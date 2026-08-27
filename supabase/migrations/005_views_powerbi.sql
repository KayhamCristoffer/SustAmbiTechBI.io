-- ============================================================
-- SustAmbiTech BI — Migration 005
-- VIEWs para Power BI e Análise de Dados
-- ============================================================
-- Dependências: 002_tabelas_principais.sql
-- Cada VIEW tem suporte a ?format=csv no endpoint REST
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- VIEW 1: vw_postos_completo
-- Visão desnormalizada de postos com endereço, tomadas e avaliações
-- Power BI: "Quais postos em X região têm Y custo menor"
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_postos_completo AS
SELECT
    p.id                             AS posto_id,
    p.firebase_uid,
    p.nome                           AS posto_nome,
    p.tipo::TEXT                     AS tipo_energia,
    p.ativo,
    p.horario_funcionamento,
    p.acesso,
    p.requer_app,
    p.app_nome,
    p.observacoes,
    -- Endereço
    e.cep,
    e.rua,
    e.numero,
    e.bairro,
    e.cidade,
    e.estado,
    e.latitude,
    e.longitude,
    -- Tomadas agregadas
    COUNT(DISTINCT t.id)             AS total_tomadas,
    MIN(t.custo_por_minuto)          AS custo_min_por_minuto,
    MAX(t.custo_por_minuto)          AS custo_max_por_minuto,
    ROUND(AVG(t.custo_por_minuto), 4) AS custo_medio_por_minuto,
    MIN(t.custo_por_kwh)             AS custo_min_por_kwh,
    MAX(t.potencia_kw)               AS potencia_max_kw,
    STRING_AGG(DISTINCT t.tipo_conector, ', ' ORDER BY t.tipo_conector) AS conectores,
    -- Avaliações
    COUNT(DISTINCT av.id)            AS total_avaliacoes,
    ROUND(AVG(av.nota), 2)           AS media_nota,
    -- Responsável
    u.nome || ' ' || COALESCE(u.sobrenome, '') AS usuario_resp,
    p.criado_em,
    p.atualizado_em
FROM postos p
JOIN enderecos e         ON p.endereco_id = e.id
LEFT JOIN tomadas t      ON t.posto_id = p.id
LEFT JOIN avaliacoes av  ON av.posto_id = p.id
LEFT JOIN usuarios u     ON u.id = p.usuario_resp_id
GROUP BY p.id, e.id, u.id;

COMMENT ON VIEW vw_postos_completo IS
  'Visão completa de postos com endereço, tomadas e avaliações — use no Power BI para análise de custo e cobertura';

-- ─────────────────────────────────────────────────────────────
-- VIEW 2: vw_resumo_por_cidade
-- KPIs por cidade: total de postos, tipos, custo médio, cobertura
-- Power BI: Mapa coroplético / Gráfico de barras por cidade
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_resumo_por_cidade AS
SELECT
    e.cidade,
    e.estado,
    -- Contagens
    COUNT(DISTINCT p.id)                                                  AS total_postos,
    COUNT(DISTINCT CASE WHEN p.ativo THEN p.id END)                       AS postos_ativos,
    COUNT(DISTINCT CASE WHEN p.tipo = 'eletrico' THEN p.id END)          AS postos_eletrico,
    COUNT(DISTINCT CASE WHEN p.tipo = 'hibrido' THEN p.id END)           AS postos_hibrido,
    COUNT(DISTINCT CASE WHEN p.tipo = 'comum' THEN p.id END)             AS postos_comum,
    -- Tomadas
    COUNT(DISTINCT t.id)                                                  AS total_tomadas,
    STRING_AGG(DISTINCT t.tipo_conector, ', ')                           AS tipos_conector,
    -- Custo
    ROUND(AVG(t.custo_por_minuto), 4)                                    AS custo_medio_min,
    MIN(t.custo_por_minuto)                                              AS custo_minimo_min,
    -- Avaliações
    ROUND(AVG(av.nota), 2)                                               AS media_avaliacoes,
    COUNT(DISTINCT av.id)                                                AS total_avaliacoes,
    -- Geo (centroide aproximado)
    ROUND(AVG(e.latitude)::NUMERIC, 6)                                   AS lat_media,
    ROUND(AVG(e.longitude)::NUMERIC, 6)                                  AS lon_media
