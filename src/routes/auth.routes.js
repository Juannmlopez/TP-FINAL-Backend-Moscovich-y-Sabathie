// Rutas de autenticación: /api/auth
const { Router } = require('express');
const controller = require('../controllers/auth.controller');
const { validate } = require('../middlewares/validate.middleware');
const { requireAuth } = require('../middlewares/auth.middleware');
const { validarRegistro, validarLogin } = require('../validators/auth.validator');

const router = Router();

// Express 5 pasa al errorHandler los errores de funciones async
router.post('/register', validate(validarRegistro), controller.register);
router.post('/login', validate(validarLogin), controller.login);
router.get('/me', requireAuth, controller.me);

module.exports = router;
