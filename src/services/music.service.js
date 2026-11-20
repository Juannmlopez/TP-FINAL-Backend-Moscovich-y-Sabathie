// Servicio de música: consulta la API de Deezer y guarda cada resultado en contents. En las respuestas, id es el id local y externalId el de Deezer.
const { pool } = require('../config');
const { HttpError } = require('../utils');

// URL base de la API de música.
const MUSIC_API_URL = 'https://api.deezer.com';

// Hace un GET a la API de música y devuelve el JSON; 404 si el recurso no existe y 502 si la API falla o no responde.
async function fetchFromMusicApi(endpoint) {
  let data;
  try {
    const respuesta = await fetch(MUSIC_API_URL + endpoint, { signal: AbortSignal.timeout(8000) });
    data = await respuesta.json();
  } catch (err) {
    console.error('Error llamando a la API de música:', err.message, err.cause?.code || '');
    throw new HttpError(502, 'La API de música no respondió');
  }
  if (data.error) {
    if (data.error.code === 800) throw new HttpError(404, 'No se encontró en la API de música');
    throw new HttpError(502, 'La API de música devolvió un error');
  }
  return data;
}

// Devuelve la fecha si es válida (YYYY-MM-DD); Deezer a veces manda "0000-00-00" y eso se guarda como null.
function fechaValida(valor) {
  return /^\d{4}-\d{2}-\d{2}$/.test(valor || '') && !valor.startsWith('0000') && !valor.includes('-00') ? valor : null;
}

// Convierte una canción de Deezer a las columnas de contents (album se usa cuando la canción no trae su álbum).
function mapTrack(t, album = null) {
  return {
    type: 'track',
    externalId: String(t.id),
    title: t.title,
    artistName: t.artist?.name || null,
    albumTitle: t.album?.title || album?.title || null,
    coverUrl: t.album?.cover_xl || album?.cover_xl || null,
    releaseDate: fechaValida(t.release_date || album?.release_date),
    durationMs: t.duration > 0 ? t.duration * 1000 : null,
    explicit: Boolean(t.explicit_lyrics),
  };
}

// Convierte un álbum de Deezer a las columnas de contents.
function mapAlbum(a) {
  return {
    type: 'album',
    externalId: String(a.id),
    title: a.title,
    artistName: a.artist?.name || null,
    albumTitle: null,
    coverUrl: a.cover_xl || null,
    releaseDate: fechaValida(a.release_date),
    durationMs: a.duration > 0 ? a.duration * 1000 : null,
    explicit: Boolean(a.explicit_lyrics),
  };
}

// Convierte un artista de Deezer a las columnas de contents (title = nombre, coverUrl = foto).
function mapArtist(a) {
  return {
    type: 'artist',
    externalId: String(a.id),
    title: a.name,
    artistName: a.name,
    albumTitle: null,
    coverUrl: a.picture_xl || null,
    releaseDate: null,
    durationMs: null,
    explicit: false,
  };
}

// Convierte una fila de contents (o un to_jsonb(c)) al formato de la API.
function formatContent(row) {
  return {
    id: String(row.id),
    externalId: row.external_id,
    type: row.type,
    title: row.title,
    artistName: row.artist_name,
    albumTitle: row.album_title,
    coverUrl: row.cover_url,
    releaseDate: row.release_date,
    durationMs: row.duration_ms,
    explicit: row.explicit,
  };
}

// Inserta un contenido o, si ya existe (source + type + external_id), actualiza sus datos; devuelve la fila formateada.
async function upsertContent(item) {
  const { rows } = await pool.query(
    `INSERT INTO contents (source, external_id, type, title, artist_name, album_title,
                           cover_url, release_date, duration_ms, explicit)
     VALUES ('deezer', $1, $2, $3, $4, $5, $6, $7, $8, $9)
     ON CONFLICT (source, type, external_id) DO UPDATE SET
       title        = EXCLUDED.title,
       artist_name  = EXCLUDED.artist_name,
       album_title  = COALESCE(EXCLUDED.album_title, contents.album_title),
       cover_url    = EXCLUDED.cover_url,
       release_date = COALESCE(EXCLUDED.release_date, contents.release_date),
       duration_ms  = COALESCE(EXCLUDED.duration_ms, contents.duration_ms),
       explicit     = EXCLUDED.explicit
     RETURNING *`,
    [item.externalId, item.type, item.title, item.artistName, item.albumTitle,
      item.coverUrl, item.releaseDate, item.durationMs, item.explicit]
  );
  return formatContent(rows[0]);
}

// Guarda varios contenidos en orden y los devuelve formateados.
async function upsertMany(items) {
  const guardados = [];
  for (const item of items) guardados.push(await upsertContent(item));
  return guardados;
}

