-- Migración para bases ya creadas: agrega la columna de configuración (reproducción, notificaciones, privacidad).
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS settings JSONB NOT NULL DEFAULT '{}'::jsonb;
