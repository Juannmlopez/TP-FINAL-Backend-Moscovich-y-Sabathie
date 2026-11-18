-- =====================================================================
--  Datos de la cuenta de demostración
--
-- Uso:
--   npm run db:seed        (corre 01_schema.sql y después este archivo)
--
-- Usuario: demo   -  Contraseña: root
-- scripts/db-setup.js define la setting de sesión 'demo.password' con
-- DEMO_PASSWORD del .env antes de ejecutar este archivo. Si se corre a mano
-- (pgAdmin / psql) sin definirla, la contraseña de la cuenta demo es 'root'.
--
-- Se puede correr varias veces: borra la cuenta demo y la vuelve a crear.
-- Las fechas son relativas a now(), así la actividad siempre es "reciente"
-- y el resumen anual siempre tiene datos del año en curso.
--
-- Los contenidos usan los ids y portadas reales de Deezer (la API que usa
-- el backend), así la vista de Detalle funciona con la cuenta demo.
-- =====================================================================

-- Sólo se usa para hashear la contraseña con bcrypt ($2a$), compatible con
-- bcryptjs en Node. El backend NO depende de esta extensión.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

BEGIN;

-- El historial "aleatorio" sale siempre igual
SELECT setseed(0.42);

DELETE FROM users WHERE lower(username) = 'demo';

-- ---------------------------------------------------------------------
-- Usuario y perfil
-- ---------------------------------------------------------------------
INSERT INTO users (username, email, password_hash, display_name, bio, avatar_url, created_at)
VALUES (
  'demo',
  'demo@mycollection.app',
  crypt(COALESCE(NULLIF(current_setting('demo.password', true), ''), 'root'), gen_salt('bf', 10)),
  'Demo',
  'Rock nacional para el bondi, electrónica para estudiar y algo de reggaetón los viernes.',
  'https://api.dicebear.com/9.x/thumbs/svg?seed=demo',
  now() - interval '400 days'
);

INSERT INTO user_preferences (user_id, theme, language)
SELECT id, 'dark', 'es' FROM users WHERE username = 'demo';

-- ---------------------------------------------------------------------
-- Géneros (catálogo base: también es la lista que puede elegir
-- cualquier usuario como géneros preferidos)
-- ---------------------------------------------------------------------
INSERT INTO genres (name) VALUES
  ('Rock nacional'), ('Rock alternativo'), ('Rock'), ('Pop'), ('Pop latino'),
  ('Reggaetón'), ('Electrónica'), ('Folklore'), ('Hip hop'), ('Indie')
ON CONFLICT DO NOTHING;

INSERT INTO user_preferred_genres (user_id, genre_id)
SELECT u.id, g.id
FROM users u JOIN genres g ON g.name IN ('Rock nacional', 'Electrónica', 'Rock alternativo')
WHERE u.username = 'demo';

-- ---------------------------------------------------------------------
-- Contenidos (catálogo usado por la demo, con ids reales de Deezer)
-- ---------------------------------------------------------------------
CREATE TEMP TABLE seed_contents (
  ref                TEXT PRIMARY KEY,   -- clave interna del seed
  type               content_type,
  external_id        TEXT,               -- id en Deezer
  title              TEXT,
  artist             TEXT,
  album              TEXT,
  release_date       DATE,
  duration_ms        INTEGER,
  cover_url          TEXT,
  genres             TEXT[]
);

