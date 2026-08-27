-- ============================================================
-- SustAmbiTech BI — Migration 003
-- Tabelas de Auditoria e Backup (Espelhamento)
-- ============================================================
-- Dependências: 002_tabelas_principais.sql
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- TABELA: auditoria_log
-- Registro imutável de todas as operações CRUD no sistema
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS auditoria_log (
    id            UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    nome_tabela   VARCHAR(60)         NOT NULL,
    operacao      operacao_auditoria  NOT NULL,
    registro_id   UUID                NOT NULL,
    dados_antigos JSONB,                                     -- NULL em INSERT
    dados_novos   JSONB,                                     -- NULL em DELETE
    realizado_em  TIMESTAMPTZ         DEFAULT NOW(),
    usuario_db    VARCHAR(100)        DEFAULT current_user,  -- Role do PostgreSQL
    ip_origem     INET,                                      -- IP da conexão (quando disponível)
    session_info  JSONB               DEFAULT '{}'::jsonb   -- Metadados extras (JWT, app, etc.)
);

-- Auditoria é append-only: sem UPDATE/DELETE na própria tabela
-- (protegida por RLS: apenas INSERT é permitido para roles não-admin)
COMMENT ON TABLE  auditoria_log              IS 'Log imutável de auditoria de todas as operações CRUD no sistema';
COMMENT ON COLUMN auditoria_log.dados_antigos IS 'Snapshot JSON do registro ANTES da alteração (NULL em INSERT)';
COMMENT ON COLUMN auditoria_log.dados_novos   IS 'Snapshot JSON do registro APÓS a alteração (NULL em DELETE)';

-- ─────────────────────────────────────────────────────────────
-- TABELAS DE BACKUP (Espelhos sem constraints exclusivas)
-- Replicam a estrutura das tabelas principais.
-- Sem FK/UNIQUE para não bloquear restaurações parciais.
-- Sem PK para permitir duplicatas em cenários de merge.
-- ─────────────────────────────────────────────────────────────

-- Backup: usuarios
CREATE TABLE IF NOT EXISTS usuarios_bkp (
    bkp_id        UUID         DEFAULT gen_random_uuid(),   -- ID próprio do backup
    bkp_em        TIMESTAMPTZ  DEFAULT NOW(),                -- Quando foi espelhado
    bkp_operacao  VARCHAR(10),                               -- INSERT | UPDATE | DELETE
    -- Colunas originais (sem constraints)
    id            UUID,
    firebase_uid  VARCHAR(128),
    email         VARCHAR(255),
    nome          VARCHAR(100),
    sobrenome     VARCHAR(100),
    nivel         TEXT,                                      -- TEXT (sem ENUM constraint)
    newsletter_opt_in BOOLEAN,
    ativo         BOOLEAN,
    criado_em     TIMESTAMPTZ,
    atualizado_em TIMESTAMPTZ
);
COMMENT ON TABLE usuarios_bkp IS 'Espelho de backup da tabela usuarios — populado automaticamente pelos triggers';

-- Backup: enderecos
CREATE TABLE IF NOT EXISTS enderecos_bkp (
    bkp_id        UUID         DEFAULT gen_random_uuid(),
    bkp_em        TIMESTAMPTZ  DEFAULT NOW(),
    bkp_operacao  VARCHAR(10),
    id            UUID,
    cep           VARCHAR(10),
    estado        VARCHAR(2),
    cidade        VARCHAR(100),
    bairro        VARCHAR(100),
    rua           VARCHAR(200),
    numero        VARCHAR(20),
    complemento   VARCHAR(100),
    latitude      NUMERIC(10, 8),
    longitude     NUMERIC(11, 8),
    criado_em     TIMESTAMPTZ,
    atualizado_em TIMESTAMPTZ
);
COMMENT ON TABLE enderecos_bkp IS 'Espelho de backup da tabela enderecos';

-- Backup: postos
CREATE TABLE IF NOT EXISTS postos_bkp (
    bkp_id        UUID         DEFAULT gen_random_uuid(),
    bkp_em        TIMESTAMPTZ  DEFAULT NOW(),
    bkp_operacao  VARCHAR(10),
    id            UUID,
    firebase_uid  VARCHAR(128),
    nome          VARCHAR(200),
    tipo          TEXT,
    endereco_id   UUID,
    usuario_resp_id UUID,
    ativo         BOOLEAN,
    horario_funcionamento VARCHAR(100),
    acesso        VARCHAR(30),
    requer_app    BOOLEAN,
    app_nome      VARCHAR(100),
    observacoes   TEXT,
    criado_em     TIMESTAMPTZ,
    atualizado_em TIMESTAMPTZ
);
COMMENT ON TABLE postos_bkp IS 'Espelho de backup da tabela postos';

