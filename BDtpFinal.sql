--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2
-- Dumped by pg_dump version 16.2

-- Started on 2026-11-16 08:26:31

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;
SET demo.password = 'root';
--
-- TOC entry 2 (class 3079 OID 16384)
-- Name: adminpack; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS adminpack WITH SCHEMA pg_catalog;


--
-- TOC entry 4982 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION adminpack; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION adminpack IS 'administrative functions for PostgreSQL';


--
-- TOC entry 868 (class 1247 OID 16416)
-- Name: activity_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.activity_type AS ENUM (
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
    'profile_update',
    'history_import'
);


ALTER TYPE public.activity_type OWNER TO postgres;

--
-- TOC entry 862 (class 1247 OID 16399)
-- Name: content_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.content_type AS ENUM (
    'track',
    'album',
    'artist'
);


ALTER TYPE public.content_type OWNER TO postgres;

--
-- TOC entry 865 (class 1247 OID 16406)
-- Name: library_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.library_status AS ENUM (
    'quiero_escuchar',
    'escuchando',
    'escuchado',
    'favorito'
);


ALTER TYPE public.library_status OWNER TO postgres;

--
-- TOC entry 871 (class 1247 OID 16452)
-- Name: play_source; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.play_source AS ENUM (
    'manual',
    'spotify_import',
    'lastfm_import',
    'seed'
);


ALTER TYPE public.play_source OWNER TO postgres;

--
-- TOC entry 237 (class 1255 OID 16461)
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 236 (class 1259 OID 16680)
-- Name: activities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.activities (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    type public.activity_type NOT NULL,
    content_id bigint,
    collection_id bigint,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.activities OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16679)
-- Name: activities_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.activities ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 232 (class 1259 OID 16639)
-- Name: collection_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.collection_items (
    collection_id bigint NOT NULL,
    content_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT collection_items_position_check CHECK (("position" >= 0))
);


ALTER TABLE public.collection_items OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16622)
-- Name: collections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.collections (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying(80) NOT NULL,
    description character varying(300),
    cover_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT collections_name_check CHECK ((char_length(btrim((name)::text)) > 0))
);


ALTER TABLE public.collections OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16621)
-- Name: collections_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.collections ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.collections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 224 (class 1259 OID 16534)
-- Name: content_genres; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.content_genres (
    content_id bigint NOT NULL,
    genre_id integer NOT NULL
);


ALTER TABLE public.content_genres OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16518)
-- Name: contents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contents (
    id bigint NOT NULL,
    source character varying(20) NOT NULL,
    external_id character varying(100) NOT NULL,
    type public.content_type NOT NULL,
    title character varying(300) NOT NULL,
    artist_name character varying(300),
    artist_external_id character varying(100),
    album_title character varying(300),
    cover_url text,
    release_date date,
    duration_ms integer,
    explicit boolean DEFAULT false NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contents_duration_ms_check CHECK (((duration_ms IS NULL) OR (duration_ms > 0)))
);


ALTER TABLE public.contents OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16517)
-- Name: contents_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.contents ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.contents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 220 (class 1259 OID 16496)
-- Name: genres; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.genres (
    id integer NOT NULL,
    name character varying(60) NOT NULL
);


ALTER TABLE public.genres OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16495)
-- Name: genres_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.genres ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.genres_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 16551)
-- Name: library_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.library_items (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    content_id bigint NOT NULL,
    status public.library_status DEFAULT 'quiero_escuchar'::public.library_status NOT NULL,
    is_favorite boolean DEFAULT false NOT NULL,
    favorited_at timestamp with time zone,
    status_changed_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT library_items_favorite_consistent CHECK ((is_favorite = (favorited_at IS NOT NULL)))
);


ALTER TABLE public.library_items OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16550)
-- Name: library_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.library_items ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.library_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 234 (class 1259 OID 16659)
-- Name: listening_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.listening_history (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    content_id bigint NOT NULL,
    played_at timestamp with time zone NOT NULL,
    ms_played integer NOT NULL,
    source public.play_source DEFAULT 'manual'::public.play_source NOT NULL,
    CONSTRAINT listening_history_ms_played_check CHECK ((ms_played >= 0))
);


ALTER TABLE public.listening_history OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 16658)
-- Name: listening_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.listening_history ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.listening_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 227 (class 1259 OID 16577)
-- Name: ratings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ratings (
    user_id bigint NOT NULL,
    content_id bigint NOT NULL,
    score smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= 1) AND (score <= 5)))
);