INSERT INTO seed_contents VALUES
  -- álbumes
  ('alb_cancion_animal', 'album', '1222449',   'Canción Animal',         'Soda Stereo',     NULL, '1990-08-07', NULL, 'https://cdn-images.dzcdn.net/images/cover/88ade8cebd318b62c5e5f86825994c4e/1000x1000-000000-80-0-0.jpg', ARRAY['Rock nacional','Rock']),
  ('alb_clics',          'album', '259292',    'Clics Modernos',         'Charly García',     NULL, '1983-11-01', NULL, 'https://cdn-images.dzcdn.net/images/cover/37ad6b28e5958ed75655a7f021b84423/1000x1000-000000-80-0-0.jpg', ARRAY['Rock nacional']),
  ('alb_bocanada',       'album', '373731',    'Bocanada',               'Gustavo Cerati',     NULL, '1999-06-14', NULL, 'https://cdn-images.dzcdn.net/images/cover/d0532f8fbe9cb0eabd385508e52b597f/1000x1000-000000-80-0-0.jpg', ARRAY['Rock alternativo','Rock nacional']),
  ('alb_ram',            'album', '6575789',   'Random Access Memories', 'Daft Punk',       NULL, '2013-05-17', NULL, 'https://cdn-images.dzcdn.net/images/cover/311bba0fc112d15f72c8b5a65f0456c1/1000x1000-000000-80-0-0.jpg', ARRAY['Electrónica']),
  ('alb_ok_computer',    'album', '14879699',  'OK Computer',            'Radiohead',      NULL, '1997-05-21', NULL, 'https://cdn-images.dzcdn.net/images/cover/05a186e0a859a36f9cd51cdae2158fe1/1000x1000-000000-80-0-0.jpg', ARRAY['Rock alternativo']),
  ('alb_unverano',       'album', '316164367', 'Un Verano Sin Ti',       'Bad Bunny', NULL, '2022-05-06', NULL, 'https://cdn-images.dzcdn.net/images/cover/b29d1070377b784384c2456093f96a66/1000x1000-000000-80-0-0.jpg', ARRAY['Reggaetón','Pop latino']),
  ('alb_1989',           'album', '9007779',   '1989',                   'Taylor Swift',    NULL, '2014-10-27', NULL, 'https://cdn-images.dzcdn.net/images/cover/8c39b232a5edecdf5fffc14f551fa42b/1000x1000-000000-80-0-0.jpg', ARRAY['Pop']),
  ('alb_cantora',        'album', '369524',    'Cantora',                'Mercedes Sosa',    NULL, '2009-04-28', NULL, 'https://cdn-images.dzcdn.net/images/cover/947662a24a2210335f2dd0da8b9f8eb6/1000x1000-000000-80-0-0.jpg', ARRAY['Folklore']),
  -- canciones
  ('trk_musica_ligera',  'track', '13342210',   'De música ligera',       'Soda Stereo',     'Canción Animal',   '1990-08-07', 213000, 'https://cdn-images.dzcdn.net/images/cover/88ade8cebd318b62c5e5f86825994c4e/1000x1000-000000-80-0-0.jpg', ARRAY['Rock nacional','Rock']),
  ('trk_crimen',         'track', '13255149',   'Crimen',                 'Gustavo Cerati',     'Ahí Vamos',   '2006-04-04', 232000, 'https://cdn-images.dzcdn.net/images/cover/994b58426935136ff774ff4ee880931b/1000x1000-000000-80-0-0.jpg', ARRAY['Rock alternativo','Rock nacional']),
  ('trk_get_lucky',      'track', '67238735',   'Get Lucky',              'Daft Punk',       'Random Access Memories',   '2013-05-17', 367000, 'https://cdn-images.dzcdn.net/images/cover/311bba0fc112d15f72c8b5a65f0456c1/1000x1000-000000-80-0-0.jpg', ARRAY['Electrónica']),
  ('trk_karma_police',   'track', '138539981',  'Karma Police',           'Radiohead',      'OK Computer',  '1997-05-21', 264000, 'https://cdn-images.dzcdn.net/images/cover/05a186e0a859a36f9cd51cdae2158fe1/1000x1000-000000-80-0-0.jpg', ARRAY['Rock alternativo']),
  ('trk_titi',           'track', '1741494317', 'Tití Me Preguntó',       'Bad Bunny', 'Un Verano Sin Ti', '2022-05-06', 243000, 'https://cdn-images.dzcdn.net/images/cover/b29d1070377b784384c2456093f96a66/1000x1000-000000-80-0-0.jpg', ARRAY['Reggaetón','Pop latino']),
  ('trk_dinosaurios',    'track', '2674969',    'Los Dinosaurios',        'Charly García',     'Clics Modernos',    '1983-11-01', 207000, 'https://cdn-images.dzcdn.net/images/cover/37ad6b28e5958ed75655a7f021b84423/1000x1000-000000-80-0-0.jpg', ARRAY['Rock nacional']),
  ('trk_flaca',          'track', '786580',     'Flaca',                  'Andrés Calamaro',     'Alta Suciedad',     '1997-06-03', 276000, 'https://cdn-images.dzcdn.net/images/cover/f5885eb6b37eb30866b5088341a4f946/1000x1000-000000-80-0-0.jpg', ARRAY['Rock nacional']),
  ('trk_blank_space',    'track', '89077521',   'Blank Space',            'Taylor Swift',    '1989',                   '2014-10-27', 232000, 'https://cdn-images.dzcdn.net/images/cover/8c39b232a5edecdf5fffc14f551fa42b/1000x1000-000000-80-0-0.jpg', ARRAY['Pop']);

