// Verifica el JWT del header Authorization y pone req.user
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const HttpError = require('../utils/HttpError');

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [tipo, token] = header.split(' ');

  if (tipo !== 'Bearer' || !token) {
    return next(new HttpError(401, 'Falta el token de autenticación'));
  }

  try {
    const payload = jwt.verify(token, env.jwtSecret);
    req.user = { id: payload.sub, username: payload.username };
    next();
  } catch {
    next(new HttpError(401, 'Token inválido o vencido'));
  }
}

module.exports = { requireAuth };
