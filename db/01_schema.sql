-- =====================================================================
-- Temática: Música
-- Esquema PostgreSQL (>= 13)
--
-- Uso:
--   npm run db:setup
--   (o directo: psql "$DATABASE_URL" -f db/01_schema.sql)
--
-- El script borra y vuelve a crear todo: sirve como migración inicial
-- y para resetear la base en desarrollo. NO correr en producción
-- con datos reales que quieran conservar.
-- =====================================================================

SET client_min_messages = warning;

BEGIN;

DROP TABLE IF EXISTS activities           CASCADE;
DROP TABLE IF EXISTS listening_history    CASCADE;
DROP TABLE IF EXISTS collection_items     CASCADE;
DROP TABLE IF EXISTS collections          CASCADE;
DROP TABLE IF EXISTS reviews              CASCADE;
DROP TABLE IF EXISTS ratings              CASCADE;
DROP TABLE IF EXISTS library_items        CASCADE;
DROP TABLE IF EXISTS content_genres       CASCADE;
DROP TABLE IF EXISTS contents             CASCADE;
DROP TABLE IF EXISTS user_preferred_genres CASCADE;
DROP TABLE IF EXISTS genres               CASCADE;
DROP TABLE IF EXISTS user_preferences     CASCADE;
DROP TABLE IF EXISTS users                CASCADE;

DROP TYPE IF EXISTS content_type   CASCADE;
DROP TYPE IF EXISTS library_status CASCADE;
DROP TYPE IF EXISTS activity_type  CASCADE;
DROP TYPE IF EXISTS play_source    CASCADE;

DROP FUNCTION IF EXISTS set_updated_at() CASCADE;

-- ---------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------

-- Qué tipo de contenido de la API externa se guarda
CREATE TYPE content_type AS ENUM ('track', 'album', 'artist');

-- Estados de la biblioteca (consigna, sección 3.3 - Música)
CREATE TYPE library_status AS ENUM (
  'quiero_escuchar',
  'escuchando',
  'escuchado',
  'favorito'
);

-- Todo lo que se registra como actividad (consigna, sección 3.4)
CREATE TYPE activity_type AS ENUM (
  'library_add',
  'library_remove',
  'status_change',
  'favorite_add',
  'favorite_remove',
  'rating_set',
  'rating_remove',
  'review_create',
  'review_update',
  'review_delete',
  'collection_create',
  'collection_update',
  'collection_delete',
  'collection_add_item',
  'collection_remove_item',
  'profile_update'
);

-- De dónde salió una reproducción del historial
CREATE TYPE play_source AS ENUM ('manual', 'seed');

-- ---------------------------------------------------------------------
-- Función genérica para mantener updated_at
-- ---------------------------------------------------------------------
CREATE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- Usuarios y perfil
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username       VARCHAR(30)  NOT NULL,
  email          VARCHAR(255) NOT NULL,
  password_hash  TEXT         NOT NULL,            -- bcrypt, nunca texto plano
  display_name   VARCHAR(60),
  bio            VARCHAR(300),
  avatar_url     TEXT,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT users_username_format CHECK (username ~ '^[A-Za-z0-9_.]{3,30}$'),
  CONSTRAINT users_email_format    CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);

-- Únicos sin distinguir mayúsculas: "Juan" y "juan" son el mismo usuario
CREATE UNIQUE INDEX users_username_unique ON users (lower(username));
CREATE UNIQUE INDEX users_email_unique    ON users (lower(email));

CREATE TRIGGER users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Preferencias de la cuenta (1 a 1 con users)
CREATE TABLE user_preferences (
  user_id           BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme             VARCHAR(10) NOT NULL DEFAULT 'dark'  CHECK (theme IN ('dark', 'light')),
  language          VARCHAR(5)  NOT NULL DEFAULT 'es',
  settings          JSONB       NOT NULL DEFAULT '{}'::jsonb,  -- reproducción, notificaciones y privacidad
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER user_preferences_updated_at BEFORE UPDATE ON user_preferences
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- Géneros (normalizados para poder hacer estadísticas por género)
-- ---------------------------------------------------------------------
CREATE TABLE genres (
  id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name  VARCHAR(60) NOT NULL
);
CREATE UNIQUE INDEX genres_name_unique ON genres (lower(name));

-- Géneros que el usuario marcó como preferidos en su perfil
CREATE TABLE user_preferred_genres (
  user_id   BIGINT  NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
  genre_id  INTEGER NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, genre_id)
);

-- ---------------------------------------------------------------------
-- Contenidos de la API externa (Deezer)
-- Se guarda una copia mínima de los metadatos para poder reconstruir
-- biblioteca, colecciones y estadísticas sin llamar a la API cada vez.
-- (source, type, external_id) es el identificador estable.
-- ---------------------------------------------------------------------
CREATE TABLE contents (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source              VARCHAR(20)  NOT NULL,          -- 'deezer'
  external_id         VARCHAR(100) NOT NULL,          -- id del contenido en esa API
  type                content_type NOT NULL,
  title               VARCHAR(300) NOT NULL,
  artist_name         VARCHAR(300),                   -- artista principal
  album_title         VARCHAR(300),                   -- sólo para tracks
  cover_url           TEXT,
  release_date        DATE,
  duration_ms         INTEGER CHECK (duration_ms IS NULL OR duration_ms > 0),
  explicit            BOOLEAN NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT contents_external_unique UNIQUE (source, type, external_id)
);