FROM postos p
JOIN enderecos e         ON p.endereco_id = e.id
LEFT JOIN tomadas t      ON t.posto_id = p.id
LEFT JOIN avaliacoes av  ON av.posto_id = p.id
GROUP BY e.cidade, e.estado
ORDER BY total_postos DESC;

COMMENT ON VIEW vw_resumo_por_cidade IS
  'KPIs agregados por cidade — ideal para mapas e comparativos regionais no Power BI';

-- ─────────────────────────────────────────────────────────────
-- VIEW 3: vw_custo_por_regiao
-- Ranking de custo por cidade/bairro — principal análise BI
-- Power BI: "Quais pontos em X região têm Y lista de custo menor"
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_custo_por_regiao AS
SELECT
    p.id                        AS posto_id,
    p.nome                      AS posto_nome,
    p.tipo::TEXT                AS tipo_energia,
    e.bairro,
    e.cidade,
    e.estado,
    e.latitude,
    e.longitude,
    t.tipo_conector,
    t.potencia_kw,
    t.custo_por_minuto,
    t.custo_por_kwh,
    t.tempo_recarga_estimado_min,
    -- Custo estimado para recarga completa (0→80%)
    ROUND(t.custo_por_minuto * t.tempo_recarga_estimado_min, 2) AS custo_recarga_completa_r$,
    t.status::TEXT              AS status_tomada,
    ROUND(AVG(av.nota), 2)      AS media_nota,
    COUNT(av.id)                AS total_avaliacoes
FROM postos p
JOIN enderecos e        ON p.endereco_id = e.id
JOIN tomadas t          ON t.posto_id = p.id
LEFT JOIN avaliacoes av ON av.posto_id = p.id
WHERE p.ativo = true
GROUP BY p.id, e.id, t.id
ORDER BY t.custo_por_minuto ASC, e.cidade, e.bairro;

COMMENT ON VIEW vw_custo_por_regiao IS
  'Ranking de custo por tomada/região — use no Power BI para filtrar "custo menor por X região"';

-- ─────────────────────────────────────────────────────────────
-- VIEW 4: vw_conectores_distribuicao
-- Distribuição de tipos de conector no parque instalado
-- Power BI: Gráfico de rosca / treemap
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_conectores_distribuicao AS
SELECT
    t.tipo_conector,
    COUNT(DISTINCT t.id)          AS total_tomadas,
    COUNT(DISTINCT p.id)          AS postos_com_conector,
    SUM(t.quantidade)             AS unidades_instaladas,
    ROUND(AVG(t.potencia_kw), 2)  AS potencia_media_kw,
    MAX(t.potencia_kw)            AS potencia_max_kw,
    ROUND(AVG(t.custo_por_minuto), 4) AS custo_medio_min,
    STRING_AGG(DISTINCT e.cidade, ', ') AS cidades
FROM tomadas t
JOIN postos p   ON p.id = t.posto_id
JOIN enderecos e ON e.id = p.endereco_id
WHERE p.ativo = true
GROUP BY t.tipo_conector
ORDER BY total_tomadas DESC;

COMMENT ON VIEW vw_conectores_distribuicao IS
  'Distribuição de tipos de conector — use no Power BI para rosca/treemap de compatibilidade';

-- ─────────────────────────────────────────────────────────────
-- VIEW 5: vw_veiculos_compatibilidade
-- Cruzamento veículos ↔ postos disponíveis por cidade
-- Power BI: "Para meu carro X, quais postos têm tomada compatível?"
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_veiculos_compatibilidade AS
SELECT
    v.marca,
    v.modelo,
    v.ano_lancamento,
    v.tipo_fonte::TEXT        AS tipo_veiculo,
    v.capacidade_bateria_kwh,
    v.autonomia_km,
    v.preco_estimado,
    v.conectores_compativeis,
    -- Para cada cidade: quantos postos têm pelo menos 1 tomada compatível
    e.cidade,
    COUNT(DISTINCT p.id)      AS postos_compativeis,
    COUNT(DISTINCT t.id)      AS tomadas_compativeis,
    ROUND(AVG(t.custo_por_minuto), 4) AS custo_medio_min,
    -- Estimativa de custo de recarga 0→80%
    ROUND(
        AVG(t.custo_por_minuto) *
        COALESCE(v.tempo_recarga_ac_min, 60)
    , 2)                      AS custo_estimado_recarga_r$
