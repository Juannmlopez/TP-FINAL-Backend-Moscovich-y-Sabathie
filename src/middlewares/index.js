// Middlewares de Express: autenticación, validación, 404 y manejo de errores.
const jwt = require('jsonwebtoken');
const { env } = require('../config');
const { HttpError } = require('../utils');

// Exige sesión: lee el JWT de la cookie "token", lo verifica y deja req.user = { id, username }; si falta, es inválido o venció, 401.
function requireAuth(req, res, next) {
  const token = req.cookies?.token;
  if (!token) {
    return next(new HttpError(401, 'No autenticado'));
  }
  try {
    const payload = jwt.verify(token, env.jwtSecret);
    req.user = { id: payload.sub, username: payload.username };
    next();
  } catch {
    next(new HttpError(401, 'Sesión inválida o vencida'));
  }
}

// Devuelve un middleware que corre el validador sobre req.body; si hay errores, 400 con la lista.
function validate(schema) {
  return (req, res, next) => {
    const errores = schema(req.body || {});
    if (errores.length > 0) {
      return next(new HttpError(400, 'Datos inválidos', errores));
    }
    next();
  };
}

// Responde 404 en JSON para cualquier ruta que no exista.
function notFound(req, res) {
  res.status(404).json({ error: `Ruta no encontrada: ${req.method} ${req.originalUrl}` });
}

// Errores de PostgreSQL que se traducen a status HTTP: 23505 duplicado, 23514 fuera de rango, 22P02 formato inválido, 23503 referencia inexistente.
const ERRORES_PG = {
  23505: [409, 'El registro ya existe'],
  23514: [400, 'Datos fuera de rango'],
  '22P02': [400, 'Formato de dato inválido'],
  23503: [404, 'El recurso referenciado no existe'],
};

// Manejador final: responde { error } con el status del HttpError, del JSON mal formado o del error de Postgres; cualquier otro error se loguea y responde 500 sin detalles.
function errorHandler(err, req, res, next) {
  if (err instanceof HttpError) {
    const body = { error: err.message };
    if (err.details) body.details = err.details;
    return res.status(err.status).json(body);
  }

  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'El body no es un JSON válido' });
  }

  if (ERRORES_PG[err.code]) {
    const [status, message] = ERRORES_PG[err.code];
    return res.status(status).json({ error: message });
  }

  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor' });
}

module.exports = { requireAuth, validate, notFound, errorHandler };
