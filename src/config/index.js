// Configuración: carga el .env, lo valida y crea la conexión a PostgreSQL.
require('dotenv').config({ quiet: true });
const { Pool, types } = require('pg');

// Hace que las columnas date lleguen como texto ("2024-05-01") y no se corran de día por la zona horaria.
types.setTypeParser(1082, (valor) => valor);

// Variables sin las cuales la app no puede arrancar.
const obligatorias = ['DATABASE_URL', 'JWT_SECRET', 'FRONTEND_URL'];

// Nombres de las variables obligatorias que no están definidas.
const faltantes = obligatorias.filter((nombre) => !process.env[nombre]);

// Si falta alguna, muestra cuáles (nunca sus valores) y corta la ejecución.
if (faltantes.length > 0) {
  console.error(`Faltan variables en el .env: ${faltantes.join(', ')}`);
  console.error('Copiá .env.example como .env y completalas.');
  process.exit(1);
}

// Valores de configuración que usa el resto de la app.
const env = {
  port: Number(process.env.PORT) || 3000,
  databaseUrl: process.env.DATABASE_URL,
  databaseSSL: process.env.DATABASE_SSL === 'true',
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  frontendUrl: process.env.FRONTEND_URL,
  isProduction: process.env.NODE_ENV === 'production',
};

// Pool de conexiones a PostgreSQL compartido por toda la app (SSL solo si DATABASE_SSL=true).
const pool = new Pool({
  connectionString: env.databaseUrl,
  ssl: env.databaseSSL ? { rejectUnauthorized: false } : false,
});

module.exports = { env, pool };