FROM veiculos v
JOIN tomadas t ON (
    v.conectores_compativeis ILIKE '%' || t.tipo_conector || '%'
    OR t.tipo_conector = ANY(STRING_TO_ARRAY(v.conectores_compativeis, ','))
)
JOIN postos p   ON p.id = t.posto_id AND p.ativo = true
JOIN enderecos e ON e.id = p.endereco_id
WHERE v.ativo = true
GROUP BY v.id, e.cidade
ORDER BY v.marca, v.modelo, postos_compativeis DESC;

COMMENT ON VIEW vw_veiculos_compatibilidade IS
  'Compatibilidade veículo ↔ postos por cidade — Power BI: filtrar "meu carro X tem postos em Y cidade"';

-- ─────────────────────────────────────────────────────────────
-- VIEW 6: vw_clima_powerbi
-- Dados climáticos normalizados para análise temporal no Power BI
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_clima_powerbi AS
SELECT
    id,
    cidade,
    estado,
    data_hora,
    DATE(data_hora)              AS data,
    EXTRACT(HOUR FROM data_hora) AS hora,
    EXTRACT(DOW FROM data_hora)  AS dia_semana,   -- 0=Dom, 6=Sáb
    TO_CHAR(data_hora AT TIME ZONE 'America/Sao_Paulo', 'YYYY-MM-DD HH24:MI') AS data_hora_local,
    temperatura_atual,
    temperatura_max,
    temperatura_min,
    sensacao_termica,
    umidade_percent,
    precipitacao_mm,
    velocidade_vento_kmh,
    codigo_clima,
    condicao_climatica,
    -- Previsão expandida para colunas do Power BI (próximos 3 dias)
    (previsao_futura->0->>'data')::DATE         AS prev_dia1_data,
    (previsao_futura->0->>'temp_max')::NUMERIC  AS prev_dia1_temp_max,
    (previsao_futura->0->>'temp_min')::NUMERIC  AS prev_dia1_temp_min,
    (previsao_futura->0->>'precipitacao')::NUMERIC AS prev_dia1_precip,
    (previsao_futura->1->>'data')::DATE         AS prev_dia2_data,
    (previsao_futura->1->>'temp_max')::NUMERIC  AS prev_dia2_temp_max,
    (previsao_futura->1->>'temp_min')::NUMERIC  AS prev_dia2_temp_min,
    (previsao_futura->1->>'precipitacao')::NUMERIC AS prev_dia2_precip,
    (previsao_futura->2->>'data')::DATE         AS prev_dia3_data,
    (previsao_futura->2->>'temp_max')::NUMERIC  AS prev_dia3_temp_max,
    (previsao_futura->2->>'temp_min')::NUMERIC  AS prev_dia3_temp_min,
    (previsao_futura->2->>'precipitacao')::NUMERIC AS prev_dia3_precip,
    fonte_api,
    criado_em
FROM clima_historico
ORDER BY cidade, data_hora DESC;

COMMENT ON VIEW vw_clima_powerbi IS
  'Dados climáticos normalizados com previsão expandida em colunas — otimizado para Power BI DirectQuery';

-- ─────────────────────────────────────────────────────────────
-- VIEW 7: vw_auditoria_resumo
-- Resumo de atividade no sistema para monitoramento
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_auditoria_resumo AS
SELECT
    nome_tabela,
    operacao::TEXT,
    DATE(realizado_em)           AS data,
    COUNT(*)                     AS total_operacoes,
    MIN(realizado_em)            AS primeira_operacao,
    MAX(realizado_em)            AS ultima_operacao
FROM auditoria_log
GROUP BY nome_tabela, operacao, DATE(realizado_em)
ORDER BY data DESC, total_operacoes DESC;

COMMENT ON VIEW vw_auditoria_resumo IS
  'Resumo diário de operações por tabela — use no Power BI para monitorar atividade do sistema';
