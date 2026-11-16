// Error con código HTTP. Ej: throw new HttpError(404, 'Reseña no encontrada')
class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details; // opcional: lista de errores de validación
  }
}

module.exports = HttpError;
