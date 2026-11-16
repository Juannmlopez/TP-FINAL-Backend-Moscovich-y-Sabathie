// Lee y valida las variables del .env en un solo lugar
require('dotenv').config({ quiet: true });

// Variables sin las cuales la app no puede arrancar
const obligatorias = ['DATABASE_URL', 'JWT_SECRET'];
const faltantes = obligatorias.filter((nombre) => !process.env[nombre]);

if (faltantes.length > 0) {
  throw new Error(`Faltan variables en el .env: ${faltantes.join(', ')}`);
}

module.exports = {
  port: Number(process.env.PORT) || 3000,
  databaseUrl: process.env.DATABASE_URL,
  databaseSSL: process.env.DATABASE_SSL === 'true',
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:5173',
};
