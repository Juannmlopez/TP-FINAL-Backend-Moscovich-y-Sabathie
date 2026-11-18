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

// Registro: username de 3 a 30 caracteres [A-Za-z0-9_.], email válido, password de 8 a 72 caracteres y confirmPassword igual.
function register({ username, email, password, confirmPassword }) {
  const errores = [];
  if (typeof username !== 'string' || !USERNAME_REGEX.test(username)) {
    errores.push('username: entre 3 y 30 caracteres (letras, números, "_" o ".")');
  }
  if (typeof email !== 'string' || email.length > 255 || !EMAIL_REGEX.test(email.trim())) {
    errores.push('email: no es un email válido');
  }
  if (typeof password !== 'string' || password.length < 8 || password.length > 72) {
    errores.push('password: entre 8 y 72 caracteres');
  }
  if (confirmPassword !== password) {
    errores.push('confirmPassword: no coincide con password');
  }
  return errores;
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
  addLibraryItem,
  updateLibraryItem,
  rating,
  review,
  collection,
  collectionItem,
  historyEntry,
};