INSERT INTO contents (source, external_id, type, title, artist_name,
                      album_title, cover_url, release_date, duration_ms)
SELECT 'deezer', external_id, type, title, artist,
       album, cover_url, release_date, duration_ms
FROM seed_contents
ON CONFLICT (source, type, external_id) DO NOTHING;

INSERT INTO content_genres (content_id, genre_id)
SELECT c.id, g.id
FROM seed_contents s
JOIN contents c ON c.source = 'deezer' AND c.type = s.type AND c.external_id = s.external_id
CROSS JOIN LATERAL unnest(s.genres) AS gname
JOIN genres g ON g.name = gname
ON CONFLICT DO NOTHING;

-- Vista auxiliar para referenciar contenidos por su ref del seed
CREATE TEMP VIEW sc AS
SELECT s.ref, c.id AS content_id
FROM seed_contents s
JOIN contents c ON c.source = 'deezer' AND c.type = s.type AND c.external_id = s.external_id;

-- ---------------------------------------------------------------------
-- Biblioteca: 14 contenidos, 4 estados, 6 favoritos
-- ---------------------------------------------------------------------
INSERT INTO library_items (user_id, content_id, status, is_favorite, favorited_at, added_at, status_changed_at)
SELECT u.id, sc.content_id, v.status::library_status, v.fav,
       CASE WHEN v.fav THEN now() - (v.days_ago - 2) * interval '1 day' END,
       now() - v.days_ago * interval '1 day',
       now() - (v.days_ago - 1) * interval '1 day'
FROM users u
CROSS JOIN (VALUES
  ('alb_cancion_animal', 'favorito',        TRUE,  300),
  ('alb_clics',          'escuchado',       TRUE,  250),
  ('alb_bocanada',       'favorito',        TRUE,  200),
  ('alb_ram',            'escuchado',       FALSE, 150),
  ('alb_ok_computer',    'escuchando',      FALSE,  40),
  ('alb_unverano',       'escuchado',       FALSE, 120),
  ('alb_1989',           'quiero_escuchar', FALSE,   6),
  ('alb_cantora',        'quiero_escuchar', FALSE,   3),
  ('trk_musica_ligera',  'favorito',        TRUE,  280),
  ('trk_crimen',         'escuchado',       TRUE,  180),
  ('trk_get_lucky',      'escuchado',       FALSE, 140),
  ('trk_karma_police',   'escuchando',      FALSE,  30),
  ('trk_titi',           'escuchado',       FALSE, 110),
  ('trk_flaca',          'favorito',        TRUE,   90)
) AS v(ref, status, fav, days_ago)
JOIN sc ON sc.ref = v.ref
WHERE u.username = 'demo';

-- ---------------------------------------------------------------------
-- Puntuaciones (8) y reseñas (4)
-- ---------------------------------------------------------------------
INSERT INTO ratings (user_id, content_id, score, created_at, updated_at)
SELECT u.id, sc.content_id, v.score, now() - v.days_ago * interval '1 day', now() - v.days_ago * interval '1 day'
FROM users u
CROSS JOIN (VALUES
  ('alb_cancion_animal', 5, 295),
  ('alb_clics',          5, 245),
  ('alb_bocanada',       5, 195),
  ('alb_ram',            4, 145),
  ('alb_unverano',       3, 115),
  ('trk_crimen',         5, 175),
  ('trk_get_lucky',      4, 135),
  ('trk_titi',           3, 105)
) AS v(ref, score, days_ago)
JOIN sc ON sc.ref = v.ref
WHERE u.username = 'demo';

