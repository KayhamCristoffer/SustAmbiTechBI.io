-- ============================================================
-- SustAmbiTech - Eletropostos: Schema de Banco de Dados
-- Foco: Postos de Recarga para Veículos Elétricos e Híbridos
-- Versão: 2.0 | Migração Firebase → Cloudflare D1 (SQLite)
-- ============================================================

-- ============================================================
-- DIMENSÕES (tabelas de referência / lookup)
-- ============================================================

-- Regiões geográficas (cidades/municípios)
CREATE TABLE IF NOT EXISTS dim_regioes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  estado TEXT NOT NULL DEFAULT 'SP',
  latitude_centro REAL,
  longitude_centro REAL,
  populacao INTEGER,
  area_km2 REAL,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tipos de conectores/tomadas para veículos elétricos
CREATE TABLE IF NOT EXISTS dim_conectores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  codigo TEXT UNIQUE NOT NULL,           -- CCS2, CHADEMO, TYPE2, AC_L1, AC_L2, TESLA
  nome TEXT NOT NULL,                    -- Nome completo
  descricao TEXT,
  potencia_max_kw REAL,                  -- Potência máxima em kW
  corrente TEXT,                         -- AC ou DC
  nivel TEXT,                            -- Nivel 1, 2, 3 (DC Fast)
  padrao_region TEXT,                    -- Europa, América do Norte, Japão, Global
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tipos de veículos elétricos e híbridos
CREATE TABLE IF NOT EXISTS dim_tipos_veiculos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  categoria TEXT NOT NULL,               -- BEV, PHEV, HEV, FCEV
  nome TEXT NOT NULL,                    -- Nome da categoria
  descricao TEXT,
  autonomia_media_km INTEGER,
  exemplo_modelos TEXT,                  -- Ex: Tesla Model 3, VW ID.4
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Operadores/redes de recarga
CREATE TABLE IF NOT EXISTS dim_operadores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  site TEXT,
  app TEXT,
  modelo_negocio TEXT,                   -- público, privado, semipúblico
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- TABELA PRINCIPAL: Postos de Recarga
-- ============================================================

CREATE TABLE IF NOT EXISTS postos_recarga (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  firebase_uid TEXT UNIQUE,              -- ID original do Firebase (para rastreabilidade)
  nome TEXT NOT NULL,
  tipo_ponto TEXT NOT NULL DEFAULT 'Posto Eletro',  -- Posto Eletro, Reciclagem, Outros
  ativo INTEGER NOT NULL DEFAULT 1,      -- 1=ativo, 0=inativo

  -- Endereço
  rua TEXT,
  numero TEXT,
  bairro TEXT,
  cidade TEXT NOT NULL,
  estado TEXT NOT NULL DEFAULT 'SP',
  cep TEXT,
  regiao_id INTEGER REFERENCES dim_regioes(id),

  -- Geolocalização
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,

  -- Informações do posto
  operador_id INTEGER REFERENCES dim_operadores(id),
  potencia_max_kw REAL,                  -- Potência máxima disponível
  num_vagas INTEGER DEFAULT 1,           -- Número de vagas de carregamento
  acesso TEXT DEFAULT 'público',         -- público, privado, semipúblico, estacionamento
  horario_funcionamento TEXT,            -- Ex: "24h", "Seg-Sex 09h-18h"
  requer_app INTEGER DEFAULT 0,          -- 1=sim, 0=não
  app_nome TEXT,

  -- Metadados
  observacoes TEXT,
  email_cadastro TEXT,
  usuario_id TEXT,                       -- Firebase UID do usuário que cadastrou
  data_cadastro DATETIME,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Relação N:N entre Postos e Conectores (tipos de tomada)
-- ============================================================

CREATE TABLE IF NOT EXISTS postos_conectores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  posto_id INTEGER NOT NULL REFERENCES postos_recarga(id) ON DELETE CASCADE,
  conector_id INTEGER NOT NULL REFERENCES dim_conectores(id),
  quantidade INTEGER DEFAULT 1,
  potencia_kw REAL,                      -- Potência específica desta tomada
  status TEXT DEFAULT 'disponível',      -- disponível, ocupado, inativo, manutenção
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(posto_id, conector_id)
);

-- ============================================================
-- Compatibilidade Veículo × Conector (matriz de negócio)
-- ============================================================

CREATE TABLE IF NOT EXISTS veiculos_conectores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  veiculo_id INTEGER NOT NULL REFERENCES dim_tipos_veiculos(id),
  conector_id INTEGER NOT NULL REFERENCES dim_conectores(id),
  compativel INTEGER DEFAULT 1,          -- 1=compatível, 0=incompatível
  velocidade TEXT,                       -- lenta, normal, rápida, ultra-rápida
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(veiculo_id, conector_id)
);

-- ============================================================
-- Usuários (migração do Firebase)
-- ============================================================

