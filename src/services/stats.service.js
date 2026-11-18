// Servicio de estadísticas, actividad e historial de escucha. Las consultas son las de db/03_estadisticas.sql y todas filtran por user_id.
const { pool } = require('../config');
const { HttpError } = require('../utils');

// Consulta 1: resumen de la biblioteca (total, favoritos y cantidad por estado).
const SQL_BIBLIOTECA = `
SELECT
  count(*)                                           AS total_biblioteca,
  count(*) FILTER (WHERE is_favorite)                AS favoritos,
  count(*) FILTER (WHERE status = 'quiero_escuchar') AS quiero_escuchar,
  count(*) FILTER (WHERE status = 'escuchando')      AS escuchando,
  count(*) FILTER (WHERE status = 'escuchado')       AS escuchado,
  count(*) FILTER (WHERE status = 'favorito')        AS estado_favorito
FROM library_items
WHERE user_id = $1`;

// Consulta 2: minutos escuchados, reproducciones y canciones distintas del año.
const SQL_MINUTOS = `
SELECT
  round(coalesce(sum(ms_played), 0) / 60000.0)       AS minutos,
  count(*)                                           AS reproducciones,
  count(DISTINCT content_id)                         AS canciones_distintas
FROM listening_history
WHERE user_id = $1
  AND played_at >= make_date($2, 1, 1)
  AND played_at <  make_date($2 + 1, 1, 1)`;

// Consulta 3: top 5 artistas del año por minutos.
const SQL_TOP_ARTISTAS = `
SELECT
  c.artist_name                          AS artista,
  round(sum(h.ms_played) / 60000.0)      AS minutos
FROM listening_history h
JOIN contents c ON c.id = h.content_id
WHERE h.user_id = $1
  AND h.played_at >= make_date($2, 1, 1)
  AND h.played_at <  make_date($2 + 1, 1, 1)
GROUP BY c.artist_name
ORDER BY minutos DESC
LIMIT 5`;

// Consulta 4: top 5 canciones del año por reproducciones.
const SQL_TOP_CANCIONES = `
SELECT
  c.id, c.title AS cancion, c.artist_name AS artista, c.cover_url,
  count(*) AS reproducciones
FROM listening_history h
JOIN contents c ON c.id = h.content_id
WHERE h.user_id = $1
  AND h.played_at >= make_date($2, 1, 1)
  AND h.played_at <  make_date($2 + 1, 1, 1)
GROUP BY c.id
ORDER BY reproducciones DESC, c.title
LIMIT 5`;

// Consulta 5: géneros que predominan en el año, por minutos.
const SQL_GENEROS = `
SELECT
  g.name                                 AS genero,
  round(sum(h.ms_played) / 60000.0)      AS minutos
FROM listening_history h
JOIN content_genres cg ON cg.content_id = h.content_id
JOIN genres g          ON g.id = cg.genre_id
WHERE h.user_id = $1
  AND h.played_at >= make_date($2, 1, 1)
  AND h.played_at <  make_date($2 + 1, 1, 1)
GROUP BY g.name
ORDER BY minutos DESC`;

// Consulta 6: hábitos de escucha, reproducciones por momento del día (hora de Argentina).
const SQL_MOMENTO_DEL_DIA = `
SELECT
  CASE
    WHEN extract(hour FROM played_at AT TIME ZONE 'America/Argentina/Buenos_Aires') BETWEEN 6  AND 11 THEN 'Mañana'
    WHEN extract(hour FROM played_at AT TIME ZONE 'America/Argentina/Buenos_Aires') BETWEEN 12 AND 18 THEN 'Tarde'
    WHEN extract(hour FROM played_at AT TIME ZONE 'America/Argentina/Buenos_Aires') BETWEEN 19 AND 23 THEN 'Noche'
    ELSE 'Madrugada'
  END                                    AS momento,
  count(*)                               AS reproducciones
FROM listening_history
WHERE user_id = $1
  AND played_at >= make_date($2, 1, 1)
  AND played_at <  make_date($2 + 1, 1, 1)
GROUP BY momento
ORDER BY reproducciones DESC`;