INSERT INTO reviews (user_id, content_id, body, created_at, updated_at)
SELECT u.id, sc.content_id, v.body, now() - v.days_ago * interval '1 day', now() - v.edited_ago * interval '1 day'
FROM users u
CROSS JOIN (VALUES
  ('alb_cancion_animal',
   'El disco más redondo de Soda. No tiene un tema de relleno y la producción no envejeció nada.', 294, 294),
  ('alb_bocanada',
   'Cerati solista en su punto más experimental. Hay que escucharlo entero y con auriculares.', 194, 60),
  ('alb_ram',
   'Suena a disco grabado con músicos de verdad. Get Lucky es lo más conocido pero Touch es lo mejor.', 144, 144),
  ('trk_crimen',
   'Una de esas canciones que te sabés de memoria aunque no la busques.', 174, 174)
) AS v(ref, body, days_ago, edited_ago)
JOIN sc ON sc.ref = v.ref
WHERE u.username = 'demo';

-- ---------------------------------------------------------------------
-- Colecciones / playlists (3)
-- ---------------------------------------------------------------------
INSERT INTO collections (user_id, name, description, created_at)
SELECT u.id, v.name, v.description, now() - v.days_ago * interval '1 day'
FROM users u
CROSS JOIN (VALUES
  ('Rock nacional de siempre', 'Lo que no puede faltar en ninguna previa.',   260),
  ('Para estudiar',            'Instrumental y cosas que no distraen.',        150),
  ('Viernes',                  'Para arrancar el finde.',                       12)
) AS v(name, description, days_ago)
WHERE u.username = 'demo';

INSERT INTO collection_items (collection_id, content_id, position, added_at)
SELECT c.id, sc.content_id, v.pos, c.created_at + v.pos * interval '1 hour'
FROM collections c
JOIN users u ON u.id = c.user_id AND u.username = 'demo'
JOIN (VALUES
  ('Rock nacional de siempre', 'trk_musica_ligera', 0),
  ('Rock nacional de siempre', 'trk_dinosaurios',   1),
  ('Rock nacional de siempre', 'trk_flaca',         2),
  ('Rock nacional de siempre', 'trk_crimen',        3),
  ('Para estudiar',            'alb_ram',           0),
  ('Para estudiar',            'alb_ok_computer',   1),
  ('Para estudiar',            'trk_karma_police',  2),
  ('Viernes',                  'trk_titi',          0),
  ('Viernes',                  'trk_get_lucky',     1),
  ('Viernes',                  'trk_blank_space',   2)
) AS v(cname, ref, pos) ON v.cname = c.name
JOIN sc ON sc.ref = v.ref;

-- ---------------------------------------------------------------------
-- Historial de escucha: ~1 año de reproducciones de las canciones.
-- Cada canción tiene un "peso" (qué tanto se escucha) y las horas
-- se concentran a la mañana (viaje) y a la noche.
-- ---------------------------------------------------------------------
INSERT INTO listening_history (user_id, content_id, played_at, ms_played, source)
SELECT u.id, sc.content_id, p.played_at,
       CASE WHEN random() < 0.85 THEN c.duration_ms              -- escuchada completa
            ELSE (c.duration_ms * (0.2 + random() * 0.6))::int   -- salteada
       END,
       'seed'
FROM users u
CROSS JOIN (VALUES
  ('trk_musica_ligera', 0.55),
  ('trk_crimen',        0.50),
  ('trk_flaca',         0.40),
  ('trk_get_lucky',     0.35),
  ('trk_dinosaurios',   0.25),
  ('trk_titi',          0.25),
  ('trk_karma_police',  0.20),
  ('trk_blank_space',   0.08)
) AS w(ref, weight)
JOIN sc ON sc.ref = w.ref
JOIN contents c ON c.id = sc.content_id
CROSS JOIN LATERAL (
  SELECT date_trunc('day', now()) - d * interval '1 day'
         -- 11 y 23 UTC = 8 y 20 hs en Argentina (viaje a la mañana y a la noche)
         + (CASE WHEN random() < 0.5 THEN 11 ELSE 23 END) * interval '1 hour'
         + (random() * 180) * interval '1 minute' AS played_at
  FROM generate_series(1, 365) AS d
  WHERE random() < w.weight
) p
WHERE u.username = 'demo'
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- Actividad: se reconstruye a partir de lo cargado arriba,
-- igual que la registraría el backend en cada acción.
-- ---------------------------------------------------------------------
INSERT INTO activities (user_id, type, content_id, details, created_at)
SELECT li.user_id, 'library_add', li.content_id,
       jsonb_build_object('title', c.title, 'artist', c.artist_name), li.added_at
