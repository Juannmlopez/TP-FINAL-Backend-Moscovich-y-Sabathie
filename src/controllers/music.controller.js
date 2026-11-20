// Controlador de música: lee query y params, llama a music.service y responde. Los :id son ids de Deezer.
const service = require('../services/music.service');
const { parseId } = require('../utils');

// GET /api/music/search — busca por texto (?q=) con filtro por tipo (?type=track|album).
async function search(req, res) {
  res.json(await service.search(req.query.q, req.query.type));
}

// GET /api/music/featured — devuelve los destacados para la Home.
async function getFeatured(req, res) {
  res.json(await service.getFeatured());
}

// GET /api/music/albums/:id — detalle de un álbum con sus canciones.
async function getAlbum(req, res) {
  res.json(await service.getAlbum(req.user.id, parseId(req.params.id)));
}

// GET /api/music/tracks/:id — detalle de una canción.
async function getTrack(req, res) {
  res.json(await service.getTrack(req.user.id, parseId(req.params.id)));
}

// GET /api/music/artists/:id — detalle de un artista.
async function getArtist(req, res) {
  res.json(await service.getArtist(req.user.id, parseId(req.params.id)));
}

// GET /api/music/artists/:id/albums — discografía de un artista.
async function getArtistAlbums(req, res) {
  res.json(await service.getArtistAlbums(parseId(req.params.id)));
}

module.exports = { search, getFeatured, getAlbum, getTrack, getArtist, getArtistAlbums };
