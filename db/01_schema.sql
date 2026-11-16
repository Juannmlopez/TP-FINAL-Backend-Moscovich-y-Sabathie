-- =====================================================================
-- 01_schema.sql — Crea todas las tablas de la app de música.
-- ATENCIÓN: borra y recrea todo (se pierden los datos).
-- Se ejecuta con: npm run db:setup
-- =====================================================================

-- ---------- Limpieza (orden inverso a las dependencias) ----------
DROP TABLE IF EXISTS activities            CASCADE;
DROP TABLE IF EXISTS listening_history     CASCADE;
DROP TABLE IF EXISTS reviews               CASCADE;
DROP TABLE IF EXISTS ratings               CASCADE;
DROP TABLE IF EXISTS collection_items      CASCADE;
DROP TABLE IF EXISTS collections           CASCADE;
DROP TABLE IF EXISTS library_items         CASCADE;
DROP TABLE IF EXISTS content_genres        CASCADE;
DROP TABLE IF EXISTS user_preferred_genres CASCADE;
DROP TABLE IF EXISTS user_preferences      CASCADE;
DROP TABLE IF EXISTS contents              CASCADE;
DROP TABLE IF EXISTS genres                CASCADE;
DROP TABLE IF EXISTS users                 CASCADE;

DROP TYPE IF EXISTS activity_type  CASCADE;
DROP TYPE IF EXISTS play_source    CASCADE;
DROP TYPE IF EXISTS library_status CASCADE;
DROP TYPE IF EXISTS content_type   CASCADE;

DROP FUNCTION IF EXISTS set_updated_at() CASCADE;

-- ---------- Tipos enumerados ----------
CREATE TYPE content_type AS ENUM ('track', 'album', 'artist');

CREATE TYPE library_status AS ENUM ('quiero_escuchar', 'escuchando', 'escuchado', 'favorito');

CREATE TYPE play_source AS ENUM ('manual', 'spotify_import', 'lastfm_import', 'seed');

CREATE TYPE activity_type AS ENUM (
  'library_add', 'library_remove', 'status_change',
  'favorite_add', 'favorite_remove',
  'rating_set', 'rating_remove',
  'review_create', 'review_update', 'review_delete',
  'collection_create', 'collection_update', 'collection_delete',
  'collection_add_item', 'collection_remove_item',
  'profile_update', 'history_import'
);

-- ---------- Función para mantener updated_at al día ----------
CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ---------- Usuarios ----------
CREATE TABLE users (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username      varchar(30)  NOT NULL,
  email         varchar(255) NOT NULL,
  password_hash text         NOT NULL,
  display_name  varchar(60),
  bio           varchar(300),
  avatar_url    text,
  created_at    timestamptz  NOT NULL DEFAULT now(),
  updated_at    timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT users_username_format CHECK (username ~ '^[A-Za-z0-9_.]{3,30}$'),
  CONSTRAINT users_email_format    CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);
-- Únicos sin distinguir mayúsculas
CREATE UNIQUE INDEX users_username_unique ON users (lower(username));
CREATE UNIQUE INDEX users_email_unique    ON users (lower(email));

-- ---------- Géneros ----------
CREATE TABLE genres (
  id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name varchar(60) NOT NULL
);
CREATE UNIQUE INDEX genres_name_unique ON genres (lower(name));

-- ---------- Preferencias del usuario (1 a 1) ----------
CREATE TABLE user_preferences (
  user_id        bigint      PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme          varchar(10) NOT NULL DEFAULT 'dark' CHECK (theme IN ('dark', 'light')),
  language       varchar(5)  NOT NULL DEFAULT 'es',
  show_explicit  boolean     NOT NULL DEFAULT true,
  profile_public boolean     NOT NULL DEFAULT false,
  yearly_goal    integer     CHECK (yearly_goal IS NULL OR yearly_goal > 0),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_preferred_genres (
  user_id  bigint  NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
  genre_id integer NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, genre_id)
);

