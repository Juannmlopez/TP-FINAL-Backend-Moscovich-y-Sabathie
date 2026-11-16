// Aplica un validador (de la carpeta validators) al body del request.
// Un validador es una función que recibe el body y devuelve un array de errores.
const HttpError = require('../utils/HttpError');

function validate(validador) {
  return (req, res, next) => {
    const errores = validador(req.body || {});
    if (errores.length > 0) {
      return next(new HttpError(400, 'Datos inválidos', errores));
    }
    next();
  };
}

module.exports = { validate };