-- Backup: tomadas
CREATE TABLE IF NOT EXISTS tomadas_bkp (
    bkp_id        UUID         DEFAULT gen_random_uuid(),
    bkp_em        TIMESTAMPTZ  DEFAULT NOW(),
    bkp_operacao  VARCHAR(10),
    id            UUID,
    posto_id      UUID,
    tipo_conector VARCHAR(50),
    potencia_kw   NUMERIC(6, 2),
    custo_por_minuto NUMERIC(10, 4),
    custo_por_kwh NUMERIC(10, 4),
    tempo_recarga_estimado_min INT,
    quantidade    INT,
    status        TEXT,
    criado_em     TIMESTAMPTZ,
    atualizado_em TIMESTAMPTZ
);
COMMENT ON TABLE tomadas_bkp IS 'Espelho de backup da tabela tomadas';

-- Backup: veiculos
CREATE TABLE IF NOT EXISTS veiculos_bkp (
    bkp_id        UUID         DEFAULT gen_random_uuid(),
    bkp_em        TIMESTAMPTZ  DEFAULT NOW(),
    bkp_operacao  VARCHAR(10),
    id            UUID,
    marca         VARCHAR(100),
    modelo        VARCHAR(100),
    ano_lancamento INT,
    tipo_fonte    TEXT,
    preco_estimado NUMERIC(15, 2),
    capacidade_bateria_kwh NUMERIC(6, 2),
    autonomia_km  INT,
    tempo_recarga_ac_min INT,
    tempo_recarga_dc_min INT,
    conectores_compativeis VARCHAR(200),
    fonte         TEXT,
    ativo         BOOLEAN,
    criado_em     TIMESTAMPTZ,
    atualizado_em TIMESTAMPTZ
);
COMMENT ON TABLE veiculos_bkp IS 'Espelho de backup da tabela veiculos';

-- Backup: avaliacoes
CREATE TABLE IF NOT EXISTS avaliacoes_bkp (
    bkp_id        UUID         DEFAULT gen_random_uuid(),
    bkp_em        TIMESTAMPTZ  DEFAULT NOW(),
    bkp_operacao  VARCHAR(10),
    id            UUID,
    firebase_id   VARCHAR(128),
    posto_id      UUID,
    usuario_id    UUID,
    nota          INT,
    comentario    TEXT,
    criado_em     TIMESTAMPTZ,
    atualizado_em TIMESTAMPTZ
);
COMMENT ON TABLE avaliacoes_bkp IS 'Espelho de backup da tabela avaliacoes';

-- Backup: feedbacks
CREATE TABLE IF NOT EXISTS feedbacks_bkp (
    bkp_id        UUID         DEFAULT gen_random_uuid(),
    bkp_em        TIMESTAMPTZ  DEFAULT NOW(),
    bkp_operacao  VARCHAR(10),
    id            UUID,
    firebase_id   VARCHAR(128),
    usuario_id    UUID,
    nota          INT,
    observacoes   TEXT,
    categoria     VARCHAR(50),
    criado_em     TIMESTAMPTZ,
    atualizado_em TIMESTAMPTZ
);
COMMENT ON TABLE feedbacks_bkp IS 'Espelho de backup da tabela feedbacks';

-- Backup: clima_historico
CREATE TABLE IF NOT EXISTS clima_historico_bkp (
    bkp_id                UUID         DEFAULT gen_random_uuid(),
    bkp_em                TIMESTAMPTZ  DEFAULT NOW(),
    bkp_operacao          VARCHAR(10),
    id                    UUID,
    cidade                VARCHAR(100),
    estado                VARCHAR(2),
    latitude              NUMERIC(10, 8),
    longitude             NUMERIC(11, 8),
    data_hora             TIMESTAMPTZ,
    temperatura_atual     NUMERIC(5, 2),
    temperatura_max       NUMERIC(5, 2),
    temperatura_min       NUMERIC(5, 2),
    sensacao_termica      NUMERIC(5, 2),
    umidade_percent       INT,
    precipitacao_mm       NUMERIC(6, 2),
    velocidade_vento_kmh  NUMERIC(6, 2),
    codigo_clima          INT,
    condicao_climatica    VARCHAR(100),
    previsao_futura       JSONB,
    fonte_api             VARCHAR(50),
    criado_em             TIMESTAMPTZ,
    atualizado_em         TIMESTAMPTZ
);
COMMENT ON TABLE clima_historico_bkp IS 'Espelho de backup da tabela clima_historico';
