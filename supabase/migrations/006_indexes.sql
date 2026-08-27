-- ============================================================
-- SustAmbiTech BI — Migration 006
-- Índices de Performance
-- ============================================================
-- Dependências: 002_tabelas_principais.sql
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- Índices: postos
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_postos_firebase_uid   ON postos (firebase_uid);
CREATE INDEX IF NOT EXISTS idx_postos_ativo          ON postos (ativo);
CREATE INDEX IF NOT EXISTS idx_postos_tipo           ON postos (tipo);
CREATE INDEX IF NOT EXISTS idx_postos_endereco_id    ON postos (endereco_id);
CREATE INDEX IF NOT EXISTS idx_postos_usuario_resp   ON postos (usuario_resp_id);

-- ─────────────────────────────────────────────────────────────
-- Índices: enderecos (geo e texto)
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_enderecos_cidade       ON enderecos (cidade);
CREATE INDEX IF NOT EXISTS idx_enderecos_estado       ON enderecos (estado);
CREATE INDEX IF NOT EXISTS idx_enderecos_latlon       ON enderecos (latitude, longitude);

-- Índice GiST para busca geoespacial (extensão cube+earthdistance ou apenas para ORDER BY)
-- Se habilitar PostGIS: substitua por GIST(ST_MakePoint(longitude, latitude))
CREATE INDEX IF NOT EXISTS idx_enderecos_cep          ON enderecos (cep);

-- ─────────────────────────────────────────────────────────────
-- Índices: tomadas
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tomadas_posto_id       ON tomadas (posto_id);
CREATE INDEX IF NOT EXISTS idx_tomadas_tipo_conector  ON tomadas (tipo_conector);
CREATE INDEX IF NOT EXISTS idx_tomadas_status         ON tomadas (status);
CREATE INDEX IF NOT EXISTS idx_tomadas_custo          ON tomadas (custo_por_minuto);

-- ─────────────────────────────────────────────────────────────
-- Índices: avaliacoes
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_avaliacoes_posto_id    ON avaliacoes (posto_id);
CREATE INDEX IF NOT EXISTS idx_avaliacoes_usuario_id  ON avaliacoes (usuario_id);
CREATE INDEX IF NOT EXISTS idx_avaliacoes_nota        ON avaliacoes (nota);

-- ─────────────────────────────────────────────────────────────
-- Índices: usuarios
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_usuarios_email         ON usuarios (email);
CREATE INDEX IF NOT EXISTS idx_usuarios_firebase_uid  ON usuarios (firebase_uid);
CREATE INDEX IF NOT EXISTS idx_usuarios_nivel         ON usuarios (nivel);

-- ─────────────────────────────────────────────────────────────
-- Índices: veiculos
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_veiculos_tipo_fonte    ON veiculos (tipo_fonte);
CREATE INDEX IF NOT EXISTS idx_veiculos_marca_modelo  ON veiculos (marca, modelo);

-- ─────────────────────────────────────────────────────────────
-- Índices: clima_historico
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_clima_cidade_data      ON clima_historico (cidade, data_hora DESC);
CREATE INDEX IF NOT EXISTS idx_clima_data_hora        ON clima_historico (data_hora DESC);

-- ─────────────────────────────────────────────────────────────
-- Índices: auditoria_log
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_auditoria_tabela       ON auditoria_log (nome_tabela);
CREATE INDEX IF NOT EXISTS idx_auditoria_realizado_em ON auditoria_log (realizado_em DESC);
CREATE INDEX IF NOT EXISTS idx_auditoria_registro_id  ON auditoria_log (registro_id);

-- ─────────────────────────────────────────────────────────────
-- Índice parcial: apenas postos ativos (consultas mais comuns)
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_postos_ativos_cidade
    ON postos (endereco_id)
    WHERE ativo = true;

-- ─────────────────────────────────────────────────────────────
-- Índice parcial: tomadas disponíveis
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tomadas_disponiveis
    ON tomadas (posto_id, custo_por_minuto)
    WHERE status = 'disponivel';