// Consulta de actividad reciente (las últimas 20 acciones del usuario).
const SQL_ACTIVIDAD = `
SELECT a.id, a.type, a.created_at, a.details,
       c.id AS content_id, c.title, c.cover_url,
       col.id AS collection_id, col.name AS collection_name
FROM activities a
LEFT JOIN contents    c   ON c.id   = a.content_id
LEFT JOIN collections col ON col.id = a.collection_id
WHERE a.user_id = $1
ORDER BY a.created_at DESC
LIMIT 20`;

// Lee el año del query string (por defecto el actual); 400 si no es válido.
function parseYear(valor) {
  const actual = new Date().getFullYear();
  if (valor === undefined) return actual;
  const year = Number(valor);
  if (!Number.isInteger(year) || year < 2000 || year > actual) {
    throw new HttpError(400, `year: entre 2000 y ${actual}`);
  }
  return year;
}

// Calcula las 6 estadísticas del usuario en el momento, a partir de sus datos guardados.
async function getStats(userId, yearParam) {
  const year = parseYear(yearParam);
  const [biblioteca, minutos, artistas, canciones, generos, momentos] = await Promise.all([
    pool.query(SQL_BIBLIOTECA, [userId]),
    pool.query(SQL_MINUTOS, [userId, year]),
    pool.query(SQL_TOP_ARTISTAS, [userId, year]),
    pool.query(SQL_TOP_CANCIONES, [userId, year]),
    pool.query(SQL_GENEROS, [userId, year]),
    pool.query(SQL_MOMENTO_DEL_DIA, [userId, year]),
  ]);

  const b = biblioteca.rows[0];
  const m = minutos.rows[0];
  return {
    year,
    library: {
      total: Number(b.total_biblioteca),
      favorites: Number(b.favoritos),
      quieroEscuchar: Number(b.quiero_escuchar),
      escuchando: Number(b.escuchando),
      escuchado: Number(b.escuchado),
      favorito: Number(b.estado_favorito),
    },
    minutesListened: Number(m.minutos),
    plays: Number(m.reproducciones),
    uniqueTracks: Number(m.canciones_distintas),
    topArtists: artistas.rows.map((a) => ({ name: a.artista, minutes: Number(a.minutos) })),
    topTracks: canciones.rows.map((t) => ({
      id: String(t.id),
      title: t.cancion,
      artistName: t.artista,
      coverUrl: t.cover_url,
      plays: Number(t.reproducciones),
    })),
    genres: generos.rows.map((g) => ({ name: g.genero, minutes: Number(g.minutos) })),
    timeOfDay: momentos.rows.map((x) => ({ moment: x.momento, plays: Number(x.reproducciones) })),
  };
}

// Devuelve las últimas 20 acciones del usuario, con el contenido o la playlist de cada una.
async function getActivity(userId) {
  const { rows } = await pool.query(SQL_ACTIVIDAD, [userId]);
  return {
    activities: rows.map((a) => ({
      id: String(a.id),
      type: a.type,
      details: a.details,
      content: a.content_id ? { id: String(a.content_id), title: a.title, coverUrl: a.cover_url } : null,
      collection: a.collection_id ? { id: String(a.collection_id), name: a.collection_name } : null,
      createdAt: a.created_at,
    })),
  };
}

// Registra que el usuario escuchó una canción ahora (solo canciones; 404 si no existe).
async function addHistoryEntry(userId, contentId, msPlayed) {
  const { rows } = await pool.query('SELECT type FROM contents WHERE id = $1', [contentId]);
  if (!rows[0]) throw new HttpError(404, 'Contenido no encontrado');
  if (rows[0].type !== 'track') throw new HttpError(400, 'Solo se pueden registrar canciones');

  const { rows: creada } = await pool.query(
    `INSERT INTO listening_history (user_id, content_id, played_at, ms_played)
     VALUES ($1, $2, now(), $3)
     RETURNING id, played_at`,
    [userId, contentId, msPlayed]
  );
  return { id: String(creada[0].id), contentId, msPlayed, playedAt: creada[0].played_at };
}

module.exports = { getStats, getActivity, addHistoryEntry };
