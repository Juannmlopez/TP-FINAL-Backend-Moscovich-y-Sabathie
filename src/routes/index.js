// Junta todos los routers bajo /api
const { Router } = require('express');
const pool = require('../db');

const router = Router();

// Chequeo rápido de que el servidor y la base responden
router.get('/health', async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT now() AS ahora');
    res.json({ ok: true, db: rows[0].ahora });
  } catch (err) {
    next(err);
  }
});

router.use('/auth', require('./auth.routes'));
router.use('/users', require('./users.routes'));
router.use('/home', require('./home.routes'));
router.use('/library', require('./library.routes'));
router.use('/collections', require('./collections.routes'));
router.use('/ratings', require('./ratings.routes'));
router.use('/reviews', require('./reviews.routes'));
router.use('/history', require('./history.routes'));
router.use('/stats', require('./stats.routes'));
router.use('/activity', require('./activity.routes'));

module.exports = router;