// Crea los géneros que falten y los asocia a los contenidos en content_genres.
async function saveGenres(contentIds, genres) {
  for (const genre of genres) {
    const { rows } = await pool.query(
      `INSERT INTO genres (name) VALUES ($1)
       ON CONFLICT ((lower(name))) DO UPDATE SET name = genres.name
       RETURNING id`,
      [genre.name]
    );
    await pool.query(
      `INSERT INTO content_genres (content_id, genre_id)
       SELECT unnest($1::bigint[]), $2::int
       ON CONFLICT DO NOTHING`,
      [contentIds, rows[0].id]
    );
  }
}

// Datos del usuario sobre un contenido, para las acciones del Detalle: estado y favorito en su biblioteca, su puntuación y su reseña.
async function getUserData(userId, contentId) {
  const { rows } = await pool.query(
    `SELECT li.status, li.is_favorite, r.score, rv.body AS review
       FROM contents c
       LEFT JOIN library_items li ON li.content_id = c.id AND li.user_id = $1
       LEFT JOIN ratings r        ON r.content_id  = c.id AND r.user_id  = $1
       LEFT JOIN reviews rv       ON rv.content_id = c.id AND rv.user_id = $1
      WHERE c.id = $2`,
    [userId, contentId]
  );
  const d = rows[0];
  return {
    library: d.status ? { status: d.status, isFavorite: d.is_favorite } : null,
    rating: d.score ?? null,
    review: d.review ?? null,
  };
}

// Busca por texto en la API, filtrando por tipo (track o album); guarda los resultados y los devuelve.
async function search(q, type = 'track') {
  const texto = typeof q === 'string' ? q.trim() : '';
  if (texto.length < 1 || texto.length > 100) throw new HttpError(400, 'q: entre 1 y 100 caracteres');
  if (!['track', 'album'].includes(type)) throw new HttpError(400, 'type: debe ser track o album');

  const endpoint = type === 'album' ? '/search/album' : '/search';
  const data = await fetchFromMusicApi(`${endpoint}?limit=25&q=${encodeURIComponent(texto)}`);
  const mapear = type === 'album' ? mapAlbum : mapTrack;
  return { results: await upsertMany(data.data.map((x) => mapear(x))) };
}

// Trae el chart de la API (canciones y álbumes más escuchados), lo guarda y lo devuelve.
async function getFeatured() {
  const data = await fetchFromMusicApi('/chart/0?limit=10');
  return {
    tracks: await upsertMany(data.tracks.data.map((t) => mapTrack(t))),
    albums: await upsertMany(data.albums.data.map((a) => mapAlbum(a))),
  };
}

// Trae un álbum con sus canciones y géneros, guarda todo y lo devuelve con los datos del usuario.
async function getAlbum(userId, externalId) {
  const data = await fetchFromMusicApi(`/album/${externalId}`);
  const album = await upsertContent(mapAlbum(data));
  const tracks = await upsertMany(data.tracks.data.map((t) => mapTrack(t, data)));
  const genres = data.genres?.data || [];
  await saveGenres([album.id, ...tracks.map((t) => t.id)], genres);
  return {
    album: { ...album, genres: genres.map((g) => g.name), ...(await getUserData(userId, album.id)) },
    tracks,
  };
}

// Trae una canción y los géneros de su álbum, la guarda y la devuelve con los datos del usuario.
async function getTrack(userId, externalId) {
  const data = await fetchFromMusicApi(`/track/${externalId}`);
  const track = await upsertContent(mapTrack(data));
  const album = await fetchFromMusicApi(`/album/${data.album.id}`);
  const genres = album.genres?.data || [];
  await saveGenres([track.id], genres);
  return { track: { ...track, genres: genres.map((g) => g.name), ...(await getUserData(userId, track.id)) } };
}

// Trae un artista, lo guarda y lo devuelve con cantidad de fans y álbumes y los datos del usuario.
async function getArtist(userId, externalId) {
  const data = await fetchFromMusicApi(`/artist/${externalId}`);
  const artist = await upsertContent(mapArtist(data));
  return {
    artist: {
      ...artist,
      fans: data.nb_fan ?? null,
      albumsCount: data.nb_album ?? null,
      ...(await getUserData(userId, artist.id)),
    },
  };
}

// Trae la discografía de un artista (hasta 50 álbumes), los guarda y los devuelve.
async function getArtistAlbums(externalId) {
  const artista = await fetchFromMusicApi(`/artist/${externalId}`);
  const data = await fetchFromMusicApi(`/artist/${externalId}/albums?limit=50`);
  // Los álbumes de este endpoint no traen el artista: se completa con el nombre del artista pedido.
  return { albums: await upsertMany(data.data.map((a) => ({ ...mapAlbum(a), artistName: artista.name }))) };
}

module.exports = { formatContent, search, getFeatured, getAlbum, getTrack, getArtist, getArtistAlbums };