ALTER TABLE public.ratings OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16597)
-- Name: reviews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reviews (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    content_id bigint NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reviews_body_check CHECK (((char_length(btrim(body)) >= 1) AND (char_length(btrim(body)) <= 5000)))
);


ALTER TABLE public.reviews OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16596)
-- Name: reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.reviews ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 218 (class 1259 OID 16477)
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_preferences (
    user_id bigint NOT NULL,
    theme character varying(10) DEFAULT 'dark'::character varying NOT NULL,
    language character varying(5) DEFAULT 'es'::character varying NOT NULL,
    show_explicit boolean DEFAULT true NOT NULL,
    profile_public boolean DEFAULT false NOT NULL,
    yearly_goal integer,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_preferences_theme_check CHECK (((theme)::text = ANY ((ARRAY['dark'::character varying, 'light'::character varying])::text[]))),
    CONSTRAINT user_preferences_yearly_goal_check CHECK (((yearly_goal IS NULL) OR (yearly_goal > 0)))
);


ALTER TABLE public.user_preferences OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16502)
-- Name: user_preferred_genres; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_preferred_genres (
    user_id bigint NOT NULL,
    genre_id integer NOT NULL
);


ALTER TABLE public.user_preferred_genres OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 16463)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    username character varying(30) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash text NOT NULL,
    display_name character varying(60),
    bio character varying(300),
    avatar_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT users_email_format CHECK (((email)::text ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text)),
    CONSTRAINT users_username_format CHECK (((username)::text ~ '^[A-Za-z0-9_.]{3,30}$'::text))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 16462)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.users ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 4976 (class 0 OID 16680)
-- Dependencies: 236
-- Data for Name: activities; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4972 (class 0 OID 16639)
-- Dependencies: 232
-- Data for Name: collection_items; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4971 (class 0 OID 16622)
-- Dependencies: 231
-- Data for Name: collections; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4964 (class 0 OID 16534)
-- Dependencies: 224
-- Data for Name: content_genres; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4963 (class 0 OID 16518)
-- Dependencies: 223
-- Data for Name: contents; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4960 (class 0 OID 16496)
-- Dependencies: 220
-- Data for Name: genres; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4966 (class 0 OID 16551)
-- Dependencies: 226
-- Data for Name: library_items; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4974 (class 0 OID 16659)
-- Dependencies: 234
-- Data for Name: listening_history; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4967 (class 0 OID 16577)
-- Dependencies: 227
-- Data for Name: ratings; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4969 (class 0 OID 16597)
-- Dependencies: 229
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4958 (class 0 OID 16477)
-- Dependencies: 218
-- Data for Name: user_preferences; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4961 (class 0 OID 16502)
-- Dependencies: 221
-- Data for Name: user_preferred_genres; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4957 (class 0 OID 16463)
-- Dependencies: 217
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4983 (class 0 OID 0)
-- Dependencies: 235
-- Name: activities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.activities_id_seq', 1, false);


--
-- TOC entry 4984 (class 0 OID 0)
-- Dependencies: 230
-- Name: collections_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.collections_id_seq', 1, false);


--
-- TOC entry 4985 (class 0 OID 0)
-- Dependencies: 222
-- Name: contents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contents_id_seq', 1, false);


--
-- TOC entry 4986 (class 0 OID 0)
-- Dependencies: 219
-- Name: genres_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.genres_id_seq', 1, false);


--
-- TOC entry 4987 (class 0 OID 0)
-- Dependencies: 225
-- Name: library_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.library_items_id_seq', 1, false);


--
-- TOC entry 4988 (class 0 OID 0)
-- Dependencies: 233
-- Name: listening_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.listening_history_id_seq', 1, false);


--
-- TOC entry 4989 (class 0 OID 0)
-- Dependencies: 228
-- Name: reviews_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reviews_id_seq', 1, false);


--
-- TOC entry 4990 (class 0 OID 0)
-- Dependencies: 216
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 1, false);


--
-- TOC entry 4785 (class 2606 OID 16688)
-- Name: activities activities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- TOC entry 4778 (class 2606 OID 16646)
-- Name: collection_items collection_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collection_items
    ADD CONSTRAINT collection_items_pkey PRIMARY KEY (collection_id, content_id);


--
-- TOC entry 4774 (class 2606 OID 16631)
-- Name: collections collections_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (id);


