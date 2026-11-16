// Conexión a PostgreSQL compartida por toda la app
require('dotenv').config({ quiet: true });
const { Pool } = require('pg');

if (!process.env.DATABASE_URL) {
  throw new Error('Falta DATABASE_URL en el archivo .env');
}

// SSL solo si DATABASE_SSL=true (por ejemplo, en una base en la nube)
const usarSSL = process.env.DATABASE_SSL === 'true';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: usarSSL ? { rejectUnauthorized: false } : false,
});

module.exports = pool;
