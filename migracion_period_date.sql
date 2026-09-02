-- =========================================================================
-- MIGRACION: Agregar columna period_date a la tabla payments
-- =========================================================================
-- INSTRUCCIONES:
-- 1. Ve a tu panel de Supabase
-- 2. Abre el "SQL Editor"
-- 3. Copia y pega este script y ejecútalo
-- 4. Luego instala el nuevo APK

-- Agregar la columna period_date (opcional, acepta NULL para pagos anteriores)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS period_date DATE;

-- Verificar que la columna se creo correctamente
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'payments' AND column_name = 'period_date';
