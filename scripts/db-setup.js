// Crea las tablas (db/01_schema.sql) y, con --seed, carga la cuenta demo (db/02_seed_demo.sql). Uso: node scripts/db-setup.js [--seed]
require('dotenv').config({ quiet: true });
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

// Ruta del archivo que crea las tablas.
const SCHEMA = path.join(__dirname, '..', 'db', '01_schema.sql');

// Ruta del archivo que carga la cuenta demo.
const SEED = path.join(__dirname, '..', 'db', '02_seed_demo.sql');

// true si se ejecutó con --seed.
const conSeed = process.argv.includes('--seed');

// Lee un archivo .sql; error claro si no existe.
function leerSQL(ruta) {
  if (!fs.existsSync(ruta)) {
    throw new Error(`No se encontró el archivo ${path.relative(process.cwd(), ruta)}`);
  }
  return fs.readFileSync(ruta, 'utf8');
}

// Valida el .env, ejecuta el schema y, con --seed, define demo.password como parámetro (sin mostrarla) y ejecuta el seed, todo con un único Client.
async function main() {
  if (!process.env.DATABASE_URL) {
    throw new Error('Falta DATABASE_URL en el archivo .env');
  }
  if (conSeed && !process.env.DEMO_PASSWORD) {
    throw new Error('Falta DEMO_PASSWORD en el archivo .env (necesaria para --seed)');
  }

  const schemaSQL = leerSQL(SCHEMA);
  const seedSQL = conSeed ? leerSQL(SEED) : null;

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

// Ejecuta el script; si falla, muestra el error y sale con código 1.
main().catch((err) => {
  console.error('Error en db-setup:', err.message);
  process.exit(1);
});
