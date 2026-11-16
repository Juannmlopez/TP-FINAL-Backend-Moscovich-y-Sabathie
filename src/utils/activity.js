// Registra una acción del usuario en la tabla activities (feed de actividad)
const pool = require('../db');

// db puede ser el pool o un client dentro de una transacción
async function registrarActividad(
  { userId, type, contentId = null, collectionId = null, details = {} },
  db = pool
) {
  await db.query(
    `INSERT INTO activities (user_id, type, content_id, collection_id, details)
     VALUES ($1, $2, $3, $4, $5)`,
    [userId, type, contentId, collectionId, details]
  );
}

module.exports = { registrarActividad };
