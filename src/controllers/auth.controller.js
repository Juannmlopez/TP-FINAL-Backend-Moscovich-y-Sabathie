// Controlador de autenticación y perfil: recibe el pedido, llama a auth.service y arma la respuesta.
const service = require('../services/auth.service');
const { signToken, cookieOptions } = require('../utils');

// POST /api/auth/register — crea la cuenta, setea la cookie con el JWT y responde 201 con el usuario.
async function register(req, res) {
  const user = await service.register(req.body);
  res.cookie('token', signToken(user), cookieOptions);
  res.status(201).json({ user });
}

// POST /api/auth/login — valida las credenciales, setea la cookie y responde el usuario.
async function login(req, res) {
  const user = await service.login(req.body);
  res.cookie('token', signToken(user), cookieOptions);
  res.json({ user });
}

// POST /api/auth/logout — borra la cookie de sesión (mismas opciones con que se setea) y responde 200, haya o no sesión.
async function logout(req, res) {
  res.clearCookie('token', cookieOptions);
  res.json({ message: 'Sesión cerrada' });
}

// GET /api/auth/me — devuelve el usuario de la sesión.
async function me(req, res) {
  res.json({ user: await service.me(req.user.id) });
}

// GET /api/users/me — devuelve usuario, preferencias y géneros preferidos.
async function getProfile(req, res) {
  res.json(await service.getProfile(req.user.id));
}

// PATCH /api/users/me — edita el perfil y devuelve el usuario actualizado.
async function updateProfile(req, res) {
  res.json({ user: await service.updateProfile(req.user.id, req.body) });
}

// PUT /api/users/me/preferences — cambia tema, idioma y/o géneros preferidos y devuelve el perfil completo.
async function updatePreferences(req, res) {
  res.json(await service.updatePreferences(req.user.id, req.body));
}

// POST /api/auth/forgot-password — responde siempre 200 con el mismo mensaje, exista o no el email.
async function forgotPassword(req, res) {
  await service.forgotPassword(req.body);
  res.json({ message: 'Si el email está registrado, te enviamos las instrucciones para recuperar la contraseña' });
}

module.exports = { forgotPassword, register, login, logout, me, getProfile, updateProfile, updatePreferences };
