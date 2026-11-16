// Servicio de autenticación (registro, login, usuario actual): lógica y consultas SQL
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const env = require('../config/env');
const HttpError = require('../utils/HttpError');

const SALT_ROUNDS = 10;

// Firma el JWT que después lee auth.middleware (sub = id, username)
function generarToken(user) {
  return jwt.sign({ sub: String(user.id), username: user.username }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  });
}

// Datos públicos del usuario (nunca devolvemos password_hash)
function formatearUsuario(row) {
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

async function registrar({ username, email, password, displayName }) {
  const emailNormalizado = email.trim().toLowerCase();

  // Chequeo previo para dar un mensaje claro (el índice único igual lo garantiza)
  const { rows: existentes } = await pool.query(
    `SELECT lower(username) = lower($1) AS mismo_username,
            lower(email)    = lower($2) AS mismo_email
       FROM users
      WHERE lower(username) = lower($1) OR lower(email) = lower($2)`,
    [username, emailNormalizado]
  );
  if (existentes.some((r) => r.mismo_username)) {
    throw new HttpError(409, 'El nombre de usuario ya está en uso');
  }
  if (existentes.some((r) => r.mismo_email)) {
    throw new HttpError(409, 'El email ya está registrado');
  }

  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

  // Usuario + preferencias por defecto en una sola transacción
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `INSERT INTO users (username, email, password_hash, display_name)
       VALUES ($1, $2, $3, $4)
       RETURNING id, username, email, display_name, bio, avatar_url, created_at`,
      [username, emailNormalizado, passwordHash, displayName?.trim() || null]
    );
    const user = rows[0];
    await client.query('INSERT INTO user_preferences (user_id) VALUES ($1)', [user.id]);
    await client.query('COMMIT');

    return { token: generarToken(user), user: formatearUsuario(user) };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err; // un 23505 (carrera entre dos registros) lo traduce error.middleware a 409
  } finally {
    client.release();
  }
}

// Hash válido que se compara cuando el usuario no existe, para que la respuesta
// tarde lo mismo y no se pueda adivinar qué usuarios están registrados
const HASH_FALSO = bcrypt.hashSync('contraseña-que-no-existe', SALT_ROUNDS);

async function login({ username, email, password }) {
  const identificador = (email || username).trim();
  const columna = email ? 'email' : 'username';

  const { rows } = await pool.query(
    `SELECT id, username, email, password_hash, display_name, bio, avatar_url, created_at
       FROM users
      WHERE lower(${columna}) = lower($1)`,
    [identificador]
  );
  const user = rows[0];

  const coincide = await bcrypt.compare(password, user ? user.password_hash : HASH_FALSO);
  if (!user || !coincide) {
    // Mismo mensaje en los dos casos: no revelamos si el usuario existe
    throw new HttpError(401, 'Usuario o contraseña incorrectos');
  }

  return { token: generarToken(user), user: formatearUsuario(user) };
}

// Usuario del token (req.user.id). Si lo borraron después de emitir el token → 401
async function usuarioActual(id) {
  const { rows } = await pool.query(
    `SELECT id, username, email, display_name, bio, avatar_url, created_at
       FROM users
      WHERE id = $1`,
    [id]
  );
  if (!rows[0]) {
    throw new HttpError(401, 'El usuario del token ya no existe');
  }
  return formatearUsuario(rows[0]);
}

module.exports = { registrar, login, usuarioActual, generarToken, formatearUsuario };
