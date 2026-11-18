// Controlador de estadísticas, actividad e historial: llama a stats.service con req.user.id y responde.
const service = require('../services/stats.service');
const { parseId } = require('../utils');

// GET /api/stats — estadísticas del año (?year=, por defecto el actual).
async function getStats(req, res) {
  res.json(await service.getStats(req.user.id, req.query.year));
}

// GET /api/activity — últimas 20 acciones del usuario.
async function getActivity(req, res) {
  res.json(await service.getActivity(req.user.id));
}

// POST /api/history — registra una reproducción y responde 201.
async function addHistoryEntry(req, res) {
  const entry = await service.addHistoryEntry(
    req.user.id,
    parseId(req.body.contentId, 'contentId'),
    req.body.msPlayed
  );
  res.status(201).json({ entry });
}

module.exports = { getStats, getActivity, addHistoryEntry };
