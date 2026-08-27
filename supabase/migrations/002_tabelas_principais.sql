-- ============================================================
-- SustAmbiTech BI — Migration 002
-- Tabelas Principais (Esquema de Produção)
-- ============================================================
-- Dependências: 001_enums_e_extensoes.sql
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- TABELA: usuarios
-- Perfis de usuários do sistema (Firebase UID mantido para migração)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS usuarios (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid      VARCHAR(128) UNIQUE,                  -- Compatibilidade Firebase
    email             VARCHAR(255) UNIQUE NOT NULL,
    nome              VARCHAR(100) NOT NULL,
    sobrenome         VARCHAR(100),
    nivel             nivel_usuario DEFAULT 'comum',
    newsletter_opt_in BOOLEAN      DEFAULT false,
    ativo             BOOLEAN      DEFAULT true,
    criado_em         TIMESTAMPTZ  DEFAULT NOW(),
    atualizado_em     TIMESTAMPTZ  DEFAULT NOW()
);

COMMENT ON TABLE  usuarios                IS 'Usuários cadastrados no sistema SustAmbiTech';
COMMENT ON COLUMN usuarios.firebase_uid   IS 'UID original do Firebase para rastreabilidade na migração';
COMMENT ON COLUMN usuarios.nivel          IS 'comum = usuário padrão | admin = acesso total | operador = gestão de postos';

-- ─────────────────────────────────────────────────────────────
-- TABELA: enderecos
-- Separada para reutilização por postos (e futuramente usuários)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS enderecos (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    cep           VARCHAR(10),
    estado        VARCHAR(2)   NOT NULL,
    cidade        VARCHAR(100) NOT NULL,
    bairro        VARCHAR(100),
    rua           VARCHAR(200),
    numero        VARCHAR(20),
    complemento   VARCHAR(100),
    latitude      NUMERIC(10, 8) NOT NULL,
    longitude     NUMERIC(11, 8) NOT NULL,
    criado_em     TIMESTAMPTZ  DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ  DEFAULT NOW()
);

COMMENT ON TABLE enderecos IS 'Endereços georreferenciados dos postos de recarga';

