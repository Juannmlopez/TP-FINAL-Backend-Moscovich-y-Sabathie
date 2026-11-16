// Controlador de autenticación (registro, login, usuario actual): recibe req, llama al servicio y arma la respuesta
const service = require('../services/auth.service');

// POST /api/auth/register
async function register(req, res) {
  const resultado = await service.registrar(req.body);
  res.status(201).json(resultado);
}

// POST /api/auth/login
async function login(req, res) {
  const resultado = await service.login(req.body);
  res.json(resultado);
}

// GET /api/auth/me (requiere token)
async function me(req, res) {
  const user = await service.usuarioActual(req.user.id);
  res.json({ user });
}

module.exports = { register, login, me };
