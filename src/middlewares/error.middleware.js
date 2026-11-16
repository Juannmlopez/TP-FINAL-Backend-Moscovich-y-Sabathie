// Un solo lugar para responder errores
const HttpError = require('../utils/HttpError');

// Ruta inexistente → 404
function notFound(req, res, next) {
  next(new HttpError(404, `Ruta no encontrada: ${req.method} ${req.originalUrl}`));
}

// Códigos de error de PostgreSQL que traducimos a respuestas claras
const ERRORES_PG = {
  23505: [409, 'El registro ya existe'], // unique_violation
  23503: [400, 'Referencia inválida'], // foreign_key_violation
  23514: [400, 'Datos fuera de rango'], // check_violation
  '22P02': [400, 'Formato de dato inválido'], // invalid_text_representation
};

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  // Errores que lanzamos nosotros
  if (err instanceof HttpError) {
    return res.status(err.status).json({ error: err.message, details: err.details });
  }

  // JSON mal formado en el body
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'El body no es un JSON válido' });
  }

  // Errores conocidos de la base
  if (ERRORES_PG[err.code]) {
    const [status, message] = ERRORES_PG[err.code];
    return res.status(status).json({ error: message });
  }

  // Cualquier otro: se loguea y no se exponen detalles internos
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor' });
}

module.exports = { notFound, errorHandler };
