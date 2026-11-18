-- =====================================================================
-- Consultas de estadísticas
--
-- NO se ejecuta como script: es la referencia de las consultas que usa
-- src/services/stats.service.js (las mismas, con los mismos parámetros).
--
-- Todas reciben parámetros, listas para usar con node-postgres (pg):
--   $1 = id del usuario autenticado (sale del JWT, nunca del body)
--   $2 = año del resumen (ej: 2026), cuando corresponde
--
-- Se calculan siempre sobre los datos guardados: si el usuario cambia
-- algo en la biblioteca o el historial, el resultado cambia.
-- Para probarlas en psql:  \set uid 1  \set anio 2026  y reemplazar $1/$2.
-- =====================================================================


-- 1) Resumen de la biblioteca: total, favoritos y cantidad por estado
SELECT
  count(*)                                           AS total_biblioteca,
  count(*) FILTER (WHERE is_favorite)                AS favoritos,
  count(*) FILTER (WHERE status = 'quiero_escuchar') AS quiero_escuchar,
  count(*) FILTER (WHERE status = 'escuchando')      AS escuchando,
  count(*) FILTER (WHERE status = 'escuchado')       AS escuchado,
  count(*) FILTER (WHERE status = 'favorito')        AS estado_favorito
FROM library_items
WHERE user_id = $1;


-- 2) Minutos escuchados en el año (el número grande del Wrapped)
SELECT
  round(coalesce(sum(ms_played), 0) / 60000.0)       AS minutos,
  count(*)                                           AS reproducciones,
  count(DISTINCT content_id)                         AS canciones_distintas
FROM listening_history
WHERE user_id = $1
  AND played_at >= make_date($2, 1, 1)
  AND played_at <  make_date($2 + 1, 1, 1);


-- 3) Top 5 artistas del año (por minutos escuchados)
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
LIMIT 5;


-- 4) Top 5 canciones del año (por cantidad de reproducciones)
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
LIMIT 5;


-- 5) Géneros que predominan en el año (una canción con 2 géneros suma a los dos)
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
ORDER BY minutos DESC;


-- 6) Hábitos de escucha: momento del día (hora de Argentina)
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
ORDER BY reproducciones DESC;


-- Actividad reciente (Home / Perfil): no es una estadística, pero sale de la misma forma
SELECT a.id, a.type, a.created_at, a.details,
       c.id AS content_id, c.title, c.cover_url,
       col.id AS collection_id, col.name AS collection_name
FROM activities a
LEFT JOIN contents    c   ON c.id   = a.content_id
LEFT JOIN collections col ON col.id = a.collection_id
WHERE a.user_id = $1
ORDER BY a.created_at DESC
LIMIT 20;
