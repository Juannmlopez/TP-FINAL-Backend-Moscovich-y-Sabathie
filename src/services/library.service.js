// Servicio de biblioteca, favoritos, puntuaciones, reseñas y playlists. Todas las consultas filtran por user_id y cada cambio se registra en activities dentro de la misma transacción.
const { pool } = require('../config');
const { HttpError, logActivity, withTransaction } = require('../utils');
const { formatContent } = require('./music.service');

// Lanza 404 si el contenido no existe en contents.
async function assertContentExists(client, contentId) {
  const { rows } = await client.query('SELECT 1 FROM contents WHERE id = $1', [contentId]);
  if (!rows[0]) throw new HttpError(404, 'Contenido no encontrado');
}

// Consulta de la biblioteca del usuario: cada ítem con su contenido, su puntuación y su reseña.
const SQL_BIBLIOTECA = `
  SELECT to_jsonb(c) AS content, li.status, li.is_favorite, li.added_at, r.score, rv.body AS review
    FROM library_items li
    JOIN contents c       ON c.id = li.content_id
    LEFT JOIN ratings r   ON r.user_id  = li.user_id AND r.content_id  = li.content_id
    LEFT JOIN reviews rv  ON rv.user_id = li.user_id AND rv.content_id = li.content_id
   WHERE li.user_id = $1`;

// Convierte una fila de SQL_BIBLIOTECA al formato de la API.
function formatLibraryItem(row) {
  return {
    ...formatContent(row.content),
    status: row.status,
    isFavorite: row.is_favorite,
    addedAt: row.added_at,
    rating: row.score ?? null,
    review: row.review ?? null,
  };
}

// Devuelve toda la biblioteca del usuario, lo agregado más reciente primero (los filtros se hacen en el frontend).
async function getLibrary(userId) {
  const { rows } = await pool.query(`${SQL_BIBLIOTECA} ORDER BY li.added_at DESC`, [userId]);
  return { items: rows.map(formatLibraryItem) };
}

// Devuelve un ítem de la biblioteca del usuario.
async function getItem(client, userId, contentId) {
  const { rows } = await client.query(`${SQL_BIBLIOTECA} AND li.content_id = $2`, [userId, contentId]);
  return formatLibraryItem(rows[0]);
}

// Agrega un contenido a la biblioteca (409 si ya estaba) y registra 'library_add'.
async function addItem(userId, contentId, status = 'quiero_escuchar') {
  return withTransaction(async (client) => {
    await assertContentExists(client, contentId);
    const { rowCount } = await client.query(
      `INSERT INTO library_items (user_id, content_id, status)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, content_id) DO NOTHING`,
      [userId, contentId, status]
    );
    if (rowCount === 0) throw new HttpError(409, 'Ya está en tu biblioteca');
    await logActivity(client, userId, 'library_add', { contentId, details: { status } });
    return getItem(client, userId, contentId);
  });
}

// Cambia el estado y/o el favorito de un ítem y registra 'status_change', 'favorite_add' o 'favorite_remove' según lo que cambió.
async function updateItem(userId, contentId, { status, isFavorite }) {
  return withTransaction(async (client) => {
    const { rows } = await client.query(
      'SELECT status, is_favorite FROM library_items WHERE user_id = $1 AND content_id = $2',
      [userId, contentId]
    );
    const actual = rows[0];
    if (!actual) throw new HttpError(404, 'No está en tu biblioteca');

    const nuevoStatus = status ?? actual.status;
    const nuevoFavorito = isFavorite ?? actual.is_favorite;
    await client.query(
      `UPDATE library_items
          SET status = $3,
              status_changed_at = CASE WHEN status <> $3::library_status THEN now() ELSE status_changed_at END,
              is_favorite = $4,
              favorited_at = CASE WHEN $4::boolean THEN COALESCE(favorited_at, now()) END
        WHERE user_id = $1 AND content_id = $2`,
      [userId, contentId, nuevoStatus, nuevoFavorito]
    );

    if (nuevoStatus !== actual.status) {
      await logActivity(client, userId, 'status_change', {
        contentId,
        details: { from: actual.status, to: nuevoStatus },
      });
    }
    if (nuevoFavorito !== actual.is_favorite) {
      await logActivity(client, userId, nuevoFavorito ? 'favorite_add' : 'favorite_remove', { contentId });
    }
    return getItem(client, userId, contentId);
  });
}

