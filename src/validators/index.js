// Validadores del body, sin librerías: cada uno recibe el body y devuelve un array de errores (vacío = válido).

// Formato de username (igual que el CHECK de la tabla users).
const USERNAME_REGEX = /^[A-Za-z0-9_.]{3,30}$/;

// Formato de email (igual que el CHECK de la tabla users).
const EMAIL_REGEX = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

// Valores del enum library_status.
const LIBRARY_STATUS = ['quiero_escuchar', 'escuchando', 'escuchado', 'favorito'];

// true si es un string cuyo largo (sin espacios en los bordes) está entre min y max.
const largoEntre = (v, min, max) => typeof v === 'string' && v.trim().length >= min && v.trim().length <= max;

// true si es un id válido: entero positivo, como número o como texto.
const esId = (v) => /^[1-9]\d{0,17}$/.test(String(v));

// Mensaje de error de un password (o undefined si es válido): de 8 a 72 caracteres.
const errorPassword = (v) =>
  typeof v === 'string' && v.length >= 8 && v.length <= 72
    ? undefined
    : 'La contraseña debe tener entre 8 y 72 caracteres';

// Mensaje de error de un email (o undefined si es válido); se evalúa con trim.
const errorEmail = (v) =>
  typeof v === 'string' && v.trim().length <= 255 && EMAIL_REGEX.test(v.trim()) ? undefined : 'El email no es válido';

// Arma el objeto de errores por campo sacando los campos sin error; {} = válido.
const porCampo = (campos) => Object.fromEntries(Object.entries(campos).filter(([, msg]) => msg));

// Registro: username de 3 a 30 caracteres [A-Za-z0-9_.], email válido y password de 8 a 72. confirmPassword es opcional (si viene, tiene que coincidir). Devuelve { campo: mensaje }.
function register({ username, email, password, confirmPassword }) {
  return porCampo({
    username:
      typeof username === 'string' && USERNAME_REGEX.test(username)
        ? undefined
        : 'El usuario debe tener entre 3 y 30 caracteres (letras, números, "_" o ".")',
    email: errorEmail(email),
    password: errorPassword(password),
    confirmPassword:
      confirmPassword === undefined || confirmPassword === password ? undefined : 'Las contraseñas no coinciden',
  });
}

// Login: username o email (uno de los dos) y password.
function login({ username, email, password }) {
  const errores = [];
  if (!largoEntre(username, 1, 255) && !largoEntre(email, 1, 255)) {
    errores.push('username o email: hay que enviar uno de los dos');
  }
  if (typeof password !== 'string' || password.length === 0) {
    errores.push('password: es obligatoria');
  }
  return errores;
}

// Edición de perfil: displayName (1 a 60), bio (hasta 300) y/o avatarUrl; al menos uno.
function updateProfile({ displayName, bio, avatarUrl }) {
  const errores = [];
  if (displayName === undefined && bio === undefined && avatarUrl === undefined) {
    errores.push('Enviar al menos uno de: displayName, bio, avatarUrl');
  }
  if (displayName !== undefined && !largoEntre(displayName, 1, 60)) {
    errores.push('displayName: entre 1 y 60 caracteres');
  }
  if (bio !== undefined && !(typeof bio === 'string' && bio.length <= 300)) {
    errores.push('bio: hasta 300 caracteres');
  }
  if (avatarUrl !== undefined && !(typeof avatarUrl === 'string' && /^https?:\/\/\S+$/.test(avatarUrl))) {
    errores.push('avatarUrl: debe ser una URL http(s)');
  }
  return errores;
}

// Preferencias: theme ('dark' o 'light'), language (2 a 5 caracteres) y/o genres (lista de hasta 20 nombres de 1 a 60 caracteres); al menos uno.
function updatePreferences({ theme, language, genres }) {
  const errores = [];
  if (theme === undefined && language === undefined && genres === undefined) {
    errores.push('Enviar al menos uno de: theme, language, genres');
  }
  if (theme !== undefined && !['dark', 'light'].includes(theme)) {
    errores.push('theme: debe ser dark o light');
  }
  if (language !== undefined && !(typeof language === 'string' && /^[a-zA-Z-]{2,5}$/.test(language))) {
    errores.push('language: código de 2 a 5 caracteres (ej. es, en)');
  }
  if (genres !== undefined && !(Array.isArray(genres) && genres.length <= 20 && genres.every((g) => largoEntre(g, 1, 60)))) {
    errores.push('genres: lista de hasta 20 nombres de 1 a 60 caracteres');
  }
  return errores;
}

// Agregar a la biblioteca: contentId obligatorio y status opcional (enum library_status).
function addLibraryItem({ contentId, status }) {
  const errores = [];
  if (!esId(contentId)) errores.push('contentId: id inválido');
  if (status !== undefined && !LIBRARY_STATUS.includes(status)) {
    errores.push(`status: debe ser uno de ${LIBRARY_STATUS.join(', ')}`);
  }
  return errores;
}

// Editar un ítem de la biblioteca: status (enum library_status) y/o isFavorite (boolean).
function updateLibraryItem({ status, isFavorite }) {
  const errores = [];
  if (status === undefined && isFavorite === undefined) {
    errores.push('Enviar al menos uno de: status, isFavorite');
  }
  if (status !== undefined && !LIBRARY_STATUS.includes(status)) {
    errores.push(`status: debe ser uno de ${LIBRARY_STATUS.join(', ')}`);
  }
  if (isFavorite !== undefined && typeof isFavorite !== 'boolean') {
    errores.push('isFavorite: debe ser true o false');
  }
  return errores;
}

// Puntuación: score entero de 1 a 5.
function rating({ score }) {
  return Number.isInteger(score) && score >= 1 && score <= 5 ? [] : ['score: entero entre 1 y 5'];
}

// Reseña: body de 1 a 5000 caracteres.
function review({ body }) {
  return largoEntre(body, 1, 5000) ? [] : ['body: entre 1 y 5000 caracteres'];
}

// Playlist (crear y editar): name de 1 a 80 caracteres y description opcional hasta 300.
function collection({ name, description }) {
  const errores = [];
  if (!largoEntre(name, 1, 80)) errores.push('name: entre 1 y 80 caracteres');
  if (description !== undefined && !(typeof description === 'string' && description.length <= 300)) {
    errores.push('description: hasta 300 caracteres');
  }
  return errores;
}

// Agregar a una playlist: contentId obligatorio.
function collectionItem({ contentId }) {
  return esId(contentId) ? [] : ['contentId: id inválido'];
}

// Reproducción: contentId y msPlayed (entero >= 0).
function historyEntry({ contentId, msPlayed }) {
  const errores = [];
  if (!esId(contentId)) errores.push('contentId: id inválido');
  if (!(Number.isInteger(msPlayed) && msPlayed >= 0)) errores.push('msPlayed: entero mayor o igual a 0');
  return errores;
}

module.exports = {
  register,
  login,
  updateProfile,
  updatePreferences,
  addLibraryItem,
  updateLibraryItem,
  rating,
  review,
  collection,
  collectionItem,
  historyEntry,
};