--
-- TOC entry 4759 (class 2606 OID 16538)
-- Name: content_genres content_genres_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_genres
    ADD CONSTRAINT content_genres_pkey PRIMARY KEY (content_id, genre_id);


--
-- TOC entry 4754 (class 2606 OID 16531)
-- Name: contents contents_external_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contents
    ADD CONSTRAINT contents_external_unique UNIQUE (source, type, external_id);


--
-- TOC entry 4756 (class 2606 OID 16529)
-- Name: contents contents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contents
    ADD CONSTRAINT contents_pkey PRIMARY KEY (id);


--
-- TOC entry 4749 (class 2606 OID 16500)
-- Name: genres genres_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.genres
    ADD CONSTRAINT genres_pkey PRIMARY KEY (id);


--
-- TOC entry 4761 (class 2606 OID 16561)
-- Name: library_items library_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.library_items
    ADD CONSTRAINT library_items_pkey PRIMARY KEY (id);


--
-- TOC entry 4763 (class 2606 OID 16563)
-- Name: library_items library_items_user_content_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.library_items
    ADD CONSTRAINT library_items_user_content_unique UNIQUE (user_id, content_id);


--
-- TOC entry 4780 (class 2606 OID 16665)
-- Name: listening_history listening_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.listening_history
    ADD CONSTRAINT listening_history_pkey PRIMARY KEY (id);


--
-- TOC entry 4782 (class 2606 OID 16667)
-- Name: listening_history listening_history_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.listening_history
    ADD CONSTRAINT listening_history_unique UNIQUE (user_id, content_id, played_at);


--
-- TOC entry 4767 (class 2606 OID 16584)
-- Name: ratings ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (user_id, content_id);


--
-- TOC entry 4770 (class 2606 OID 16606)
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- TOC entry 4772 (class 2606 OID 16608)
-- Name: reviews reviews_user_content_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_content_unique UNIQUE (user_id, content_id);


--
-- TOC entry 4746 (class 2606 OID 16488)
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4751 (class 2606 OID 16506)
-- Name: user_preferred_genres user_preferred_genres_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_preferred_genres
    ADD CONSTRAINT user_preferred_genres_pkey PRIMARY KEY (user_id, genre_id);


--
-- TOC entry 4743 (class 2606 OID 16473)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4786 (class 1259 OID 16704)
-- Name: activities_user_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX activities_user_date_idx ON public.activities USING btree (user_id, created_at DESC);


--
-- TOC entry 4776 (class 1259 OID 16657)
-- Name: collection_items_content_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX collection_items_content_idx ON public.collection_items USING btree (content_id);


--
-- TOC entry 4775 (class 1259 OID 16637)
-- Name: collections_user_name_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX collections_user_name_unique ON public.collections USING btree (user_id, lower((name)::text));


--
-- TOC entry 4757 (class 1259 OID 16549)
-- Name: content_genres_genre_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX content_genres_genre_idx ON public.content_genres USING btree (genre_id);


--
-- TOC entry 4752 (class 1259 OID 16532)
-- Name: contents_artist_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contents_artist_idx ON public.contents USING btree (lower((artist_name)::text));


--
-- TOC entry 4747 (class 1259 OID 16501)
-- Name: genres_name_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX genres_name_unique ON public.genres USING btree (lower((name)::text));


--
-- TOC entry 4764 (class 1259 OID 16575)
-- Name: library_items_user_favorite_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX library_items_user_favorite_idx ON public.library_items USING btree (user_id) WHERE is_favorite;


--
-- TOC entry 4765 (class 1259 OID 16574)
-- Name: library_items_user_status_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX library_items_user_status_idx ON public.library_items USING btree (user_id, status);


--
-- TOC entry 4783 (class 1259 OID 16678)
-- Name: listening_history_user_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX listening_history_user_date_idx ON public.listening_history USING btree (user_id, played_at);


--
-- TOC entry 4768 (class 1259 OID 16619)
-- Name: reviews_content_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX reviews_content_idx ON public.reviews USING btree (content_id);


--
-- TOC entry 4741 (class 1259 OID 16475)
-- Name: users_email_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX users_email_unique ON public.users USING btree (lower((email)::text));


--
-- TOC entry 4744 (class 1259 OID 16474)
-- Name: users_username_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX users_username_unique ON public.users USING btree (lower((username)::text));


