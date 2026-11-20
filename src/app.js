// Punto de entrada: configura Express y levanta el servidor.
const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const { env } = require('./config');
const routes = require('./routes');
const { notFound, errorHandler } = require('./middlewares');

// Aplicación de Express.
const app = express();

// CORS: solo acepta pedidos del frontend configurado, con cookies.
app.use(cors({ origin: env.frontendUrl, credentials: true }));

// Convierte el body JSON en req.body.
app.use(express.json());

// Deja las cookies del pedido en req.cookies.
app.use(cookieParser());

// Monta todas las rutas bajo /api.
app.use('/api', routes);

// Cualquier ruta que no exista responde 404.
app.use(notFound);

// Manejador de errores (siempre al final).
app.use(errorHandler);

// Levanta el servidor en el puerto PORT (en Express 5 el callback también recibe el error si no pudo escuchar).
app.listen(env.port, (err) => {
  if (err) {
    console.error(
      err.code === 'EADDRINUSE'
        ? `El puerto ${env.port} ya está en uso: cerrá el otro proceso o cambiá PORT en el .env`
        : `No se pudo levantar el servidor: ${err.message}`
    );
    process.exit(1);
  }
  console.log(`Servidor escuchando en http://localhost:${env.port}`);
});