-- ---------- Contenidos (caché local de canciones/álbumes/artistas) ----------
CREATE TABLE contents (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source             varchar(20)  NOT NULL,          -- de qué API vino
  external_id        varchar(100) NOT NULL,          -- id en esa API
  type               content_type NOT NULL,
  title              varchar(300) NOT NULL,
  artist_name        varchar(300),
  artist_external_id varchar(100),
  album_title        varchar(300),
  cover_url          text,
  release_date       date,
  duration_ms        integer CHECK (duration_ms IS NULL OR duration_ms > 0),
  explicit           boolean NOT NULL DEFAULT false,
  metadata           jsonb   NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT contents_external_unique UNIQUE (source, type, external_id)
);
CREATE INDEX contents_artist_idx ON contents (lower(artist_name));

CREATE TABLE content_genres (
  content_id bigint  NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  genre_id   integer NOT NULL REFERENCES genres(id)   ON DELETE CASCADE,
  PRIMARY KEY (content_id, genre_id)
);
CREATE INDEX content_genres_genre_idx ON content_genres (genre_id);

-- ---------- Biblioteca y favoritos ----------
CREATE TABLE library_items (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id           bigint NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  content_id        bigint NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  status            library_status NOT NULL DEFAULT 'quiero_escuchar',
  is_favorite       boolean NOT NULL DEFAULT false,
  favorited_at      timestamptz,
  status_changed_at timestamptz NOT NULL DEFAULT now(),
  finished_at       timestamptz,
  added_at          timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT library_items_user_content_unique UNIQUE (user_id, content_id),
  -- Si es favorito tiene fecha, y si no, no
  CONSTRAINT library_items_favorite_consistent CHECK (is_favorite = (favorited_at IS NOT NULL))
);
CREATE INDEX library_items_user_status_idx   ON library_items (user_id, status);
CREATE INDEX library_items_user_favorite_idx ON library_items (user_id) WHERE is_favorite;

-- ---------- Colecciones (playlists) ----------
CREATE TABLE collections (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        varchar(80) NOT NULL CHECK (char_length(btrim(name)) > 0),
  description varchar(300),
  cover_url   text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
-- Un usuario no puede repetir nombre de colección
CREATE UNIQUE INDEX collections_user_name_unique ON collections (user_id, lower(name));

CREATE TABLE collection_items (
  collection_id bigint  NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  content_id    bigint  NOT NULL REFERENCES contents(id)    ON DELETE CASCADE,
  position      integer NOT NULL DEFAULT 0 CHECK (position >= 0),
  added_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (collection_id, content_id)
);
CREATE INDEX collection_items_content_idx ON collection_items (content_id);

-- ---------- Puntuaciones (1 a 5) ----------
CREATE TABLE ratings (
  user_id    bigint   NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  content_id bigint   NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  score      smallint NOT NULL CHECK (score BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, content_id)
);

-- ---------- Reseñas (una por usuario y contenido) ----------
CREATE TABLE reviews (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    bigint NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  content_id bigint NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  body       text   NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 5000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reviews_user_content_unique UNIQUE (user_id, content_id)
);
CREATE INDEX reviews_content_idx ON reviews (content_id);

-- ---------- Historial de escucha (base de las estadísticas) ----------
CREATE TABLE listening_history (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    bigint NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  content_id bigint NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
  played_at  timestamptz NOT NULL,
  ms_played  integer NOT NULL CHECK (ms_played >= 0),
  source     play_source NOT NULL DEFAULT 'manual',
  CONSTRAINT listening_history_unique UNIQUE (user_id, content_id, played_at)
);
CREATE INDEX listening_history_user_date_idx ON listening_history (user_id, played_at);

-- ---------- Actividad del usuario (feed) ----------
CREATE TABLE activities (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type          activity_type NOT NULL,
  content_id    bigint REFERENCES contents(id)    ON DELETE SET NULL,
  collection_id bigint REFERENCES collections(id) ON DELETE SET NULL,
  details       jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX activities_user_date_idx ON activities (user_id, created_at DESC);

-- ---------- Triggers de updated_at ----------
CREATE TRIGGER users_updated_at            BEFORE UPDATE ON users            FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER user_preferences_updated_at BEFORE UPDATE ON user_preferences FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER contents_updated_at         BEFORE UPDATE ON contents         FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER library_items_updated_at    BEFORE UPDATE ON library_items    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER collections_updated_at      BEFORE UPDATE ON collections      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER ratings_updated_at          BEFORE UPDATE ON ratings          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER reviews_updated_at          BEFORE UPDATE ON reviews          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
