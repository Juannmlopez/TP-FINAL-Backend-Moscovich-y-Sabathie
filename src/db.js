// Conexión a PostgreSQL compartida por toda la app
const { Pool } = require('pg');
const env = require('./config/env');

// SSL solo si DATABASE_SSL=true (por ejemplo, en una base en la nube)
const pool = new Pool({
  connectionString: env.databaseUrl,
  ssl: env.databaseSSL ? { rejectUnauthorized: false } : false,
});

module.exports = pool;
