-- =====================================================================
-- 02_seed_demo.sql — Carga la cuenta demo.
-- La contraseña se lee de la setting de sesión 'demo.password', que
-- scripts/db-setup.js define con DEMO_PASSWORD antes de ejecutar esto.
-- Se ejecuta con: npm run db:seed
--
-- PENDIENTE: falta escribir los datos (14 contenidos en biblioteca,
-- 6 favoritos, 3 colecciones, 8 puntuaciones y 4 reseñas).
-- Mientras tanto corta con error para que el seed no "pase" vacío.
-- =====================================================================

DO $$
BEGIN
  RAISE EXCEPTION '02_seed_demo.sql todavía no tiene datos';
END;
$$;