// Saca un contenido de la biblioteca (404 si no estaba) y registra 'library_remove'.
async function removeItem(userId, contentId) {
  await withTransaction(async (client) => {
    const { rowCount } = await client.query(
      'DELETE FROM library_items WHERE user_id = $1 AND content_id = $2',
      [userId, contentId]
    );
    if (rowCount === 0) throw new HttpError(404, 'No está en tu biblioteca');
    await logActivity(client, userId, 'library_remove', { contentId });
  });
}

// Crea o reemplaza la puntuación (1 a 5) de un contenido y registra 'rating_set'.
async function setRating(userId, contentId, score) {
  await withTransaction(async (client) => {
    await assertContentExists(client, contentId);
    await client.query(
      `INSERT INTO ratings (user_id, content_id, score)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, content_id) DO UPDATE SET score = EXCLUDED.score`,
      [userId, contentId, score]
    );
    await logActivity(client, userId, 'rating_set', { contentId, details: { score } });
  });
  return { contentId, score };
}

// Borra la puntuación (404 si no había) y registra 'rating_remove'.
async function removeRating(userId, contentId) {
  await withTransaction(async (client) => {
    const { rowCount } = await client.query(
      'DELETE FROM ratings WHERE user_id = $1 AND content_id = $2',
      [userId, contentId]
    );
    if (rowCount === 0) throw new HttpError(404, 'No tenías puntuación para este contenido');
    await logActivity(client, userId, 'rating_remove', { contentId });
  });
}

// Crea o edita la reseña de un contenido y registra 'review_create' o 'review_update'; devuelve si fue creada.
async function setReview(userId, contentId, body) {
  return withTransaction(async (client) => {
    await assertContentExists(client, contentId);
    const { rowCount: existia } = await client.query(
      'SELECT 1 FROM reviews WHERE user_id = $1 AND content_id = $2',
      [userId, contentId]
    );
    await client.query(
      `INSERT INTO reviews (user_id, content_id, body)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, content_id) DO UPDATE SET body = EXCLUDED.body`,
      [userId, contentId, body.trim()]
    );
    await logActivity(client, userId, existia ? 'review_update' : 'review_create', { contentId });
    return { review: { contentId, body: body.trim() }, created: !existia };
  });
}

// Borra la reseña (404 si no había) y registra 'review_delete'.
async function removeReview(userId, contentId) {
  await withTransaction(async (client) => {
    const { rowCount } = await client.query(
      'DELETE FROM reviews WHERE user_id = $1 AND content_id = $2',
      [userId, contentId]
    );
    if (rowCount === 0) throw new HttpError(404, 'No tenías reseña para este contenido');
    await logActivity(client, userId, 'review_delete', { contentId });
  });
}

// Convierte una fila de collections al formato de la API.
function formatCollection(row) {
  return {
    id: String(row.id),
    name: row.name,
    description: row.description,
    itemCount: Number(row.item_count ?? 0),
    createdAt: row.created_at,
  };
}

// Devuelve la playlist si es del usuario; 404 si no existe o es de otro (no se distinguen para no revelar playlists ajenas).
async function findOwnCollection(client, userId, collectionId) {
  const { rows } = await client.query(
    'SELECT * FROM collections WHERE id = $1 AND user_id = $2',
    [collectionId, userId]
  );
  if (!rows[0]) throw new HttpError(404, 'Playlist no encontrada');
  return rows[0];
}

// Lista las playlists del usuario con la cantidad de contenidos de cada una.
async function getCollections(userId) {
  const { rows } = await pool.query(
    `SELECT col.*, count(ci.content_id) AS item_count
       FROM collections col
       LEFT JOIN collection_items ci ON ci.collection_id = col.id
      WHERE col.user_id = $1
      GROUP BY col.id
      ORDER BY col.created_at DESC`,
    [userId]
  );
  return { collections: rows.map(formatCollection) };
}

