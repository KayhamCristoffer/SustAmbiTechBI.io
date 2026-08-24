-- ============================================================
-- SUSTAMBITECH - SCHEMA COMPLETO PARA POWER BI
-- Banco de dados D1 (SQLite) - Cloudflare
-- Versão: 1.0.0
-- Descrição: Schema completo para análise de sustentabilidade
--             ambiental com suporte a Power BI
-- ============================================================

-- ============================================================
-- DIMENSÕES (Tabelas de referência)
-- ============================================================

-- Dimensão: Regiões Geográficas
CREATE TABLE IF NOT EXISTS dim_regioes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  estado TEXT NOT NULL,
  regiao_brasil TEXT NOT NULL CHECK(regiao_brasil IN ('Norte','Nordeste','Centro-Oeste','Sudeste','Sul')),
  latitude REAL,
  longitude REAL,
  populacao INTEGER,
  area_km2 REAL,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Dimensão: Categorias de Sustentabilidade
CREATE TABLE IF NOT EXISTS dim_categorias (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL UNIQUE,
  descricao TEXT,
  icone TEXT,
  cor_hex TEXT,
  ods_relacionado TEXT,  -- ODS ONU relacionado (ex: "ODS 7, ODS 13")
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Dimensão: Usuários / Perfis
CREATE TABLE IF NOT EXISTS dim_usuarios (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  tipo_usuario TEXT NOT NULL CHECK(tipo_usuario IN ('cidadao','empresa','orgao_publico','pesquisador','ong')),
  cidade TEXT,
  estado TEXT,
  regiao_id INTEGER REFERENCES dim_regioes(id),
  data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
  ativo INTEGER DEFAULT 1,
  pontos_sustentabilidade INTEGER DEFAULT 0,
  nivel_engajamento TEXT DEFAULT 'iniciante' CHECK(nivel_engajamento IN ('iniciante','intermediario','avancado','especialista'))
);

-- Dimensão: Tipos de Resíduos
CREATE TABLE IF NOT EXISTS dim_tipos_residuos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL UNIQUE,
  classificacao TEXT NOT NULL CHECK(classificacao IN ('reciclavel','organico','perigoso','especial','rejeito')),
  descricao TEXT,
  tempo_decomposicao_anos INTEGER,
  periculosidade TEXT CHECK(periculosidade IN ('baixa','media','alta','muito_alta')),
  cor_padrao_separacao TEXT
);

-- Dimensão: Tipos de Fontes de Energia
CREATE TABLE IF NOT EXISTS dim_fontes_energia (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL UNIQUE,
  tipo TEXT NOT NULL CHECK(tipo IN ('renovavel','nao_renovavel','alternativa')),
  emissao_co2_por_kwh REAL,  -- gramas de CO2 por kWh
  renovavel INTEGER DEFAULT 0,
  descricao TEXT
);

-- Dimensão: Espécies / Biodiversidade
CREATE TABLE IF NOT EXISTS dim_especies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome_cientifico TEXT NOT NULL,
  nome_popular TEXT NOT NULL,
  reino TEXT NOT NULL CHECK(reino IN ('animal','vegetal','fungo','protista','monera')),
  classe TEXT,
  status_conservacao TEXT CHECK(status_conservacao IN ('LC','NT','VU','EN','CR','EW','EX')),
  bioma TEXT,
  endemismo INTEGER DEFAULT 0,
  descricao TEXT
);

-- ============================================================
-- FATOS (Tabelas de eventos e métricas)
-- ============================================================