FROM library_items li JOIN contents c ON c.id = li.content_id
JOIN users u ON u.id = li.user_id AND u.username = 'demo';

INSERT INTO activities (user_id, type, content_id, details, created_at)
SELECT li.user_id, 'status_change', li.content_id,
       jsonb_build_object('title', c.title, 'from', 'quiero_escuchar', 'to', li.status), li.status_changed_at
FROM library_items li JOIN contents c ON c.id = li.content_id
JOIN users u ON u.id = li.user_id AND u.username = 'demo'
WHERE li.status <> 'quiero_escuchar';

INSERT INTO activities (user_id, type, content_id, details, created_at)
SELECT li.user_id, 'favorite_add', li.content_id,
       jsonb_build_object('title', c.title), li.favorited_at
FROM library_items li JOIN contents c ON c.id = li.content_id
JOIN users u ON u.id = li.user_id AND u.username = 'demo'
WHERE li.is_favorite;

INSERT INTO activities (user_id, type, content_id, details, created_at)
SELECT r.user_id, 'rating_set', r.content_id,
       jsonb_build_object('title', c.title, 'score', r.score), r.created_at
FROM ratings r JOIN contents c ON c.id = r.content_id
JOIN users u ON u.id = r.user_id AND u.username = 'demo';

INSERT INTO activities (user_id, type, content_id, details, created_at)
SELECT r.user_id, 'review_create', r.content_id,
       jsonb_build_object('title', c.title, 'review_id', r.id), r.created_at
FROM reviews r JOIN contents c ON c.id = r.content_id
JOIN users u ON u.id = r.user_id AND u.username = 'demo';

INSERT INTO activities (user_id, type, content_id, details, created_at)
SELECT r.user_id, 'review_update', r.content_id,
       jsonb_build_object('title', c.title, 'review_id', r.id), r.updated_at
FROM reviews r JOIN contents c ON c.id = r.content_id
JOIN users u ON u.id = r.user_id AND u.username = 'demo'
WHERE r.updated_at > r.created_at;

INSERT INTO activities (user_id, type, collection_id, details, created_at)
SELECT col.user_id, 'collection_create', col.id,
       jsonb_build_object('name', col.name), col.created_at
FROM collections col JOIN users u ON u.id = col.user_id AND u.username = 'demo';

INSERT INTO activities (user_id, type, content_id, collection_id, details, created_at)
SELECT col.user_id, 'collection_add_item', ci.content_id, col.id,
       jsonb_build_object('name', col.name, 'title', c.title), ci.added_at
FROM collection_items ci
JOIN collections col ON col.id = ci.collection_id
JOIN contents c ON c.id = ci.content_id
JOIN users u ON u.id = col.user_id AND u.username = 'demo';

INSERT INTO activities (user_id, type, details, created_at)
SELECT id, 'profile_update', jsonb_build_object('fields', jsonb_build_array('bio')), now() - interval '2 days'
FROM users WHERE username = 'demo';

DROP VIEW sc;
DROP TABLE seed_contents;

COMMIT;

-- Resumen de lo que quedó cargado
SELECT
  (SELECT count(*) FROM library_items     li JOIN users u ON u.id = li.user_id WHERE u.username = 'demo')                   AS biblioteca,
  (SELECT count(*) FROM library_items     li JOIN users u ON u.id = li.user_id WHERE u.username = 'demo' AND li.is_favorite) AS favoritos,
  (SELECT count(DISTINCT status) FROM library_items li JOIN users u ON u.id = li.user_id WHERE u.username = 'demo')          AS estados,
  (SELECT count(*) FROM ratings           r  JOIN users u ON u.id = r.user_id  WHERE u.username = 'demo')                   AS puntuaciones,
  (SELECT count(*) FROM reviews           r  JOIN users u ON u.id = r.user_id  WHERE u.username = 'demo')                   AS resenas,
  (SELECT count(*) FROM collections       c  JOIN users u ON u.id = c.user_id  WHERE u.username = 'demo')                   AS colecciones,
  (SELECT count(*) FROM listening_history h  JOIN users u ON u.id = h.user_id  WHERE u.username = 'demo')                   AS reproducciones,
  (SELECT count(*) FROM activities        a  JOIN users u ON u.id = a.user_id  WHERE u.username = 'demo')                   AS actividades;
