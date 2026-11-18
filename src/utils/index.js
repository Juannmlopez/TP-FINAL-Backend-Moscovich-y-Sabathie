// Utilidades compartidas por los servicios y controladores.
const jwt = require('jsonwebtoken');
const { env, pool } = require('../config');

// Error con código HTTP que el errorHandler convierte en la respuesta { error }. details: lista opcional de errores de validación.
class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

// Ejecuta fn(client) dentro de una transacción: COMMIT si todo sale bien, ROLLBACK si algo falla.
async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const resultado = await fn(client);
    await client.query('COMMIT');
    return resultado;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

// Valida un id recibido en la URL o el body (entero positivo) y lo devuelve como texto; si no es válido, 400.
function parseId(valor, nombre = 'id') {
  if (!/^[1-9]\d{0,17}$/.test(String(valor))) {
    throw new HttpError(400, `${nombre} inválido`);
  }
  return String(valor);
}

// Registra una acción del usuario en activities (type tiene que ser del enum activity_type; client puede ser el pool o el de una transacción).
async function logActivity(client, userId, type, { contentId = null, collectionId = null, details = {} } = {}) {
  await client.query(
    `INSERT INTO activities (user_id, type, content_id, collection_id, details)
     VALUES ($1, $2, $3, $4, $5)`,
    [userId, type, contentId, collectionId, details]
  );
}

// Firma el JWT de la sesión con el id (sub) y el username; vence según JWT_EXPIRES_IN.
function signToken(user) {
  return jwt.sign({ sub: String(user.id), username: user.username }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  });
}

// Convierte JWT_EXPIRES_IN ("7d", "12h", "30m", "45s" o segundos) a milisegundos.
function expiresInToMs(valor) {
  const match = /^(\d+)\s*([smhd]?)$/.exec(String(valor).trim());
  if (!match) throw new Error('JWT_EXPIRES_IN tiene un formato inválido (usar ej. 7d, 12h, 30m)');
  const unidades = { '': 1, s: 1, m: 60, h: 3600, d: 86400 };
  return Number(match[1]) * unidades[match[2]] * 1000;
}

// Opciones de la cookie "token": httpOnly y misma duración que el JWT; en producción, secure y sameSite 'none'.
const cookieOptions = {
  httpOnly: true,
  secure: env.isProduction,
  sameSite: env.isProduction ? 'none' : 'lax',
  maxAge: expiresInToMs(env.jwtExpiresIn),
};

module.exports = { HttpError, withTransaction, parseId, logActivity, signToken, cookieOptions };
