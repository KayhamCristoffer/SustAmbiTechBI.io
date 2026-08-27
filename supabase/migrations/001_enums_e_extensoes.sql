-- ============================================================
-- SustAmbiTech BI — Migration 001
-- ENUMs e Extensões
-- ============================================================
-- Execute em: Supabase Dashboard → SQL Editor
-- Ou via CLI:  supabase db push
-- ============================================================

-- Extensão para UUID v4 (gen_random_uuid)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────────
-- ENUM: Nível de Acesso do Usuário
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE nivel_usuario AS ENUM ('comum', 'admin', 'operador');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─────────────────────────────────────────────────────────────
-- ENUM: Tipo de Energia / Posto
-- comum   = tomada AC padrão (combustível / carregador simples)
-- hibrido = híbrido plug-in (AC + DC limitado)
-- eletrico = 100% elétrico (AC L2 + DC Fast Charge / Ultra)
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE tipo_energia AS ENUM ('comum', 'hibrido', 'eletrico');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─────────────────────────────────────────────────────────────
-- ENUM: Status da Tomada
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE status_tomada AS ENUM ('disponivel', 'ocupado', 'manutencao', 'inativo');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─────────────────────────────────────────────────────────────
-- ENUM: Operação de Auditoria
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE operacao_auditoria AS ENUM ('INSERT', 'UPDATE', 'DELETE');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
