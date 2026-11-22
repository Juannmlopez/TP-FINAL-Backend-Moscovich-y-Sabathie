// Todas las rutas de la API (app.js las monta en /api). Las privadas llevan requireAuth y las que reciben body, validate(schema).
const { Router } = require('express');
const { requireAuth, validate } = require('../middlewares');
const v = require('../validators');
const auth = require('../controllers/auth.controller');
const music = require('../controllers/music.controller');
const library = require('../controllers/library.controller');
const stats = require('../controllers/stats.controller');

// Router único con todas las rutas.
const router = Router();

// Crea una cuenta nueva e inicia sesión (setea la cookie).
router.post('/auth/register', validate(v.register), auth.register);

// Inicia sesión con username o email y setea la cookie.
router.post('/auth/login', validate(v.login), auth.login);

// Cierra la sesión borrando la cookie (pública: responde 200 aunque no haya sesión o esté vencida).
router.post('/auth/logout', auth.logout);

// Recuperar contraseña: responde 200 sin revelar si el email existe.
router.post('/auth/forgot-password', validate(v.forgotPassword), auth.forgotPassword);

// Devuelve el usuario de la sesión.
router.get('/auth/me', requireAuth, auth.me);

// Devuelve el perfil: usuario, preferencias y géneros preferidos.
router.get('/users/me', requireAuth, auth.getProfile);

// Edita displayName, bio y/o avatarUrl.
router.patch('/users/me', requireAuth, validate(v.updateProfile), auth.updateProfile);

// Cambia las preferencias: theme, language, settings (reproducción, notificaciones, privacidad) y/o géneros preferidos.
router.put('/users/me/preferences', requireAuth, validate(v.updatePreferences), auth.updatePreferences);

// Busca canciones o álbumes en la API de música (?q=&type=track|album|artist).
router.get('/music/search', requireAuth, music.search);

// Devuelve los destacados de la API de música para la Home.
router.get('/music/featured', requireAuth, music.getFeatured);

// Detalle de un álbum con sus canciones (:id de Deezer).
router.get('/music/albums/:id', requireAuth, music.getAlbum);

// Detalle de una canción (:id de Deezer).
router.get('/music/tracks/:id', requireAuth, music.getTrack);

// Detalle de un artista (:id de Deezer).
router.get('/music/artists/:id', requireAuth, music.getArtist);

// Discografía de un artista (:id de Deezer).
router.get('/music/artists/:id/albums', requireAuth, music.getArtistAlbums);

// Devuelve la biblioteca del usuario.
router.get('/library', requireAuth, library.getLibrary);

// Agrega un contenido a la biblioteca.
router.post('/library', requireAuth, validate(v.addLibraryItem), library.addItem);

// Cambia el estado y/o el favorito de un ítem de la biblioteca.
router.patch('/library/:contentId', requireAuth, validate(v.updateLibraryItem), library.updateItem);

// Saca un contenido de la biblioteca.
router.delete('/library/:contentId', requireAuth, library.removeItem);

// Crea o cambia la puntuación (1 a 5) de un contenido.
router.put('/library/:contentId/rating', requireAuth, validate(v.rating), library.setRating);

// Borra la puntuación de un contenido.
router.delete('/library/:contentId/rating', requireAuth, library.removeRating);

// Crea o edita la reseña de un contenido.
router.put('/library/:contentId/review', requireAuth, validate(v.review), library.setReview);

// Borra la reseña de un contenido.
router.delete('/library/:contentId/review', requireAuth, library.removeReview);

// Lista las playlists del usuario.
router.get('/collections', requireAuth, library.getCollections);

// Crea una playlist.
router.post('/collections', requireAuth, validate(v.collection), library.createCollection);

// Detalle de una playlist con sus contenidos.
router.get('/collections/:id', requireAuth, library.getCollection);

// Cambia nombre y descripción de una playlist.
router.patch('/collections/:id', requireAuth, validate(v.collection), library.updateCollection);

// Borra una playlist.
router.delete('/collections/:id', requireAuth, library.deleteCollection);

// Agrega un contenido a una playlist.
router.post('/collections/:id/items', requireAuth, validate(v.collectionItem), library.addCollectionItem);

// Saca un contenido de una playlist.
router.delete('/collections/:id/items/:contentId', requireAuth, library.removeCollectionItem);

// Estadísticas del año (?year=).
router.get('/stats', requireAuth, stats.getStats);

// Actividad reciente del usuario.
router.get('/activity', requireAuth, stats.getActivity);

// Registra una reproducción (alimenta las estadísticas de escucha).
router.post('/history', requireAuth, validate(v.historyEntry), stats.addHistoryEntry);

module.exports = router;
