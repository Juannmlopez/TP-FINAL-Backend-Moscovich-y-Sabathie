// Configura Express: CORS, JSON, rutas y manejo de errores
const express = require('express');
const cors = require('cors');
const env = require('./config/env');
const routes = require('./routes');
const { notFound, errorHandler } = require('./middlewares/error.middleware');

const app = express();

// Solo el frontend configurado puede llamar a la API
app.use(cors({ origin: env.frontendUrl }));
app.use(express.json());

// Todas las rutas cuelgan de /api
app.use('/api', routes);

// Siempre al final: 404 y errores
app.use(notFound);
app.use(errorHandler);

module.exports = app;