-- ─────────────────────────────────────────────────────────────
-- TABELA: postos
-- Postos de recarga elétrica, reciclagem e pontos ambientais
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS postos (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid     VARCHAR(128) UNIQUE,                   -- Compatibilidade Firebase
    nome             VARCHAR(200) NOT NULL,
    tipo             tipo_energia NOT NULL DEFAULT 'eletrico',
    endereco_id      UUID        NOT NULL REFERENCES enderecos(id) ON DELETE RESTRICT,
    usuario_resp_id  UUID        REFERENCES usuarios(id) ON DELETE SET NULL,
    ativo            BOOLEAN     DEFAULT true,
    horario_funcionamento VARCHAR(100),                     -- Ex: "Seg-Sex 08h-22h"
    acesso           VARCHAR(30) DEFAULT 'público',         -- público, privado, restrito
    requer_app       BOOLEAN     DEFAULT false,
    app_nome         VARCHAR(100),
    observacoes      TEXT,
    criado_em        TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE  postos               IS 'Postos de recarga elétrica (EV) e pontos ambientais';
COMMENT ON COLUMN postos.firebase_uid  IS 'UID original do Firebase para rastreabilidade';
COMMENT ON COLUMN postos.tipo          IS 'comum=AC simples | hibrido=PHEV | eletrico=BEV Fast/Ultra Charge';

-- ─────────────────────────────────────────────────────────────
-- TABELA: tomadas
-- Conectores disponíveis em cada posto
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tomadas (
    id                         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    posto_id                   UUID          NOT NULL REFERENCES postos(id) ON DELETE CASCADE,
    tipo_conector              VARCHAR(50)   NOT NULL,      -- CCS2, CHAdeMO, Type2, AC_L1, AC_L2
    potencia_kw                NUMERIC(6, 2),               -- Potência nominal em kW
    custo_por_minuto           NUMERIC(10, 4) NOT NULL DEFAULT 0.00, -- R$ por minuto
    custo_por_kwh              NUMERIC(10, 4) DEFAULT 0.00, -- R$ por kWh (alternativa)
    tempo_recarga_estimado_min INT,                         -- Minutos para recarga de 0→80%
    quantidade                 INT           DEFAULT 1,     -- Nº de tomadas deste tipo no posto
    status                     status_tomada DEFAULT 'disponivel',
    criado_em                  TIMESTAMPTZ   DEFAULT NOW(),
    atualizado_em              TIMESTAMPTZ   DEFAULT NOW()
);

COMMENT ON TABLE  tomadas                          IS 'Conectores/tomadas de cada posto com custo e tempo de recarga';
COMMENT ON COLUMN tomadas.custo_por_minuto         IS 'Custo em R$ por minuto de recarga';
COMMENT ON COLUMN tomadas.custo_por_kwh            IS 'Custo em R$ por kWh consumido (modelo alternativo)';
COMMENT ON COLUMN tomadas.tempo_recarga_estimado_min IS 'Estimativa em minutos para carregar de 0% a 80%';

-- ─────────────────────────────────────────────────────────────
-- TABELA: veiculos
-- Catálogo de veículos elétricos/híbridos para comparação
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS veiculos (
    id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    marca                 VARCHAR(100)  NOT NULL,
    modelo                VARCHAR(100)  NOT NULL,
    ano_lancamento        INT,
    tipo_fonte            tipo_energia  NOT NULL DEFAULT 'eletrico',
    preco_estimado        NUMERIC(15, 2),                     -- Preço em R$
    capacidade_bateria_kwh NUMERIC(6, 2),                    -- kWh da bateria
    autonomia_km          INT,                                -- Autonomia em km (WLTP)
    tempo_recarga_ac_min  INT,                                -- Minutos carga AC (0→100%)
    tempo_recarga_dc_min  INT,                                -- Minutos carga DC rápida (0→80%)
    conectores_compativeis VARCHAR(200),                      -- Ex: "CCS2,Type2,AC_L2"
    fonte                 TEXT,                               -- URL do fabricante/site externo
    ativo                 BOOLEAN       DEFAULT true,
    criado_em             TIMESTAMPTZ   DEFAULT NOW(),
    atualizado_em         TIMESTAMPTZ   DEFAULT NOW(),
    UNIQUE (marca, modelo, ano_lancamento)
);

COMMENT ON TABLE  veiculos              IS 'Catálogo de veículos elétricos e híbridos para análise de compatibilidade';
COMMENT ON COLUMN veiculos.fonte        IS 'Link externo para ficha técnica ou site do fabricante';
COMMENT ON COLUMN veiculos.preco_estimado IS 'Preço estimado em R$ no mercado brasileiro';

-- ─────────────────────────────────────────────────────────────
-- TABELA: avaliacoes
-- Avaliações de usuários sobre postos (1-5 estrelas)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS avaliacoes (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_id  VARCHAR(128) UNIQUE,                        -- ID Firebase da avaliação
    posto_id     UUID        NOT NULL REFERENCES postos(id) ON DELETE CASCADE,
    usuario_id   UUID        NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    nota         INT         NOT NULL CHECK (nota >= 1 AND nota <= 5),
    comentario   TEXT,
    criado_em    TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (posto_id, usuario_id)                            -- 1 avaliação por usuário/posto
);

COMMENT ON TABLE  avaliacoes        IS 'Avaliações de usuários sobre postos (escala 1-5)';
COMMENT ON COLUMN avaliacoes.nota   IS 'Nota de 1 (péssimo) a 5 (excelente)';

-- ─────────────────────────────────────────────────────────────
-- TABELA: feedbacks
-- Feedbacks gerais sobre a plataforma (migrados do Firebase)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS feedbacks (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_id  VARCHAR(128) UNIQUE,
    usuario_id   UUID        REFERENCES usuarios(id) ON DELETE SET NULL,
    nota         INT         CHECK (nota >= 1 AND nota <= 5),
    observacoes  TEXT,
    categoria    VARCHAR(50) DEFAULT 'geral',                -- geral, bug, sugestao, elogio
    criado_em    TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE feedbacks IS 'Feedbacks gerais sobre a plataforma (migrados do Firebase + novos)';

-- ─────────────────────────────────────────────────────────────
-- TABELA: clima_historico
-- Dados climáticos salvos das chamadas à Open-Meteo API
-- Estrutura otimizada para análise no Power BI
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clima_historico (
    id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    cidade               VARCHAR(100)  NOT NULL,
    estado               VARCHAR(2)    DEFAULT 'SP',
    latitude             NUMERIC(10, 8),
    longitude            NUMERIC(11, 8),
    data_hora            TIMESTAMPTZ   NOT NULL,             -- Momento da observação
    -- Dados atuais (snapshot do momento da chamada)
    temperatura_atual    NUMERIC(5, 2),
    temperatura_max      NUMERIC(5, 2),
    temperatura_min      NUMERIC(5, 2),
    sensacao_termica     NUMERIC(5, 2),
    umidade_percent      INT,
    precipitacao_mm      NUMERIC(6, 2) DEFAULT 0,
    velocidade_vento_kmh NUMERIC(6, 2),
    codigo_clima         INT,                                -- WMO Weather Code
    condicao_climatica   VARCHAR(100),                       -- Descrição textual do código WMO
    -- Previsão dos próximos dias (JSONB para flexibilidade)
    -- Estrutura: [{"data": "2025-01-15", "temp_max": 32, "temp_min": 22, "precipitacao": 0, "codigo": 0}]
    previsao_futura      JSONB         DEFAULT '[]'::jsonb,
    -- Controle
    fonte_api            VARCHAR(50)   DEFAULT 'open-meteo', -- open-meteo, inmet, etc.
    criado_em            TIMESTAMPTZ   DEFAULT NOW(),
    atualizado_em        TIMESTAMPTZ   DEFAULT NOW(),
    UNIQUE (cidade, data_hora)
);

COMMENT ON TABLE  clima_historico              IS 'Histórico climático salvo das chamadas Open-Meteo — usado no Power BI';
COMMENT ON COLUMN clima_historico.previsao_futura IS 'Array JSON com previsão dos próximos 7 dias [{data, temp_max, temp_min, precipitacao, codigo}]';
COMMENT ON COLUMN clima_historico.codigo_clima  IS 'Código WMO: 0=limpo, 1-3=nublado, 45-48=neblina, 51-57=chuvisco, 61-67=chuva, 95-99=trovoada';

-- ─────────────────────────────────────────────────────────────
-- TABELA: log_importacoes
-- Rastreamento de importações via Excel/CSV
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS log_importacoes (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo                 VARCHAR(50) NOT NULL,               -- postos, veiculos, usuarios
    arquivo_nome         VARCHAR(255),
    registros_importados INT         DEFAULT 0,
    registros_erros      INT         DEFAULT 0,
    detalhes_erros       JSONB       DEFAULT '[]'::jsonb,
    usuario_id           UUID        REFERENCES usuarios(id) ON DELETE SET NULL,
    importado_em         TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE log_importacoes IS 'Histórico de todas as importações Excel/CSV realizadas no sistema';
