// Servicio de autenticación y perfil: lógica y consultas SQL. Nunca devuelve password_hash.
const bcrypt = require('bcryptjs');
const { pool } = require('../config');
const { HttpError, logActivity, withTransaction } = require('../utils');

// Columnas públicas del usuario (sin password_hash).
const USER_COLUMNS = 'id, username, email, display_name, bio, avatar_url, created_at';

// Convierte una fila de users al formato de la API (camelCase, sin password_hash).
function formatUser(row) {
  return {
    id: String(row.id),
    username: row.username,
    email: row.email,
    displayName: row.display_name,
    bio: row.bio,
    avatarUrl: row.avatar_url,
    createdAt: row.created_at,
  };
}

// Registra un usuario: hashea la contraseña y crea el usuario y sus preferencias en una transacción; 409 si el username o el email ya existen.
async function register({ username, email, password }) {
  const passwordHash = await bcrypt.hash(password, 10);
  try {
    return await withTransaction(async (client) => {
      const { rows } = await client.query(
        `INSERT INTO users (username, email, password_hash)
         VALUES ($1, $2, $3)
         RETURNING ${USER_COLUMNS}`,
        [username, email.trim().toLowerCase(), passwordHash]
      );
      await client.query('INSERT INTO user_preferences (user_id) VALUES ($1)', [rows[0].id]);
      return formatUser(rows[0]);
    });
  } catch (err) {
    if (err.code === '23505') {
      const esUsername = err.constraint === 'users_username_unique';
      throw new HttpError(
        409,
        esUsername ? 'El nombre de usuario ya está en uso' : 'El email ya está en uso',
        esUsername
          ? { username: 'Ese nombre de usuario ya está en uso' }
          : { email: 'Ese email ya está registrado' }
      );
    }
    throw err;
  }
}

// Login por username o email: si el usuario no existe o la contraseña no coincide, 401 con el mismo mensaje.
async function login({ username, email, password }) {
  const { rows } = await pool.query(
    `SELECT ${USER_COLUMNS}, password_hash
       FROM users
      WHERE lower(username) = lower($1) OR lower(email) = lower($1)`,
    [(email || username).trim()]
  );
  const user = rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    throw new HttpError(401, 'Usuario o contraseña incorrectos');
  }
  return formatUser(user);
}

// Devuelve el usuario por id; 401 si ya no existe.
async function me(userId) {
  const { rows } = await pool.query(`SELECT ${USER_COLUMNS} FROM users WHERE id = $1`, [userId]);
  if (!rows[0]) throw new HttpError(401, 'El usuario de la sesión ya no existe');
  return formatUser(rows[0]);
}

// Devuelve el usuario, sus preferencias (tema e idioma) y sus géneros preferidos.
async function getProfile(userId) {
  const user = await me(userId);
  const { rows: prefs } = await pool.query(
    'SELECT theme, language FROM user_preferences WHERE user_id = $1',
    [userId]
  );
  const { rows: genres } = await pool.query(
    `SELECT g.name
       FROM user_preferred_genres upg
       JOIN genres g ON g.id = upg.genre_id
      WHERE upg.user_id = $1
      ORDER BY g.name`,
    [userId]
  );
  return {
    user,
    preferences: {
      theme: prefs[0]?.theme ?? 'dark',
      language: prefs[0]?.language ?? 'es',
      genres: genres.map((g) => g.name),
    },
  };
}

// Actualiza los campos enviados (displayName, bio, avatarUrl; los que no vienen quedan igual) y registra 'profile_update'.
async function updateProfile(userId, { displayName, bio, avatarUrl }) {
  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `UPDATE users
          SET display_name = COALESCE($2, display_name),
              bio          = COALESCE($3, bio),
              avatar_url   = COALESCE($4, avatar_url)
        WHERE id = $1
        RETURNING ${USER_COLUMNS}`,
      [userId, displayName?.trim(), bio?.trim(), avatarUrl]
    );
    await logActivity(client, userId, 'profile_update');
    return formatUser(rows[0]);
  });
}

// Cambia las preferencias enviadas (theme, language; las que no vienen quedan igual) y, si viene genres, reemplaza los géneros preferidos (crea los que no existan). Devuelve el perfil completo.
async function updatePreferences(userId, { theme, language, genres }) {
  await withTransaction(async (client) => {
    await client.query(
      `INSERT INTO user_preferences (user_id, theme, language)
       VALUES ($1, COALESCE($2, 'dark'), COALESCE($3, 'es'))
       ON CONFLICT (user_id) DO UPDATE SET
         theme    = COALESCE($2, user_preferences.theme),
         language = COALESCE($3, user_preferences.language)`,
      [userId, theme, language]
    );
    if (genres !== undefined) {
      await client.query('DELETE FROM user_preferred_genres WHERE user_id = $1', [userId]);
      for (const nombre of genres) {
        const { rows } = await client.query(
          `INSERT INTO genres (name) VALUES ($1)
           ON CONFLICT ((lower(name))) DO UPDATE SET name = genres.name
           RETURNING id`,
          [nombre.trim()]
        );
        await client.query(
          'INSERT INTO user_preferred_genres (user_id, genre_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
          [userId, rows[0].id]
        );
      }
    }
  });
  return getProfile(userId);
}

module.exports = { register, login, me, updatePreferences, getProfile, updateProfile };
