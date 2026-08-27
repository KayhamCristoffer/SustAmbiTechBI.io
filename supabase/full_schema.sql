-- ============================================================
-- SustAmbiTech BI — Schema Completo (All-in-One)
-- Execute este arquivo no SQL Editor do Supabase Dashboard
-- URL: https://supabase.com/dashboard/project/qqlggpgsidfhqjgzbwhp/sql
-- ============================================================
-- Ordem: ENUMs → Tabelas → Auditoria/Backup → Funções/Triggers → Views → Índices
-- ============================================================

-- ══════════════════════════════════════════════════════════════
-- 1. EXTENSÕES E ENUMs
-- ══════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$ BEGIN CREATE TYPE nivel_usuario AS ENUM ('comum', 'admin', 'operador'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE tipo_energia AS ENUM ('comum', 'hibrido', 'eletrico'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE status_tomada AS ENUM ('disponivel', 'ocupado', 'manutencao', 'inativo'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE operacao_auditoria AS ENUM ('INSERT', 'UPDATE', 'DELETE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ══════════════════════════════════════════════════════════════
-- 2. TABELAS PRINCIPAIS
-- ══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS usuarios (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid      VARCHAR(128) UNIQUE,
    email             VARCHAR(255) UNIQUE NOT NULL,
    nome              VARCHAR(100) NOT NULL,
    sobrenome         VARCHAR(100),
    nivel             nivel_usuario DEFAULT 'comum',
    newsletter_opt_in BOOLEAN      DEFAULT false,
    ativo             BOOLEAN      DEFAULT true,
    criado_em         TIMESTAMPTZ  DEFAULT NOW(),
    atualizado_em     TIMESTAMPTZ  DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS enderecos (
    id            UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    cep           VARCHAR(10),
    estado        VARCHAR(2)     NOT NULL,
    cidade        VARCHAR(100)   NOT NULL,
    bairro        VARCHAR(100),
    rua           VARCHAR(200),
    numero        VARCHAR(20),
    complemento   VARCHAR(100),
    latitude      NUMERIC(10, 8) NOT NULL,
    longitude     NUMERIC(11, 8) NOT NULL,
    criado_em     TIMESTAMPTZ    DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ    DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS postos (
    id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid          VARCHAR(128) UNIQUE,
    nome                  VARCHAR(200) NOT NULL,
    tipo                  tipo_energia NOT NULL DEFAULT 'eletrico',
    endereco_id           UUID         NOT NULL REFERENCES enderecos(id) ON DELETE RESTRICT,
    usuario_resp_id       UUID         REFERENCES usuarios(id) ON DELETE SET NULL,
    ativo                 BOOLEAN      DEFAULT true,
    horario_funcionamento VARCHAR(100),
    acesso                VARCHAR(30)  DEFAULT 'público',
    requer_app            BOOLEAN      DEFAULT false,
    app_nome              VARCHAR(100),
    observacoes           TEXT,
    criado_em             TIMESTAMPTZ  DEFAULT NOW(),
    atualizado_em         TIMESTAMPTZ  DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tomadas (
    id                         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    posto_id                   UUID           NOT NULL REFERENCES postos(id) ON DELETE CASCADE,
    tipo_conector              VARCHAR(50)    NOT NULL,
    potencia_kw                NUMERIC(6, 2),
    custo_por_minuto           NUMERIC(10, 4) NOT NULL DEFAULT 0.00,
    custo_por_kwh              NUMERIC(10, 4) DEFAULT 0.00,
    tempo_recarga_estimado_min INT,
    quantidade                 INT            DEFAULT 1,
    status                     status_tomada  DEFAULT 'disponivel',
    criado_em                  TIMESTAMPTZ    DEFAULT NOW(),
    atualizado_em              TIMESTAMPTZ    DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS veiculos (
    id                     UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    marca                  VARCHAR(100)   NOT NULL,
    modelo                 VARCHAR(100)   NOT NULL,
    ano_lancamento         INT,
    tipo_fonte             tipo_energia   NOT NULL DEFAULT 'eletrico',
    preco_estimado         NUMERIC(15, 2),
    capacidade_bateria_kwh NUMERIC(6, 2),
    autonomia_km           INT,
    tempo_recarga_ac_min   INT,
    tempo_recarga_dc_min   INT,
    conectores_compativeis VARCHAR(200),
    fonte                  TEXT,
    ativo                  BOOLEAN        DEFAULT true,
    criado_em              TIMESTAMPTZ    DEFAULT NOW(),
    atualizado_em          TIMESTAMPTZ    DEFAULT NOW(),
    UNIQUE (marca, modelo, ano_lancamento)
);

CREATE TABLE IF NOT EXISTS avaliacoes (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_id   VARCHAR(128) UNIQUE,
    posto_id      UUID        NOT NULL REFERENCES postos(id) ON DELETE CASCADE,
    usuario_id    UUID        NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    nota          INT         NOT NULL CHECK (nota >= 1 AND nota <= 5),
    comentario    TEXT,
    criado_em     TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (posto_id, usuario_id)
);

CREATE TABLE IF NOT EXISTS feedbacks (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_id   VARCHAR(128) UNIQUE,
    usuario_id    UUID        REFERENCES usuarios(id) ON DELETE SET NULL,
    nota          INT         CHECK (nota >= 1 AND nota <= 5),
    observacoes   TEXT,
    categoria     VARCHAR(50) DEFAULT 'geral',
    criado_em     TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS clima_historico (
    id                   UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    cidade               VARCHAR(100)   NOT NULL,
    estado               VARCHAR(2)     DEFAULT 'SP',
    latitude             NUMERIC(10, 8),
    longitude            NUMERIC(11, 8),
    data_hora            TIMESTAMPTZ    NOT NULL,
    temperatura_atual    NUMERIC(5, 2),
    temperatura_max      NUMERIC(5, 2),
    temperatura_min      NUMERIC(5, 2),
    sensacao_termica     NUMERIC(5, 2),
    umidade_percent      INT,
    precipitacao_mm      NUMERIC(6, 2)  DEFAULT 0,
    velocidade_vento_kmh NUMERIC(6, 2),
    codigo_clima         INT,
    condicao_climatica   VARCHAR(100),
    previsao_futura      JSONB          DEFAULT '[]'::jsonb,
    fonte_api            VARCHAR(50)    DEFAULT 'open-meteo',
    criado_em            TIMESTAMPTZ    DEFAULT NOW(),
    atualizado_em        TIMESTAMPTZ    DEFAULT NOW(),
    UNIQUE (cidade, data_hora)
);

CREATE TABLE IF NOT EXISTS log_importacoes (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo                 VARCHAR(50) NOT NULL,
    arquivo_nome         VARCHAR(255),
    registros_importados INT         DEFAULT 0,
    registros_erros      INT         DEFAULT 0,
    detalhes_erros       JSONB       DEFAULT '[]'::jsonb,
    usuario_id           UUID        REFERENCES usuarios(id) ON DELETE SET NULL,
    importado_em         TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════
-- 3. TABELA DE AUDITORIA + BACKUPS
-- ══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS auditoria_log (
    id            UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    nome_tabela   VARCHAR(60)         NOT NULL,
    operacao      operacao_auditoria  NOT NULL,
    registro_id   UUID                NOT NULL,
    dados_antigos JSONB,
    dados_novos   JSONB,
    realizado_em  TIMESTAMPTZ         DEFAULT NOW(),
    usuario_db    VARCHAR(100)        DEFAULT current_user,
    ip_origem     INET,
    session_info  JSONB               DEFAULT '{}'::jsonb
);

-- Tabelas de Backup (sem constraints — para restauração sem bloqueio)
CREATE TABLE IF NOT EXISTS usuarios_bkp       (bkp_id UUID DEFAULT gen_random_uuid(), bkp_em TIMESTAMPTZ DEFAULT NOW(), bkp_operacao VARCHAR(10), id UUID, firebase_uid VARCHAR(128), email VARCHAR(255), nome VARCHAR(100), sobrenome VARCHAR(100), nivel TEXT, newsletter_opt_in BOOLEAN, ativo BOOLEAN, criado_em TIMESTAMPTZ, atualizado_em TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS enderecos_bkp      (bkp_id UUID DEFAULT gen_random_uuid(), bkp_em TIMESTAMPTZ DEFAULT NOW(), bkp_operacao VARCHAR(10), id UUID, cep VARCHAR(10), estado VARCHAR(2), cidade VARCHAR(100), bairro VARCHAR(100), rua VARCHAR(200), numero VARCHAR(20), complemento VARCHAR(100), latitude NUMERIC(10,8), longitude NUMERIC(11,8), criado_em TIMESTAMPTZ, atualizado_em TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS postos_bkp         (bkp_id UUID DEFAULT gen_random_uuid(), bkp_em TIMESTAMPTZ DEFAULT NOW(), bkp_operacao VARCHAR(10), id UUID, firebase_uid VARCHAR(128), nome VARCHAR(200), tipo TEXT, endereco_id UUID, usuario_resp_id UUID, ativo BOOLEAN, horario_funcionamento VARCHAR(100), acesso VARCHAR(30), requer_app BOOLEAN, app_nome VARCHAR(100), observacoes TEXT, criado_em TIMESTAMPTZ, atualizado_em TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS tomadas_bkp        (bkp_id UUID DEFAULT gen_random_uuid(), bkp_em TIMESTAMPTZ DEFAULT NOW(), bkp_operacao VARCHAR(10), id UUID, posto_id UUID, tipo_conector VARCHAR(50), potencia_kw NUMERIC(6,2), custo_por_minuto NUMERIC(10,4), custo_por_kwh NUMERIC(10,4), tempo_recarga_estimado_min INT, quantidade INT, status TEXT, criado_em TIMESTAMPTZ, atualizado_em TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS veiculos_bkp       (bkp_id UUID DEFAULT gen_random_uuid(), bkp_em TIMESTAMPTZ DEFAULT NOW(), bkp_operacao VARCHAR(10), id UUID, marca VARCHAR(100), modelo VARCHAR(100), ano_lancamento INT, tipo_fonte TEXT, preco_estimado NUMERIC(15,2), capacidade_bateria_kwh NUMERIC(6,2), autonomia_km INT, tempo_recarga_ac_min INT, tempo_recarga_dc_min INT, conectores_compativeis VARCHAR(200), fonte TEXT, ativo BOOLEAN, criado_em TIMESTAMPTZ, atualizado_em TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS avaliacoes_bkp     (bkp_id UUID DEFAULT gen_random_uuid(), bkp_em TIMESTAMPTZ DEFAULT NOW(), bkp_operacao VARCHAR(10), id UUID, firebase_id VARCHAR(128), posto_id UUID, usuario_id UUID, nota INT, comentario TEXT, criado_em TIMESTAMPTZ, atualizado_em TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS feedbacks_bkp      (bkp_id UUID DEFAULT gen_random_uuid(), bkp_em TIMESTAMPTZ DEFAULT NOW(), bkp_operacao VARCHAR(10), id UUID, firebase_id VARCHAR(128), usuario_id UUID, nota INT, observacoes TEXT, categoria VARCHAR(50), criado_em TIMESTAMPTZ, atualizado_em TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS clima_historico_bkp(bkp_id UUID DEFAULT gen_random_uuid(), bkp_em TIMESTAMPTZ DEFAULT NOW(), bkp_operacao VARCHAR(10), id UUID, cidade VARCHAR(100), estado VARCHAR(2), latitude NUMERIC(10,8), longitude NUMERIC(11,8), data_hora TIMESTAMPTZ, temperatura_atual NUMERIC(5,2), temperatura_max NUMERIC(5,2), temperatura_min NUMERIC(5,2), sensacao_termica NUMERIC(5,2), umidade_percent INT, precipitacao_mm NUMERIC(6,2), velocidade_vento_kmh NUMERIC(6,2), codigo_clima INT, condicao_climatica VARCHAR(100), previsao_futura JSONB, fonte_api VARCHAR(50), criado_em TIMESTAMPTZ, atualizado_em TIMESTAMPTZ);

-- ══════════════════════════════════════════════════════════════
-- 4. FUNÇÕES E TRIGGERS
-- ══════════════════════════════════════════════════════════════

-- Função 1: Atualiza timestamp automaticamente em qualquer UPDATE
CREATE OR REPLACE FUNCTION fn_atualiza_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.atualizado_em = NOW(); RETURN NEW; END; $$;

-- Função 2: Registra todas as operações CRUD no auditoria_log
CREATE OR REPLACE FUNCTION fn_auditoria_crud()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF    (TG_OP = 'DELETE') THEN INSERT INTO auditoria_log(nome_tabela,operacao,registro_id,dados_antigos)            VALUES(TG_TABLE_NAME,'DELETE',OLD.id,row_to_json(OLD)::jsonb); RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN INSERT INTO auditoria_log(nome_tabela,operacao,registro_id,dados_antigos,dados_novos) VALUES(TG_TABLE_NAME,'UPDATE',NEW.id,row_to_json(OLD)::jsonb,row_to_json(NEW)::jsonb); RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN INSERT INTO auditoria_log(nome_tabela,operacao,registro_id,dados_novos)              VALUES(TG_TABLE_NAME,'INSERT',NEW.id,row_to_json(NEW)::jsonb); RETURN NEW;
    END IF; RETURN NULL;
END; $$;

-- Função 3: Backup simplificado para tabelas *_bkp
CREATE OR REPLACE FUNCTION fn_backup_insert()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE tabela_bkp TEXT;
BEGIN
    tabela_bkp := TG_TABLE_NAME || '_bkp';
    IF TG_OP = 'DELETE' THEN
        EXECUTE format('UPDATE %I SET bkp_operacao=$1, bkp_em=NOW() WHERE id=$2', tabela_bkp) USING 'DELETE', OLD.id;
        RETURN OLD;
    ELSE
        EXECUTE format('DELETE FROM %I WHERE id=$1', tabela_bkp) USING NEW.id;
        EXECUTE format('INSERT INTO %I SELECT gen_random_uuid(), NOW(), $1, (row_to_json($2::text)::jsonb->>''*''), $2.*', tabela_bkp) USING TG_OP, NEW;
        RETURN NEW;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Backup falhou para %: %', TG_TABLE_NAME, SQLERRM; RETURN COALESCE(NEW, OLD);
END; $$;

-- Função 4: upsert de clima via Open-Meteo
CREATE OR REPLACE FUNCTION fn_clima_upsert(p_cidade TEXT, p_estado TEXT, p_lat NUMERIC, p_lon NUMERIC, p_temp_atual NUMERIC, p_temp_max NUMERIC, p_temp_min NUMERIC, p_sensacao NUMERIC, p_umidade INT, p_precip NUMERIC, p_vento NUMERIC, p_cod_clima INT, p_condicao TEXT, p_previsao JSONB DEFAULT '[]'::jsonb)
RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE v_id UUID;
BEGIN
    INSERT INTO clima_historico(cidade,estado,latitude,longitude,data_hora,temperatura_atual,temperatura_max,temperatura_min,sensacao_termica,umidade_percent,precipitacao_mm,velocidade_vento_kmh,codigo_clima,condicao_climatica,previsao_futura,fonte_api)
    VALUES(p_cidade,p_estado,p_lat,p_lon,DATE_TRUNC('hour',NOW()),p_temp_atual,p_temp_max,p_temp_min,p_sensacao,p_umidade,p_precip,p_vento,p_cod_clima,p_condicao,p_previsao,'open-meteo')
    ON CONFLICT(cidade,data_hora) DO UPDATE SET temperatura_atual=EXCLUDED.temperatura_atual,temperatura_max=EXCLUDED.temperatura_max,temperatura_min=EXCLUDED.temperatura_min,sensacao_termica=EXCLUDED.sensacao_termica,umidade_percent=EXCLUDED.umidade_percent,precipitacao_mm=EXCLUDED.precipitacao_mm,velocidade_vento_kmh=EXCLUDED.velocidade_vento_kmh,codigo_clima=EXCLUDED.codigo_clima,condicao_climatica=EXCLUDED.condicao_climatica,previsao_futura=EXCLUDED.previsao_futura,atualizado_em=NOW()
    RETURNING id INTO v_id; RETURN v_id;
END; $$;

-- Aplicação dos triggers em lote
DO $$
DECLARE tabela TEXT;
BEGIN
    FOR tabela IN SELECT unnest(ARRAY['usuarios','enderecos','postos','tomadas','veiculos','avaliacoes','feedbacks','clima_historico'])
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS tg_%I_timestamp ON %I; CREATE TRIGGER tg_%I_timestamp BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION fn_atualiza_timestamp()', tabela,tabela,tabela,tabela);
        EXECUTE format('DROP TRIGGER IF EXISTS tg_%I_auditoria ON %I; CREATE TRIGGER tg_%I_auditoria AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION fn_auditoria_crud()', tabela,tabela,tabela,tabela);
        EXECUTE format('DROP TRIGGER IF EXISTS tg_%I_backup ON %I; CREATE TRIGGER tg_%I_backup AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION fn_backup_insert()', tabela,tabela,tabela,tabela);
        RAISE NOTICE 'Triggers OK: %', tabela;
    END LOOP;
END $$;

-- ══════════════════════════════════════════════════════════════
-- 5. VIEWS PARA POWER BI
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW vw_postos_completo AS
SELECT p.id AS posto_id, p.firebase_uid, p.nome AS posto_nome, p.tipo::TEXT AS tipo_energia, p.ativo, p.horario_funcionamento, p.acesso, p.requer_app, p.app_nome, p.observacoes, e.cep, e.rua, e.numero, e.bairro, e.cidade, e.estado, e.latitude, e.longitude, COUNT(DISTINCT t.id) AS total_tomadas, MIN(t.custo_por_minuto) AS custo_min_por_minuto, MAX(t.custo_por_minuto) AS custo_max_por_minuto, ROUND(AVG(t.custo_por_minuto),4) AS custo_medio_por_minuto, MIN(t.custo_por_kwh) AS custo_min_por_kwh, MAX(t.potencia_kw) AS potencia_max_kw, STRING_AGG(DISTINCT t.tipo_conector,', ' ORDER BY t.tipo_conector) AS conectores, COUNT(DISTINCT av.id) AS total_avaliacoes, ROUND(AVG(av.nota),2) AS media_nota, u.nome||' '||COALESCE(u.sobrenome,'') AS usuario_resp, p.criado_em, p.atualizado_em
FROM postos p JOIN enderecos e ON p.endereco_id=e.id LEFT JOIN tomadas t ON t.posto_id=p.id LEFT JOIN avaliacoes av ON av.posto_id=p.id LEFT JOIN usuarios u ON u.id=p.usuario_resp_id
GROUP BY p.id,e.id,u.id;

CREATE OR REPLACE VIEW vw_resumo_por_cidade AS
SELECT e.cidade, e.estado, COUNT(DISTINCT p.id) AS total_postos, COUNT(DISTINCT CASE WHEN p.ativo THEN p.id END) AS postos_ativos, COUNT(DISTINCT CASE WHEN p.tipo='eletrico' THEN p.id END) AS postos_eletrico, COUNT(DISTINCT CASE WHEN p.tipo='hibrido' THEN p.id END) AS postos_hibrido, COUNT(DISTINCT CASE WHEN p.tipo='comum' THEN p.id END) AS postos_comum, COUNT(DISTINCT t.id) AS total_tomadas, STRING_AGG(DISTINCT t.tipo_conector,', ') AS tipos_conector, ROUND(AVG(t.custo_por_minuto),4) AS custo_medio_min, MIN(t.custo_por_minuto) AS custo_minimo_min, ROUND(AVG(av.nota),2) AS media_avaliacoes, COUNT(DISTINCT av.id) AS total_avaliacoes, ROUND(AVG(e.latitude)::NUMERIC,6) AS lat_media, ROUND(AVG(e.longitude)::NUMERIC,6) AS lon_media
FROM postos p JOIN enderecos e ON p.endereco_id=e.id LEFT JOIN tomadas t ON t.posto_id=p.id LEFT JOIN avaliacoes av ON av.posto_id=p.id
GROUP BY e.cidade,e.estado ORDER BY total_postos DESC;

CREATE OR REPLACE VIEW vw_custo_por_regiao AS
SELECT p.id AS posto_id, p.nome AS posto_nome, p.tipo::TEXT AS tipo_energia, e.bairro, e.cidade, e.estado, e.latitude, e.longitude, t.tipo_conector, t.potencia_kw, t.custo_por_minuto, t.custo_por_kwh, t.tempo_recarga_estimado_min, ROUND(t.custo_por_minuto*t.tempo_recarga_estimado_min,2) AS custo_recarga_completa, t.status::TEXT AS status_tomada, ROUND(AVG(av.nota),2) AS media_nota, COUNT(av.id) AS total_avaliacoes
FROM postos p JOIN enderecos e ON p.endereco_id=e.id JOIN tomadas t ON t.posto_id=p.id LEFT JOIN avaliacoes av ON av.posto_id=p.id WHERE p.ativo=true
GROUP BY p.id,e.id,t.id ORDER BY t.custo_por_minuto ASC;

CREATE OR REPLACE VIEW vw_conectores_distribuicao AS
SELECT t.tipo_conector, COUNT(DISTINCT t.id) AS total_tomadas, COUNT(DISTINCT p.id) AS postos_com_conector, SUM(t.quantidade) AS unidades_instaladas, ROUND(AVG(t.potencia_kw),2) AS potencia_media_kw, MAX(t.potencia_kw) AS potencia_max_kw, ROUND(AVG(t.custo_por_minuto),4) AS custo_medio_min, STRING_AGG(DISTINCT e.cidade,', ') AS cidades
FROM tomadas t JOIN postos p ON p.id=t.posto_id JOIN enderecos e ON e.id=p.endereco_id WHERE p.ativo=true
GROUP BY t.tipo_conector ORDER BY total_tomadas DESC;

CREATE OR REPLACE VIEW vw_clima_powerbi AS
SELECT id, cidade, estado, data_hora, DATE(data_hora) AS data, EXTRACT(HOUR FROM data_hora) AS hora, EXTRACT(DOW FROM data_hora) AS dia_semana, TO_CHAR(data_hora AT TIME ZONE 'America/Sao_Paulo','YYYY-MM-DD HH24:MI') AS data_hora_local, temperatura_atual, temperatura_max, temperatura_min, sensacao_termica, umidade_percent, precipitacao_mm, velocidade_vento_kmh, codigo_clima, condicao_climatica, (previsao_futura->0->>'data')::DATE AS prev_d1_data, (previsao_futura->0->>'temp_max')::NUMERIC AS prev_d1_tmax, (previsao_futura->0->>'temp_min')::NUMERIC AS prev_d1_tmin, (previsao_futura->0->>'precipitacao')::NUMERIC AS prev_d1_precip, (previsao_futura->1->>'data')::DATE AS prev_d2_data, (previsao_futura->1->>'temp_max')::NUMERIC AS prev_d2_tmax, (previsao_futura->1->>'temp_min')::NUMERIC AS prev_d2_tmin, (previsao_futura->1->>'precipitacao')::NUMERIC AS prev_d2_precip, (previsao_futura->2->>'data')::DATE AS prev_d3_data, (previsao_futura->2->>'temp_max')::NUMERIC AS prev_d3_tmax, (previsao_futura->2->>'temp_min')::NUMERIC AS prev_d3_tmin, (previsao_futura->2->>'precipitacao')::NUMERIC AS prev_d3_precip, fonte_api, criado_em
FROM clima_historico ORDER BY cidade, data_hora DESC;

CREATE OR REPLACE VIEW vw_auditoria_resumo AS
SELECT nome_tabela, operacao::TEXT, DATE(realizado_em) AS data, COUNT(*) AS total_operacoes, MIN(realizado_em) AS primeira_op, MAX(realizado_em) AS ultima_op
FROM auditoria_log GROUP BY nome_tabela,operacao,DATE(realizado_em) ORDER BY data DESC,total_operacoes DESC;

-- ══════════════════════════════════════════════════════════════
-- 6. ÍNDICES
-- ══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_postos_ativo          ON postos(ativo);
CREATE INDEX IF NOT EXISTS idx_postos_tipo           ON postos(tipo);
CREATE INDEX IF NOT EXISTS idx_postos_endereco_id    ON postos(endereco_id);
CREATE INDEX IF NOT EXISTS idx_postos_firebase_uid   ON postos(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_enderecos_cidade      ON enderecos(cidade);
CREATE INDEX IF NOT EXISTS idx_enderecos_latlon      ON enderecos(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_tomadas_posto_id      ON tomadas(posto_id);
CREATE INDEX IF NOT EXISTS idx_tomadas_tipo_conector ON tomadas(tipo_conector);
CREATE INDEX IF NOT EXISTS idx_tomadas_custo         ON tomadas(custo_por_minuto);
CREATE INDEX IF NOT EXISTS idx_tomadas_status        ON tomadas(status);
CREATE INDEX IF NOT EXISTS idx_avaliacoes_posto_id   ON avaliacoes(posto_id);
CREATE INDEX IF NOT EXISTS idx_veiculos_marca_modelo ON veiculos(marca, modelo);
CREATE INDEX IF NOT EXISTS idx_clima_cidade_data     ON clima_historico(cidade, data_hora DESC);
CREATE INDEX IF NOT EXISTS idx_auditoria_tabela      ON auditoria_log(nome_tabela);
CREATE INDEX IF NOT EXISTS idx_auditoria_data        ON auditoria_log(realizado_em DESC);
CREATE INDEX IF NOT EXISTS idx_postos_ativos_cidade  ON postos(endereco_id) WHERE ativo = true;
CREATE INDEX IF NOT EXISTS idx_tomadas_disponiveis   ON tomadas(posto_id, custo_por_minuto) WHERE status = 'disponivel';

-- ══════════════════════════════════════════════════════════════
-- FIM DO SCHEMA — SustAmbiTech BI v2.0
-- Execute em: https://supabase.com/dashboard/project/qqlggpgsidfhqjgzbwhp/sql
-- ══════════════════════════════════════════════════════════════
SELECT 'Schema SustAmbiTech BI criado com sucesso!' AS status,
       NOW() AS criado_em;