CREATE TABLE IF NOT EXISTS usuarios (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  firebase_uid TEXT UNIQUE,
  email TEXT UNIQUE NOT NULL,
  nome TEXT,
  sobrenome TEXT,
  nivel TEXT DEFAULT 'usuario',          -- usuario, colaborador, admin
  newsletter_opt_in INTEGER DEFAULT 0,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Avaliações dos Postos (de Firebase + novas)
-- ============================================================

CREATE TABLE IF NOT EXISTS avaliacoes_postos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  firebase_av_id TEXT UNIQUE,            -- ID original do Firebase
  posto_id INTEGER NOT NULL REFERENCES postos_recarga(id) ON DELETE CASCADE,
  usuario_id INTEGER REFERENCES usuarios(id),
  nota INTEGER NOT NULL CHECK (nota BETWEEN 1 AND 5),
  comentario TEXT,
  data_avaliacao DATETIME DEFAULT CURRENT_TIMESTAMP,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Feedbacks do Aplicativo (migração Firebase)
-- ============================================================

CREATE TABLE IF NOT EXISTS feedbacks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  firebase_id TEXT UNIQUE,
  usuario_id INTEGER REFERENCES usuarios(id),
  nota INTEGER CHECK (nota BETWEEN 1 AND 5),
  observacoes TEXT,
  data_feedback DATETIME,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Dados Climáticos (integração OpenMeteo)
-- ============================================================

CREATE TABLE IF NOT EXISTS clima_historico (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cidade TEXT NOT NULL,
  data DATE NOT NULL,
  temperatura_max REAL,
  temperatura_min REAL,
  temperatura_media REAL,
  precipitacao_mm REAL DEFAULT 0,
  umidade_percent INTEGER,
  condicao TEXT,                         -- ensolarado, nublado, chuva, etc.
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(cidade, data)
);

-- ============================================================
-- Log de Importações (auditoria Excel upload)
-- ============================================================

CREATE TABLE IF NOT EXISTS log_importacoes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tipo TEXT NOT NULL,                    -- postos, usuarios, conectores
  arquivo_nome TEXT,
  registros_importados INTEGER DEFAULT 0,
  registros_erros INTEGER DEFAULT 0,
  detalhes_erros TEXT,
  usuario_id INTEGER REFERENCES usuarios(id),
  importado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- KPIs e Metas de Infraestrutura EV
-- ============================================================

CREATE TABLE IF NOT EXISTS kpis_ev (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  indicador TEXT NOT NULL,
  descricao TEXT,
  valor_atual REAL,
  meta_2025 REAL,
  meta_2030 REAL,
  unidade TEXT,
  categoria TEXT,                        -- infraestrutura, ambiental, mobilidade
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ÍNDICES para performance
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_postos_cidade ON postos_recarga(cidade);
CREATE INDEX IF NOT EXISTS idx_postos_bairro ON postos_recarga(bairro);
CREATE INDEX IF NOT EXISTS idx_postos_tipo ON postos_recarga(tipo_ponto);
CREATE INDEX IF NOT EXISTS idx_postos_ativo ON postos_recarga(ativo);
CREATE INDEX IF NOT EXISTS idx_postos_regiao ON postos_recarga(regiao_id);
CREATE INDEX IF NOT EXISTS idx_postos_lat_lon ON postos_recarga(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_postos_conectores_posto ON postos_conectores(posto_id);
CREATE INDEX IF NOT EXISTS idx_avaliacoes_posto ON avaliacoes_postos(posto_id);
CREATE INDEX IF NOT EXISTS idx_avaliacoes_usuario ON avaliacoes_postos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_clima_cidade_data ON clima_historico(cidade, data);
CREATE INDEX IF NOT EXISTS idx_usuarios_firebase ON usuarios(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_postos_firebase ON postos_recarga(firebase_uid);

-- ============================================================
-- VIEW: Resumo por Cidade (útil para Power BI)
-- ============================================================

CREATE VIEW IF NOT EXISTS vw_resumo_cidades AS
SELECT
  p.cidade,
  p.estado,
  COUNT(DISTINCT p.id) AS total_postos,
  COUNT(DISTINCT CASE WHEN p.ativo = 1 THEN p.id END) AS postos_ativos,
  COUNT(DISTINCT pc.conector_id) AS tipos_conector_distintos,
  ROUND(AVG(av.nota), 1) AS media_avaliacoes,
  COUNT(DISTINCT av.id) AS total_avaliacoes,
  COUNT(DISTINCT pc.id) AS total_tomadas
FROM postos_recarga p
LEFT JOIN postos_conectores pc ON p.id = pc.posto_id
LEFT JOIN avaliacoes_postos av ON p.id = av.posto_id
WHERE p.tipo_ponto = 'Posto Eletro'
GROUP BY p.cidade, p.estado;

-- ============================================================
-- VIEW: Postos com Conectores (para mapa e listagem)
-- ============================================================

CREATE VIEW IF NOT EXISTS vw_postos_detalhado AS
SELECT
  p.id,
  p.nome,
  p.tipo_ponto,
  p.ativo,
  p.rua,
  p.numero,
  p.bairro,
  p.cidade,
  p.estado,
  p.cep,
  p.latitude,
  p.longitude,
  p.potencia_max_kw,
  p.num_vagas,
  p.acesso,
  p.horario_funcionamento,
  p.observacoes,
  ROUND(AVG(av.nota), 1) AS media_nota,
  COUNT(DISTINCT av.id) AS total_avaliacoes,
  GROUP_CONCAT(DISTINCT c.codigo) AS conectores,
  COUNT(DISTINCT pc.id) AS num_tomadas
FROM postos_recarga p
LEFT JOIN avaliacoes_postos av ON p.id = av.posto_id
LEFT JOIN postos_conectores pc ON p.id = pc.posto_id
LEFT JOIN dim_conectores c ON pc.conector_id = c.id
GROUP BY p.id;