-- Fato: Monitoramento da Qualidade do Ar
CREATE TABLE IF NOT EXISTS fato_qualidade_ar (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  regiao_id INTEGER NOT NULL REFERENCES dim_regioes(id),
  data_medicao DATETIME NOT NULL,
  pm25 REAL,           -- Material Particulado 2.5μm (μg/m³)
  pm10 REAL,           -- Material Particulado 10μm (μg/m³)
  co2_ppm REAL,        -- CO2 em partes por milhão
  o3_ppb REAL,         -- Ozônio em ppb
  no2_ppb REAL,        -- Dióxido de Nitrogênio em ppb
  so2_ppb REAL,        -- Dióxido de Enxofre em ppb
  indice_qualidade_ar INTEGER,  -- IQA (0-500)
  classificacao_ar TEXT CHECK(classificacao_ar IN ('boa','moderada','inadequada','ma','pessima','critica')),
  temperatura_celsius REAL,
  umidade_relativa REAL,
  velocidade_vento_kmh REAL,
  fonte_dados TEXT DEFAULT 'sensor_virtual',
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Qualidade da Água
CREATE TABLE IF NOT EXISTS fato_qualidade_agua (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  regiao_id INTEGER NOT NULL REFERENCES dim_regioes(id),
  tipo_corpo_hidrico TEXT CHECK(tipo_corpo_hidrico IN ('rio','lago','reservatorio','mar','poco','nascente')),
  data_medicao DATETIME NOT NULL,
  ph REAL,
  turbidez_ntu REAL,
  oxigenio_dissolvido_mgl REAL,
  dbo_mgl REAL,        -- Demanda Bioquímica de Oxigênio
  coliformes_totais REAL,
  nitratos_mgl REAL,
  fosfatos_mgl REAL,
  temperatura_celsius REAL,
  indice_qualidade_agua REAL,  -- IQA (0-100)
  classificacao_agua TEXT CHECK(classificacao_agua IN ('otima','boa','razoavel','ruim','pessima')),
  adequada_consumo INTEGER DEFAULT 0,
  fonte_dados TEXT DEFAULT 'laboratorio',
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Consumo de Energia
CREATE TABLE IF NOT EXISTS fato_consumo_energia (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id INTEGER REFERENCES dim_usuarios(id),
  regiao_id INTEGER NOT NULL REFERENCES dim_regioes(id),
  fonte_energia_id INTEGER REFERENCES dim_fontes_energia(id),
  data_referencia DATE NOT NULL,
  consumo_kwh REAL NOT NULL,
  custo_real REAL,
  emissao_co2_kg REAL,
  setor TEXT CHECK(setor IN ('residencial','comercial','industrial','publico','transporte','agropecuario')),
  reducao_vs_mes_anterior_pct REAL,
  meta_reducao_pct REAL DEFAULT 10,
  atingiu_meta INTEGER DEFAULT 0,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Coleta e Reciclagem de Resíduos
CREATE TABLE IF NOT EXISTS fato_reciclagem (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  regiao_id INTEGER NOT NULL REFERENCES dim_regioes(id),
  usuario_id INTEGER REFERENCES dim_usuarios(id),
  tipo_residuo_id INTEGER NOT NULL REFERENCES dim_tipos_residuos(id),
  data_coleta DATETIME NOT NULL,
  quantidade_kg REAL NOT NULL,
  destinacao TEXT CHECK(destinacao IN ('reciclagem','compostagem','aterro_sanitario','incineracao','reuso','doacao')),
  ponto_coleta TEXT,
  cooperativa TEXT,
  valor_arrecadado REAL,
  co2_evitado_kg REAL,  -- CO2 evitado pelo processo de reciclagem
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Frota de Veículos Elétricos
CREATE TABLE IF NOT EXISTS fato_veiculos_eletricos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  regiao_id INTEGER NOT NULL REFERENCES dim_regioes(id),
  data_referencia DATE NOT NULL,
  total_veiculos_eletricos INTEGER DEFAULT 0,
  total_hibridos INTEGER DEFAULT 0,
  total_combustao INTEGER DEFAULT 0,
  novos_emplacamentos_eletricos INTEGER DEFAULT 0,
  eletropostos_ativos INTEGER DEFAULT 0,
  km_rodados_eletricos REAL,
  co2_evitado_kg REAL,
  economia_combustivel_litros REAL,
  modelo_mais_vendido TEXT,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Indicadores Climáticos
CREATE TABLE IF NOT EXISTS fato_indicadores_climaticos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  regiao_id INTEGER NOT NULL REFERENCES dim_regioes(id),
  data_referencia DATE NOT NULL,
  temperatura_media REAL,
  temperatura_max REAL,
  temperatura_min REAL,
  precipitacao_mm REAL,
  eventos_extremos INTEGER DEFAULT 0,
  tipo_evento_extremo TEXT,
  nivel_rio_cm REAL,
  nivel_reservatorio_pct REAL,
  indice_seca REAL,
  anomalia_termica REAL,  -- Desvio em relação à média histórica
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Desmatamento e Cobertura Vegetal
CREATE TABLE IF NOT EXISTS fato_cobertura_vegetal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  regiao_id INTEGER NOT NULL REFERENCES dim_regioes(id),
  data_referencia DATE NOT NULL,
  area_total_ha REAL,
  area_vegetacao_nativa_ha REAL,
  area_desmatada_ha REAL,
  area_reflorestada_ha REAL,
  area_degradada_ha REAL,
  taxa_desmatamento_anual_pct REAL,
  taxa_recuperacao_pct REAL,
  carbono_estocado_ton REAL,
  indice_vegetacao REAL,  -- NDVI médio
  bioma TEXT,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Educação Ambiental
CREATE TABLE IF NOT EXISTS fato_educacao_ambiental (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id INTEGER REFERENCES dim_usuarios(id),
  regiao_id INTEGER REFERENCES dim_regioes(id),
  data_atividade DATETIME NOT NULL,
  tipo_atividade TEXT CHECK(tipo_atividade IN ('quiz','workshop','video','artigo','campanha','visita_tecnica','palestra','treinamento')),
  titulo_atividade TEXT NOT NULL,
  pontuacao INTEGER DEFAULT 0,
  duracao_minutos INTEGER,
  categoria_id INTEGER REFERENCES dim_categorias(id),
  concluido INTEGER DEFAULT 0,
  certificado_emitido INTEGER DEFAULT 0,
  nivel_dificuldade TEXT CHECK(nivel_dificuldade IN ('basico','intermediario','avancado')),
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Denúncias Ambientais
CREATE TABLE IF NOT EXISTS fato_denuncias (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id INTEGER REFERENCES dim_usuarios(id),
  regiao_id INTEGER NOT NULL REFERENCES dim_regioes(id),
  data_denuncia DATETIME NOT NULL,
  tipo_denuncia TEXT CHECK(tipo_denuncia IN ('desmatamento','queimada','poluicao_ar','poluicao_agua','descarte_ilegal','caca_pesca_ilegal','outros')),
  descricao TEXT,
  latitude REAL,
  longitude REAL,
  status TEXT DEFAULT 'pendente' CHECK(status IN ('pendente','em_analise','resolvido','arquivado','improcedente')),
  orgao_responsavel TEXT,
  data_resolucao DATETIME,
  impacto_estimado TEXT CHECK(impacto_estimado IN ('baixo','medio','alto','critico')),
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Consumo Consciente / Produtos
CREATE TABLE IF NOT EXISTS fato_consumo_consciente (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id INTEGER REFERENCES dim_usuarios(id),
  data_analise DATETIME NOT NULL,
  produto_nome TEXT NOT NULL,
  categoria_produto TEXT,
  certificacao_ambiental TEXT,  -- ISO 14001, FSC, Rainforest Alliance, etc.
  pontuacao_sustentabilidade INTEGER DEFAULT 0 CHECK(pontuacao_sustentabilidade BETWEEN 0 AND 100),
  pegada_carbono_kg REAL,
  origem_produto TEXT CHECK(origem_produto IN ('local','nacional','importado')),
  embalagem_reciclavel INTEGER DEFAULT 0,
  comercio_justo INTEGER DEFAULT 0,
  recomendado INTEGER DEFAULT 0,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Políticas e Legislação Ambiental
CREATE TABLE IF NOT EXISTS fato_politicas_ambientais (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  titulo TEXT NOT NULL,
  tipo TEXT CHECK(tipo IN ('lei','decreto','resolucao','norma','tratado_internacional','politica_publica')),
  esfera TEXT CHECK(esfera IN ('federal','estadual','municipal','internacional')),
  data_publicacao DATE NOT NULL,
  data_vigencia DATE,
  status TEXT DEFAULT 'vigente' CHECK(status IN ('vigente','revogada','em_discussao','aprovada','vetada')),
  descricao TEXT,
  orgao_responsavel TEXT,
  regiao_id INTEGER REFERENCES dim_regioes(id),
  impacto_ambiental TEXT CHECK(impacto_ambiental IN ('muito_positivo','positivo','neutro','negativo','muito_negativo')),
  tags TEXT,  -- JSON array como string
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fato: Ecopontos (Pontos de Coleta)
CREATE TABLE IF NOT EXISTS fato_ecopontos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  regiao_id INTEGER NOT NULL REFERENCES dim_regioes(id),
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  endereco TEXT,
  bairro TEXT,
  cidade TEXT NOT NULL,
  estado TEXT NOT NULL,
  tipos_residuos_aceitos TEXT,  -- JSON array como string
  capacidade_toneladas_mes REAL,
  volume_coletado_mes_kg REAL,
  horario_funcionamento TEXT,
  responsavel TEXT,
  ativo INTEGER DEFAULT 1,
  avaliacao_media REAL DEFAULT 0,
  total_avaliacoes INTEGER DEFAULT 0,
  data_inauguracao DATE,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- TABELAS DE SUPORTE / RELACIONAMENTO
-- ============================================================

-- Tabela: KPIs e Metas de Sustentabilidade
CREATE TABLE IF NOT EXISTS tb_kpis_metas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  categoria_id INTEGER REFERENCES dim_categorias(id),
  nome_kpi TEXT NOT NULL,
  descricao TEXT,
  unidade_medida TEXT NOT NULL,
  valor_meta REAL NOT NULL,
  valor_atual REAL DEFAULT 0,
  ano_referencia INTEGER NOT NULL,
  mes_referencia INTEGER,
  prazo_meta DATE,
  status_meta TEXT DEFAULT 'em_andamento' CHECK(status_meta IN ('em_andamento','atingida','nao_atingida','superada','cancelada')),
  percentual_atingimento REAL DEFAULT 0,
  ods_relacionado TEXT,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela: Alertas e Notificações
CREATE TABLE IF NOT EXISTS tb_alertas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tipo_alerta TEXT NOT NULL CHECK(tipo_alerta IN ('qualidade_ar','qualidade_agua','desmatamento','evento_climatico','meta_atingida','denuncia','outros')),
  titulo TEXT NOT NULL,
  descricao TEXT,
  regiao_id INTEGER REFERENCES dim_regioes(id),
  severidade TEXT DEFAULT 'informativo' CHECK(severidade IN ('informativo','aviso','critico','emergencia')),
  data_alerta DATETIME DEFAULT CURRENT_TIMESTAMP,
  ativo INTEGER DEFAULT 1,
  resolvido INTEGER DEFAULT 0,
  data_resolucao DATETIME
);

-- Tabela: Logs de Atividade (Auditoria)
CREATE TABLE IF NOT EXISTS tb_logs_atividade (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id INTEGER REFERENCES dim_usuarios(id),
  acao TEXT NOT NULL,
  tabela_afetada TEXT,
  registro_id INTEGER,
  dados_anteriores TEXT,
  dados_novos TEXT,
  ip_address TEXT,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ÍNDICES PARA PERFORMANCE NO POWER BI
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_qualidade_ar_data ON fato_qualidade_ar(data_medicao);
CREATE INDEX IF NOT EXISTS idx_qualidade_ar_regiao ON fato_qualidade_ar(regiao_id);
CREATE INDEX IF NOT EXISTS idx_qualidade_agua_data ON fato_qualidade_agua(data_medicao);
CREATE INDEX IF NOT EXISTS idx_qualidade_agua_regiao ON fato_qualidade_agua(regiao_id);
CREATE INDEX IF NOT EXISTS idx_energia_data ON fato_consumo_energia(data_referencia);
CREATE INDEX IF NOT EXISTS idx_energia_regiao ON fato_consumo_energia(regiao_id);
CREATE INDEX IF NOT EXISTS idx_reciclagem_data ON fato_reciclagem(data_coleta);
CREATE INDEX IF NOT EXISTS idx_reciclagem_regiao ON fato_reciclagem(regiao_id);
CREATE INDEX IF NOT EXISTS idx_veiculos_data ON fato_veiculos_eletricos(data_referencia);
CREATE INDEX IF NOT EXISTS idx_climatico_data ON fato_indicadores_climaticos(data_referencia);
CREATE INDEX IF NOT EXISTS idx_cobertura_data ON fato_cobertura_vegetal(data_referencia);
CREATE INDEX IF NOT EXISTS idx_educacao_data ON fato_educacao_ambiental(data_atividade);
CREATE INDEX IF NOT EXISTS idx_denuncias_data ON fato_denuncias(data_denuncia);
CREATE INDEX IF NOT EXISTS idx_denuncias_status ON fato_denuncias(status);
CREATE INDEX IF NOT EXISTS idx_ecopontos_regiao ON fato_ecopontos(regiao_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_tipo ON dim_usuarios(tipo_usuario);
CREATE INDEX IF NOT EXISTS idx_usuarios_regiao ON dim_usuarios(regiao_id);
CREATE INDEX IF NOT EXISTS idx_kpis_ano ON tb_kpis_metas(ano_referencia);