// Crea una playlist (409 si ya tiene una con ese nombre) y registra 'collection_create'.
async function createCollection(userId, { name, description }) {
  try {
    return await withTransaction(async (client) => {
      const { rows } = await client.query(
        'INSERT INTO collections (user_id, name, description) VALUES ($1, $2, $3) RETURNING *',
        [userId, name.trim(), description?.trim() || null]
      );
      await logActivity(client, userId, 'collection_create', {
        collectionId: rows[0].id,
        details: { name: rows[0].name },
      });
      return formatCollection(rows[0]);
    });
  } catch (err) {
    if (err.code === '23505') throw new HttpError(409, 'Ya tenés una playlist con ese nombre');
    throw err;
  }
}

// Devuelve una playlist del usuario con sus contenidos en orden.
async function getCollection(userId, collectionId) {
  const col = await findOwnCollection(pool, userId, collectionId);
  const { rows } = await pool.query(
    `SELECT to_jsonb(c) AS content
       FROM collection_items ci
       JOIN contents c ON c.id = ci.content_id
      WHERE ci.collection_id = $1
      ORDER BY ci.position, ci.added_at`,
    [col.id]
  );
  const items = rows.map((r) => formatContent(r.content));
  return { collection: { ...formatCollection({ ...col, item_count: items.length }), items } };
}

// Cambia el nombre y la descripción de una playlist del usuario (409 si el nombre se repite) y registra 'collection_update'.
async function updateCollection(userId, collectionId, { name, description }) {
  try {
    return await withTransaction(async (client) => {
      await findOwnCollection(client, userId, collectionId);
      const { rows } = await client.query(
        `UPDATE collections SET name = $3, description = $4
          WHERE id = $1 AND user_id = $2
          RETURNING *`,
        [collectionId, userId, name.trim(), description?.trim() || null]
      );
      await logActivity(client, userId, 'collection_update', { collectionId, details: { name: rows[0].name } });
      return formatCollection(rows[0]);
    });
  } catch (err) {
    if (err.code === '23505') throw new HttpError(409, 'Ya tenés una playlist con ese nombre');
    throw err;
  }
}

// Borra una playlist del usuario y registra 'collection_delete' guardando su nombre.
async function deleteCollection(userId, collectionId) {
  await withTransaction(async (client) => {
    const { rows } = await client.query(
      'DELETE FROM collections WHERE id = $1 AND user_id = $2 RETURNING name',
      [collectionId, userId]
    );
    if (!rows[0]) throw new HttpError(404, 'Playlist no encontrada');
    await logActivity(client, userId, 'collection_delete', { details: { name: rows[0].name } });
  });
}

// Agrega un contenido al final de una playlist del usuario (409 si ya estaba) y registra 'collection_add_item'.
async function addCollectionItem(userId, collectionId, contentId) {
  await withTransaction(async (client) => {
    await findOwnCollection(client, userId, collectionId);
    await assertContentExists(client, contentId);
    const { rowCount } = await client.query(
      `INSERT INTO collection_items (collection_id, content_id, position)
       VALUES ($1, $2, (SELECT count(*) FROM collection_items WHERE collection_id = $1))
       ON CONFLICT (collection_id, content_id) DO NOTHING`,
      [collectionId, contentId]
    );
    if (rowCount === 0) throw new HttpError(409, 'Ya está en la playlist');
    await logActivity(client, userId, 'collection_add_item', { contentId, collectionId });
  });
  return { collectionId, contentId };
}

// Saca un contenido de una playlist del usuario (404 si no estaba) y registra 'collection_remove_item'.
async function removeCollectionItem(userId, collectionId, contentId) {
  await withTransaction(async (client) => {
    await findOwnCollection(client, userId, collectionId);
    const { rowCount } = await client.query(
      'DELETE FROM collection_items WHERE collection_id = $1 AND content_id = $2',
      [collectionId, contentId]
    );
    if (rowCount === 0) throw new HttpError(404, 'No está en la playlist');
    await logActivity(client, userId, 'collection_remove_item', { contentId, collectionId });
  });
}

module.exports = {
  getLibrary,
  addItem,
  updateItem,
  removeItem,
  setRating,
  removeRating,
  setReview,
  removeReview,
  getCollections,
  createCollection,
  getCollection,
  updateCollection,
  deleteCollection,
  addCollectionItem,
  removeCollectionItem,
};
