// Controlador de biblioteca, favoritos, puntuaciones, reseñas y playlists: llama a library.service con req.user.id y responde.
const service = require('../services/library.service');
const { parseId } = require('../utils');

// GET /api/library — devuelve la biblioteca con estado, favorito, puntuación y reseña de cada contenido.
async function getLibrary(req, res) {
  res.json(await service.getLibrary(req.user.id));
}

// POST /api/library — agrega un contenido y responde 201 con el ítem.
async function addItem(req, res) {
  const item = await service.addItem(req.user.id, parseId(req.body.contentId, 'contentId'), req.body.status);
  res.status(201).json({ item });
}

// PATCH /api/library/:contentId — cambia estado y/o favorito.
async function updateItem(req, res) {
  const item = await service.updateItem(req.user.id, parseId(req.params.contentId, 'contentId'), req.body);
  res.json({ item });
}

// DELETE /api/library/:contentId — saca el contenido de la biblioteca (204).
async function removeItem(req, res) {
  await service.removeItem(req.user.id, parseId(req.params.contentId, 'contentId'));
  res.status(204).end();
}

// PUT /api/library/:contentId/rating — crea o cambia la puntuación.
async function setRating(req, res) {
  const rating = await service.setRating(req.user.id, parseId(req.params.contentId, 'contentId'), req.body.score);
  res.json({ rating });
}

// DELETE /api/library/:contentId/rating — borra la puntuación (204).
async function removeRating(req, res) {
  await service.removeRating(req.user.id, parseId(req.params.contentId, 'contentId'));
  res.status(204).end();
}

// PUT /api/library/:contentId/review — crea (201) o edita (200) la reseña.
async function setReview(req, res) {
  const { review, created } = await service.setReview(
    req.user.id,
    parseId(req.params.contentId, 'contentId'),
    req.body.body
  );
  res.status(created ? 201 : 200).json({ review });
}

// DELETE /api/library/:contentId/review — borra la reseña (204).
async function removeReview(req, res) {
  await service.removeReview(req.user.id, parseId(req.params.contentId, 'contentId'));
  res.status(204).end();
}

// GET /api/collections — lista las playlists.
async function getCollections(req, res) {
  res.json(await service.getCollections(req.user.id));
}

// POST /api/collections — crea una playlist (201).
async function createCollection(req, res) {
  res.status(201).json({ collection: await service.createCollection(req.user.id, req.body) });
}

// GET /api/collections/:id — detalle de una playlist con sus contenidos.
async function getCollection(req, res) {
  res.json(await service.getCollection(req.user.id, parseId(req.params.id)));
}

// PATCH /api/collections/:id — cambia nombre y descripción de una playlist.
async function updateCollection(req, res) {
  res.json({ collection: await service.updateCollection(req.user.id, parseId(req.params.id), req.body) });
}

// DELETE /api/collections/:id — borra una playlist (204).
async function deleteCollection(req, res) {
  await service.deleteCollection(req.user.id, parseId(req.params.id));
  res.status(204).end();
}

// POST /api/collections/:id/items — agrega un contenido a la playlist (201).
async function addCollectionItem(req, res) {
  const item = await service.addCollectionItem(
    req.user.id,
    parseId(req.params.id),
    parseId(req.body.contentId, 'contentId')
  );
  res.status(201).json({ item });
}

// DELETE /api/collections/:id/items/:contentId — saca un contenido de la playlist (204).
async function removeCollectionItem(req, res) {
  await service.removeCollectionItem(req.user.id, parseId(req.params.id), parseId(req.params.contentId, 'contentId'));
  res.status(204).end();
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
