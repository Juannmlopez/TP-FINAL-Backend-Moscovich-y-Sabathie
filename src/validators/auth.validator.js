// Reglas del body para auth.
// Cada validador recibe el body y devuelve un array de errores (vacío = válido).

const USERNAME_REGEX = /^[A-Za-z0-9_.]{3,30}$/;
const EMAIL_REGEX = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function validarRegistro(body) {
  const errores = [];
  const { username, email, password, displayName } = body;

  if (typeof username !== 'string' || !USERNAME_REGEX.test(username)) {
    errores.push('username: entre 3 y 30 caracteres (letras, números, "_" o ".")');
  }
  if (typeof email !== 'string' || email.length > 255 || !EMAIL_REGEX.test(email.trim())) {
    errores.push('email: no es un email válido');
  }
  if (typeof password !== 'string' || password.length < 8 || password.length > 72) {
    errores.push('password: entre 8 y 72 caracteres');
  }
  if (
    displayName !== undefined &&
    displayName !== null &&
    (typeof displayName !== 'string' || displayName.trim().length === 0 || displayName.length > 60)
  ) {
    errores.push('displayName: entre 1 y 60 caracteres');
  }

  return errores;
}


// Login con username o email (uno de los dos) + password
function validarLogin(body) {
  const errores = [];
  const { username, email, password } = body;

  const tieneUsername = typeof username === 'string' && username.trim().length > 0;
  const tieneEmail = typeof email === 'string' && email.trim().length > 0;
  if (!tieneUsername && !tieneEmail) {
    errores.push('username o email: hay que enviar uno de los dos');
  }
  if (typeof password !== 'string' || password.length === 0) {
    errores.push('password: es obligatoria');
  }

  return errores;
}

module.exports = { validarRegistro, validarLogin };