CREATE INDEX contents_artist_idx ON contents (lower(artist_name));

CREATE TRIGGER contents_updated_at BEFORE UPDATE ON contents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE content_genres (
  content_id  BIGINT  NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  genre_id    INTEGER NOT NULL REFERENCES genres(id)   ON DELETE CASCADE,
  PRIMARY KEY (content_id, genre_id)
);
CREATE INDEX content_genres_genre_idx ON content_genres (genre_id);

-- ---------------------------------------------------------------------
-- Biblioteca (estado + favorito)
-- ---------------------------------------------------------------------
CREATE TABLE library_items (
  id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id            BIGINT NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  content_id         BIGINT NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  status             library_status NOT NULL DEFAULT 'quiero_escuchar',
  is_favorite        BOOLEAN        NOT NULL DEFAULT FALSE,
  favorited_at       TIMESTAMPTZ,
  status_changed_at  TIMESTAMPTZ    NOT NULL DEFAULT now(),
  added_at           TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT library_items_user_content_unique UNIQUE (user_id, content_id),
  CONSTRAINT library_items_favorite_consistent
    CHECK (is_favorite = (favorited_at IS NOT NULL))
);

CREATE INDEX library_items_user_status_idx   ON library_items (user_id, status);
CREATE INDEX library_items_user_favorite_idx ON library_items (user_id) WHERE is_favorite;

CREATE TRIGGER library_items_updated_at BEFORE UPDATE ON library_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- Puntuaciones (1 por usuario y contenido)
-- ---------------------------------------------------------------------
CREATE TABLE ratings (
  user_id     BIGINT   NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  content_id  BIGINT   NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  score       SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, content_id)
);

CREATE TRIGGER ratings_updated_at BEFORE UPDATE ON ratings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- Reseñas (1 por usuario y contenido)
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     BIGINT NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  content_id  BIGINT NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  body        TEXT   NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 5000),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT reviews_user_content_unique UNIQUE (user_id, content_id)
);

CREATE INDEX reviews_content_idx ON reviews (content_id);

CREATE TRIGGER reviews_updated_at BEFORE UPDATE ON reviews
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- Colecciones / Playlists
-- ---------------------------------------------------------------------
CREATE TABLE collections (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id      BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name         VARCHAR(80)  NOT NULL CHECK (char_length(btrim(name)) > 0),
  description  VARCHAR(300),
  cover_url    TEXT,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Un usuario no puede tener dos playlists con el mismo nombre
CREATE UNIQUE INDEX collections_user_name_unique ON collections (user_id, lower(name));

CREATE TRIGGER collections_updated_at BEFORE UPDATE ON collections
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Relación N a N entre colecciones y contenidos
CREATE TABLE collection_items (
  collection_id  BIGINT  NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  content_id     BIGINT  NOT NULL REFERENCES contents(id)    ON DELETE CASCADE,
  position       INTEGER NOT NULL DEFAULT 0 CHECK (position >= 0),
  added_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (collection_id, content_id)
);

CREATE INDEX collection_items_content_idx ON collection_items (content_id);

-- ---------------------------------------------------------------------
-- Historial de escucha (para el resumen tipo Wrapped)
-- Cada fila es una reproducción: la carga el usuario ('manual')
-- o viene de los datos de demostración ('seed').
-- ---------------------------------------------------------------------
CREATE TABLE listening_history (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     BIGINT      NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  content_id  BIGINT      NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  played_at   TIMESTAMPTZ NOT NULL,
  ms_played   INTEGER     NOT NULL CHECK (ms_played >= 0),
  source      play_source NOT NULL DEFAULT 'manual',

  -- evita registrar dos veces la misma reproducción
  CONSTRAINT listening_history_unique UNIQUE (user_id, content_id, played_at)
);

CREATE INDEX listening_history_user_date_idx ON listening_history (user_id, played_at);

-- ---------------------------------------------------------------------
-- Actividad del usuario (feed de "actividad reciente")
-- El backend inserta acá en la misma transacción que la acción.
-- content_id / collection_id quedan en NULL si después se borran,
-- y details guarda lo necesario para seguir mostrando el texto.
-- ---------------------------------------------------------------------
CREATE TABLE activities (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id        BIGINT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type           activity_type NOT NULL,
  content_id     BIGINT REFERENCES contents(id)    ON DELETE SET NULL,
  collection_id  BIGINT REFERENCES collections(id) ON DELETE SET NULL,
  details        JSONB         NOT NULL DEFAULT '{}'::jsonb,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX activities_user_date_idx ON activities (user_id, created_at DESC);

COMMIT;
