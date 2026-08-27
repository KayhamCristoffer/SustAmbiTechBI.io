-- ============================================================
-- SustAmbiTech BI — Migration 004
-- Funções PL/pgSQL + Triggers Automáticos
-- ============================================================
-- Dependências: 003_tabelas_auditoria_backup.sql
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- FUNÇÃO 1: fn_atualiza_timestamp
-- Atualiza automaticamente o campo `atualizado_em` em qualquer UPDATE
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_atualiza_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_atualiza_timestamp IS
  'Trigger function: atualiza automaticamente atualizado_em em qualquer UPDATE';

-- ─────────────────────────────────────────────────────────────
-- FUNÇÃO 2: fn_auditoria_crud
-- Registra INSERT/UPDATE/DELETE em auditoria_log como JSON snapshot
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_auditoria_crud()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER                          -- Executa como owner (acesso garantido ao audit log)
AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO auditoria_log (nome_tabela, operacao, registro_id, dados_antigos)
        VALUES (TG_TABLE_NAME, 'DELETE'::operacao_auditoria, OLD.id, row_to_json(OLD)::jsonb);
        RETURN OLD;

    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO auditoria_log (nome_tabela, operacao, registro_id, dados_antigos, dados_novos)
        VALUES (TG_TABLE_NAME, 'UPDATE'::operacao_auditoria, NEW.id,
                row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
        RETURN NEW;

    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO auditoria_log (nome_tabela, operacao, registro_id, dados_novos)
        VALUES (TG_TABLE_NAME, 'INSERT'::operacao_auditoria, NEW.id, row_to_json(NEW)::jsonb);
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION fn_auditoria_crud IS
  'Trigger function: registra todas as operações CRUD em auditoria_log com snapshot JSON completo';

-- ─────────────────────────────────────────────────────────────
-- FUNÇÃO 3: fn_espelhar_backup
-- Espelhamento dinâmico para tabelas *_bkp
-- Insere bkp_operacao, bkp_em além dos dados originais
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_espelhar_backup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    tabela_bkp TEXT;
    dados_json JSONB;
BEGIN
    tabela_bkp := TG_TABLE_NAME || '_bkp';

    IF (TG_OP = 'INSERT') THEN
        dados_json := row_to_json(NEW)::jsonb;
        EXECUTE format(
            'INSERT INTO %I (bkp_operacao, bkp_em, id, %s) VALUES ($1, NOW(), $2, %s)',
            tabela_bkp,
            (SELECT string_agg(key, ', ') FROM jsonb_object_keys(dados_json) AS t(key) WHERE key != 'id'),
            (SELECT string_agg('($3->>' || quote_literal(key) || ')::text', ', ') FROM jsonb_object_keys(dados_json) AS t(key) WHERE key != 'id')
        ) USING 'INSERT', (dados_json->>'id')::UUID, dados_json;
        RETURN NEW;

    ELSIF (TG_OP = 'UPDATE') THEN
        -- Remove versão anterior do backup e insere nova
        EXECUTE format('DELETE FROM %I WHERE id = $1', tabela_bkp) USING OLD.id;
        dados_json := row_to_json(NEW)::jsonb;
        EXECUTE format(
            'INSERT INTO %I (bkp_operacao, bkp_em, id, %s) VALUES ($1, NOW(), $2, %s)',
            tabela_bkp,
            (SELECT string_agg(key, ', ') FROM jsonb_object_keys(dados_json) AS t(key) WHERE key != 'id'),
            (SELECT string_agg('($3->>' || quote_literal(key) || ')::text', ', ') FROM jsonb_object_keys(dados_json) AS t(key) WHERE key != 'id')
        ) USING 'UPDATE', (dados_json->>'id')::UUID, dados_json;
        RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
        -- Mantém o registro como tombstone (bkp_operacao = 'DELETE')
        EXECUTE format('UPDATE %I SET bkp_operacao = $1, bkp_em = NOW() WHERE id = $2', tabela_bkp)
        USING 'DELETE', OLD.id;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION fn_espelhar_backup IS
  'Trigger function: espelha dinamicamente INSERT/UPDATE/DELETE para tabela *_bkp correspondente';

-- ─────────────────────────────────────────────────────────────
-- FUNÇÃO 4: fn_clima_upsert
-- Função auxiliar para salvar dados de clima (upsert inteligente)
-- Chamada pela API do site ao buscar dados do Open-Meteo
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_clima_upsert(
    p_cidade              TEXT,
    p_estado              TEXT,
    p_latitude            NUMERIC,
    p_longitude           NUMERIC,
    p_temperatura_atual   NUMERIC,
    p_temperatura_max     NUMERIC,
    p_temperatura_min     NUMERIC,
    p_sensacao_termica    NUMERIC,
    p_umidade_percent     INT,
    p_precipitacao_mm     NUMERIC,
    p_velocidade_vento    NUMERIC,
    p_codigo_clima        INT,
    p_condicao_climatica  TEXT,
    p_previsao_futura     JSONB DEFAULT '[]'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_hora_atual  TIMESTAMPTZ;
    v_id_retorno  UUID;
BEGIN
    -- Arredonda para hora cheia para evitar duplicatas em chamadas frequentes
    v_hora_atual := DATE_TRUNC('hour', NOW());

    INSERT INTO clima_historico (
        cidade, estado, latitude, longitude, data_hora,
        temperatura_atual, temperatura_max, temperatura_min, sensacao_termica,
        umidade_percent, precipitacao_mm, velocidade_vento_kmh,
        codigo_clima, condicao_climatica, previsao_futura,
        fonte_api
    ) VALUES (
        p_cidade, p_estado, p_latitude, p_longitude, v_hora_atual,
        p_temperatura_atual, p_temperatura_max, p_temperatura_min, p_sensacao_termica,
        p_umidade_percent, p_precipitacao_mm, p_velocidade_vento,
        p_codigo_clima, p_condicao_climatica, p_previsao_futura,
        'open-meteo'
    )
    ON CONFLICT (cidade, data_hora)
    DO UPDATE SET
        temperatura_atual    = EXCLUDED.temperatura_atual,
        temperatura_max      = EXCLUDED.temperatura_max,
        temperatura_min      = EXCLUDED.temperatura_min,
        sensacao_termica     = EXCLUDED.sensacao_termica,
        umidade_percent      = EXCLUDED.umidade_percent,
        precipitacao_mm      = EXCLUDED.precipitacao_mm,
        velocidade_vento_kmh = EXCLUDED.velocidade_vento_kmh,
        codigo_clima         = EXCLUDED.codigo_clima,
        condicao_climatica   = EXCLUDED.condicao_climatica,
        previsao_futura      = EXCLUDED.previsao_futura,
        atualizado_em        = NOW()
    RETURNING id INTO v_id_retorno;

    RETURN v_id_retorno;
END;
$$;

COMMENT ON FUNCTION fn_clima_upsert IS
  'Salva dados climáticos do Open-Meteo no banco com upsert por hora (evita duplicatas)';

-- ─────────────────────────────────────────────────────────────
-- APLICAÇÃO DOS TRIGGERS (em lote via DO block)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    tabela TEXT;
BEGIN
    FOR tabela IN
        SELECT unnest(ARRAY['usuarios','enderecos','postos','tomadas','veiculos','avaliacoes','feedbacks','clima_historico'])
    LOOP
        -- ── Trigger 1: Timestamp automático ──────────────────
        EXECUTE format('
            DROP TRIGGER IF EXISTS tg_%I_timestamp ON %I;
            CREATE TRIGGER tg_%I_timestamp
            BEFORE UPDATE ON %I
            FOR EACH ROW EXECUTE FUNCTION fn_atualiza_timestamp()
        ', tabela, tabela, tabela, tabela);

        -- ── Trigger 2: Auditoria CRUD ─────────────────────────
        EXECUTE format('
            DROP TRIGGER IF EXISTS tg_%I_auditoria ON %I;
            CREATE TRIGGER tg_%I_auditoria
            AFTER INSERT OR UPDATE OR DELETE ON %I
            FOR EACH ROW EXECUTE FUNCTION fn_auditoria_crud()
        ', tabela, tabela, tabela, tabela);

        RAISE NOTICE 'Triggers criados para tabela: %', tabela;
    END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────
-- TRIGGER DE BACKUP (separado — só para tabelas com _bkp)
-- ─────────────────────────────────────────────────────────────
-- Nota: o espelhamento dinâmico via EXECUTE pode ser lento em
-- grandes volumes. Para performance máxima, substitua por
-- triggers individuais por tabela.
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    tabela TEXT;
BEGIN
    FOR tabela IN
        SELECT unnest(ARRAY['usuarios','enderecos','postos','tomadas','veiculos','avaliacoes','feedbacks','clima_historico'])
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS tg_%I_backup ON %I;
        ', tabela, tabela);
    END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────
-- Trigger de backup simplificado (INSERT apenas — mais robusto)
-- Para DELETE/UPDATE o auditoria_log já preserva os dados.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_backup_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    tabela_bkp TEXT;
BEGIN
    tabela_bkp := TG_TABLE_NAME || '_bkp';

    -- Insere cópia direta usando INSERT ... SELECT
    EXECUTE format(
        'INSERT INTO %I SELECT gen_random_uuid(), NOW(), $1, (row_to_json($2)).*',
        tabela_bkp
    ) USING TG_OP, NEW;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Não bloqueia a operação principal se o backup falhar
    RAISE WARNING 'Backup trigger falhou para tabela %: %', TG_TABLE_NAME, SQLERRM;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_backup_insert IS
  'Cópia de segurança simplificada: espelha cada INSERT/UPDATE para tabela *_bkp sem bloquear operação principal';
