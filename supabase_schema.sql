-- =========================================================================
-- SCRIPT DE BASE DE DATOS (NUEVO MODELO DE CAPITAL VIVO)
-- Copia y pega esto en el "SQL Editor" de Supabase
-- =========================================================================

DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS installments CASCADE;
DROP TABLE IF EXISTS loans CASCADE;
DROP TABLE IF EXISTS clients CASCADE;

CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    alias TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE loans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    original_principal NUMERIC(12, 2) NOT NULL,
    interest_rate NUMERIC(5, 2) NOT NULL, 
    payment_frequency TEXT NOT NULL DEFAULT 'Mensual',
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id UUID REFERENCES loans(id) ON DELETE CASCADE,
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    principal_paid NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    interest_paid NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Políticas RLS genéricas para habilitar operaciones
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- NOTA: Reemplaza 'PEGA_AQUI_EL_UID' con el ID real del usuario desde Supabase -> Authentication -> Users.
CREATE POLICY "Allow authenticated full access to clients" ON clients FOR ALL USING (auth.uid() = 'PEGA_AQUI_EL_UID');
CREATE POLICY "Allow authenticated full access to loans" ON loans FOR ALL USING (auth.uid() = 'PEGA_AQUI_EL_UID');
CREATE POLICY "Allow authenticated full access to payments" ON payments FOR ALL USING (auth.uid() = 'PEGA_AQUI_EL_UID');
