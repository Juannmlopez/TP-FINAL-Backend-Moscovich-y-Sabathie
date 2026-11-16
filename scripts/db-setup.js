// Crea las tablas y, opcionalmente (--seed), carga la cuenta demo.
// Uso: node scripts/db-setup.js [--seed]
require('dotenv').config({ quiet: true });
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const SCHEMA = path.join(__dirname, '..', 'db', '01_schema.sql');
const SEED = path.join(__dirname, '..', 'db', '02_seed_demo.sql');
const conSeed = process.argv.includes('--seed');

// Lee un archivo .sql y avisa claramente si no existe
function leerSQL(ruta) {
  if (!fs.existsSync(ruta)) {
    throw new Error(`No se encontró el archivo ${path.relative(process.cwd(), ruta)}`);
  }
  return fs.readFileSync(ruta, 'utf8');
}

async function main() {
  if (!process.env.DATABASE_URL) {
    throw new Error('Falta DATABASE_URL en el archivo .env');
  }
  if (conSeed && !process.env.DEMO_PASSWORD) {
    throw new Error('Falta DEMO_PASSWORD en el archivo .env (necesaria para --seed)');
  }

  // Leemos los archivos antes de conectar, para fallar rápido
  const schemaSQL = leerSQL(SCHEMA);
  const seedSQL = conSeed ? leerSQL(SEED) : null;

  // Un único Client: la setting demo.password vive solo en esta sesión
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
  });

  await client.connect();
  try {
    console.log('Ejecutando db/01_schema.sql...');
    await client.query(schemaSQL);
    console.log('Esquema creado.');

    if (conSeed) {
      // Se pasa como parámetro: la contraseña nunca se imprime ni se arma en el SQL
      await client.query("SELECT set_config('demo.password', $1, false)", [
        process.env.DEMO_PASSWORD,
      ]);
      console.log('Ejecutando db/02_seed_demo.sql...');
      await client.query(seedSQL);
      console.log('Cuenta demo cargada.');
    }
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error('Error en db-setup:', err.message);
  process.exit(1);
});