--
-- TOC entry 4812 (class 2620 OID 16638)
-- Name: collections collections_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER collections_updated_at BEFORE UPDATE ON public.collections FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 4808 (class 2620 OID 16533)
-- Name: contents contents_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER contents_updated_at BEFORE UPDATE ON public.contents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 4809 (class 2620 OID 16576)
-- Name: library_items library_items_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER library_items_updated_at BEFORE UPDATE ON public.library_items FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 4810 (class 2620 OID 16595)
-- Name: ratings ratings_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ratings_updated_at BEFORE UPDATE ON public.ratings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 4811 (class 2620 OID 16620)
-- Name: reviews reviews_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER reviews_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 4807 (class 2620 OID 16494)
-- Name: user_preferences user_preferences_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER user_preferences_updated_at BEFORE UPDATE ON public.user_preferences FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 4806 (class 2620 OID 16476)
-- Name: users users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 4803 (class 2606 OID 16699)
-- Name: activities activities_collection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES public.collections(id) ON DELETE SET NULL;


--
-- TOC entry 4804 (class 2606 OID 16694)
-- Name: activities activities_content_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_content_id_fkey FOREIGN KEY (content_id) REFERENCES public.contents(id) ON DELETE SET NULL;


--
-- TOC entry 4805 (class 2606 OID 16689)
-- Name: activities activities_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4799 (class 2606 OID 16647)
-- Name: collection_items collection_items_collection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collection_items
    ADD CONSTRAINT collection_items_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES public.collections(id) ON DELETE CASCADE;


--
-- TOC entry 4800 (class 2606 OID 16652)
-- Name: collection_items collection_items_content_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collection_items
    ADD CONSTRAINT collection_items_content_id_fkey FOREIGN KEY (content_id) REFERENCES public.contents(id) ON DELETE CASCADE;


--
-- TOC entry 4798 (class 2606 OID 16632)
-- Name: collections collections_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT collections_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4790 (class 2606 OID 16539)
-- Name: content_genres content_genres_content_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_genres
    ADD CONSTRAINT content_genres_content_id_fkey FOREIGN KEY (content_id) REFERENCES public.contents(id) ON DELETE CASCADE;


--
-- TOC entry 4791 (class 2606 OID 16544)
-- Name: content_genres content_genres_genre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_genres
    ADD CONSTRAINT content_genres_genre_id_fkey FOREIGN KEY (genre_id) REFERENCES public.genres(id) ON DELETE CASCADE;


--
-- TOC entry 4792 (class 2606 OID 16569)
-- Name: library_items library_items_content_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.library_items
    ADD CONSTRAINT library_items_content_id_fkey FOREIGN KEY (content_id) REFERENCES public.contents(id) ON DELETE CASCADE;


--
-- TOC entry 4793 (class 2606 OID 16564)
-- Name: library_items library_items_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.library_items
    ADD CONSTRAINT library_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4801 (class 2606 OID 16673)
-- Name: listening_history listening_history_content_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.listening_history
    ADD CONSTRAINT listening_history_content_id_fkey FOREIGN KEY (content_id) REFERENCES public.contents(id) ON DELETE CASCADE;


--
-- TOC entry 4802 (class 2606 OID 16668)
-- Name: listening_history listening_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.listening_history
    ADD CONSTRAINT listening_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4794 (class 2606 OID 16590)
-- Name: ratings ratings_content_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_content_id_fkey FOREIGN KEY (content_id) REFERENCES public.contents(id) ON DELETE CASCADE;


--
-- TOC entry 4795 (class 2606 OID 16585)
-- Name: ratings ratings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4796 (class 2606 OID 16614)
-- Name: reviews reviews_content_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_content_id_fkey FOREIGN KEY (content_id) REFERENCES public.contents(id) ON DELETE CASCADE;


--
-- TOC entry 4797 (class 2606 OID 16609)
-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4787 (class 2606 OID 16489)
-- Name: user_preferences user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4788 (class 2606 OID 16512)
-- Name: user_preferred_genres user_preferred_genres_genre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_preferred_genres
    ADD CONSTRAINT user_preferred_genres_genre_id_fkey FOREIGN KEY (genre_id) REFERENCES public.genres(id) ON DELETE CASCADE;


--
-- TOC entry 4789 (class 2606 OID 16507)
-- Name: user_preferred_genres user_preferred_genres_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_preferred_genres
    ADD CONSTRAINT user_preferred_genres_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


-- Completed on 2026-11-16 08:26:31

--
-- PostgreSQL database dump complete
--

