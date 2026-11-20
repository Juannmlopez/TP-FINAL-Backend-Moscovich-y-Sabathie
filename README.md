TP Final Backend — Moscovich y Sabathie

Integrantes y responsabilidades: Iván Moscovich Levi y Juan Manuel Sabathie Lopez. Ambos hicimos parte del proyecto, a veces en una misma computadora y a veces en dos computadoras diferentes.

Temática: app basada en Spotify.

Arquitectura:Node.js + Express para la API, PostgreSQL para la base de datos y la API de Deezer para la música.

API externa: [Deezer API](https://developers.deezer.com/api) (búsqueda, destacados, detalle de álbumes y canciones). No requiere clave.

Cómo correr el backend


1 Crear el archivo `.env`

Copiar el archivo de ejemplo (CMD):

```cmd
copy .env.example .env
```

Abrir `.env` y completar los valores marcados con `CAMBIAR`:

| Variable | Qué poner |
| --- | --- |
| `DATABASE_URL` | `postgres://USUARIO:CONTRASEÑA@localhost:5432/NOMBRE_BASE`. Ejemplo: `postgres://postgres:root@localhost:5432/postgres` |
| `DATABASE_SSL` | `false` en local. `true` solo para bases en la nube que exigen SSL. |
| `DEMO_PASSWORD` | La contraseña que va a tener la cuenta demo (por ejemplo `root`). |
| `PORT` | Puerto del servidor. Por defecto `3000`. |
| `JWT_SECRET` | Un texto largo y aleatorio, para firmar los tokens de sesión. |
| `JWT_EXPIRES_IN` | Duración de la sesión. Por defecto `7d`. |
| `FRONTEND_URL` | URL del frontend, para CORS. Por defecto `http://localhost:5173`. |

> El `.env` no se sube a git. Cada uno tiene que crear el suyo.

2 Crear la base de datos

Con PostgreSQL corriendo, hay dos formas. Usar una sola.

Opción A — desde la terminal (recomendada):

```cmd
npm run db:seed
```

Crea todas las tablas (`db/01_schema.sql`) y carga la cuenta demo con datos de ejemplo (`db/02_seed_demo.sql`). Tiene que mostrar:

```
Esquema creado.
Cuenta demo cargada.
```

Si solo se quieren las tablas vacías, sin la cuenta demo: `npm run db:setup`.

Opción B — desde pgAdmin: abrir el Query Tool sobre la base, abrir el archivo `db/BDtpFinal.sql` y ejecutarlo. Hace lo mismo que la opción A, pero la contraseña de la cuenta demo queda fija.

 Los dos comandos borran y vuelven a crear todas las tablas. Sirven también para resetear la base, pero se pierden los datos que haya.

3 Levantar el servidor

```cmd
npm start
```

O, para desarrollo (se reinicia solo al guardar cambios):

```cmd
npm run dev
```

Tiene que aparecer:

```
Servidor escuchando en http://localhost:3000
```

