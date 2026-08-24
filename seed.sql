-- ============================================================
-- SEED DATA - SustAmbiTech BI
-- Dados de exemplo realistas para demonstração no Power BI
-- ============================================================

-- DIMENSÃO: REGIÕES
INSERT OR IGNORE INTO dim_regioes (nome, estado, regiao_brasil, latitude, longitude, populacao, area_km2) VALUES
('São Paulo', 'SP', 'Sudeste', -23.5505, -46.6333, 12325232, 1521.11),
('Rio de Janeiro', 'RJ', 'Sudeste', -22.9068, -43.1729, 6747815, 1200.27),
('Curitiba', 'PR', 'Sul', -25.4290, -49.2671, 1963726, 435.07),
('Porto Alegre', 'RS', 'Sul', -30.0346, -51.2177, 1488252, 496.68),
('Belo Horizonte', 'MG', 'Sudeste', -19.9167, -43.9345, 2530701, 330.93),
('Salvador', 'BA', 'Nordeste', -12.9714, -38.5014, 2900319, 692.82),
('Fortaleza', 'CE', 'Nordeste', -3.7172, -38.5433, 2703391, 312.38),
('Recife', 'PE', 'Nordeste', -8.0578, -34.8829, 1661017, 219.43),
('Manaus', 'AM', 'Norte', -3.1190, -60.0217, 2219580, 11401.09),
('Belém', 'PA', 'Norte', -1.4558, -48.4902, 1499641, 1064.92),
('Goiânia', 'GO', 'Centro-Oeste', -16.6864, -49.2643, 1555626, 739.49),
('Brasília', 'DF', 'Centro-Oeste', -15.7801, -47.9292, 3094325, 5779.99),
('Florianópolis', 'SC', 'Sul', -27.5954, -48.5480, 508826, 436.52),
('Vitória', 'ES', 'Sudeste', -20.3155, -40.3128, 365855, 98.19),
('Campo Grande', 'MS', 'Centro-Oeste', -20.4697, -54.6201, 906092, 8092.95);

-- DIMENSÃO: CATEGORIAS
INSERT OR IGNORE INTO dim_categorias (nome, descricao, icone, cor_hex, ods_relacionado) VALUES
('Qualidade do Ar', 'Monitoramento e análise da qualidade do ar urbano e rural', 'wind', '#4CAF50', 'ODS 3, ODS 11, ODS 13'),
('Qualidade da Água', 'Análise de corpos hídricos e qualidade da água potável', 'droplets', '#2196F3', 'ODS 3, ODS 6, ODS 14'),
('Energia Renovável', 'Consumo e geração de energia de fontes renováveis', 'zap', '#FF9800', 'ODS 7, ODS 13'),
('Reciclagem', 'Gestão de resíduos sólidos e economia circular', 'recycle', '#8BC34A', 'ODS 11, ODS 12'),
('Mobilidade Verde', 'Veículos elétricos e transporte sustentável', 'car', '#00BCD4', 'ODS 11, ODS 13'),
('Clima e Temperatura', 'Indicadores climáticos e mudanças climáticas', 'thermometer', '#FF5722', 'ODS 13, ODS 15'),
('Biodiversidade', 'Conservação de espécies e ecossistemas', 'tree', '#388E3C', 'ODS 14, ODS 15'),
('Educação Ambiental', 'Engajamento e conscientização ambiental', 'book-open', '#9C27B0', 'ODS 4, ODS 17'),
('Políticas Públicas', 'Legislação e políticas ambientais', 'landmark', '#607D8B', 'ODS 16, ODS 17'),
('Consumo Consciente', 'Análise de produtos e impacto ecológico', 'shopping-bag', '#795548', 'ODS 12');

-- DIMENSÃO: FONTES DE ENERGIA
INSERT OR IGNORE INTO dim_fontes_energia (nome, tipo, emissao_co2_por_kwh, renovavel, descricao) VALUES
('Solar Fotovoltaica', 'renovavel', 20, 1, 'Geração de energia a partir da luz solar'),
('Eólica', 'renovavel', 11, 1, 'Geração de energia a partir do vento'),
('Hidrelétrica', 'renovavel', 24, 1, 'Geração de energia a partir da água'),
('Biomassa', 'renovavel', 230, 1, 'Geração de energia a partir de matéria orgânica'),
('Gás Natural', 'nao_renovavel', 490, 0, 'Combustão de gás natural'),
('Petróleo/Óleo', 'nao_renovavel', 650, 0, 'Combustão de derivados de petróleo'),
('Carvão Mineral', 'nao_renovavel', 820, 0, 'Combustão de carvão mineral'),
('Nuclear', 'alternativa', 12, 0, 'Fissão nuclear para geração de energia'),
('Maré/Oceano', 'renovavel', 17, 1, 'Energia das marés e ondas do oceano'),
('Geotérmica', 'renovavel', 38, 1, 'Energia do calor interno da terra');

-- DIMENSÃO: TIPOS DE RESÍDUOS
INSERT OR IGNORE INTO dim_tipos_residuos (nome, classificacao, descricao, tempo_decomposicao_anos, periculosidade, cor_padrao_separacao) VALUES
('Papel/Papelão', 'reciclavel', 'Jornais, revistas, embalagens de papel', 1, 'baixa', 'Azul'),
('Plástico', 'reciclavel', 'Garrafas PET, embalagens plásticas, sacolas', 400, 'baixa', 'Vermelho'),
('Vidro', 'reciclavel', 'Garrafas, potes, frascos de vidro', 4000, 'baixa', 'Verde'),
('Metal/Alumínio', 'reciclavel', 'Latas de alumínio, aço, metais em geral', 200, 'baixa', 'Amarelo'),
('Orgânico', 'organico', 'Restos de alimentos, cascas, folhas', 1, 'baixa', 'Marrom'),
('Eletrônico (e-lixo)', 'especial', 'Computadores, celulares, baterias', 1000, 'alta', 'Laranja'),
('Pilhas e Baterias', 'perigoso', 'Pilhas comuns, baterias de celular e carro', 500, 'muito_alta', 'Preto'),
('Óleo de Cozinha', 'especial', 'Óleo vegetal usado', 1000, 'media', 'Laranja'),
('Medicamentos', 'perigoso', 'Remédios vencidos ou em excesso', 100, 'alta', 'Preto'),
('Rejeito', 'rejeito', 'Resíduos não recicláveis e não aproveitáveis', 100, 'baixa', 'Cinza');

-- DIMENSÃO: USUÁRIOS (exemplos)
INSERT OR IGNORE INTO dim_usuarios (nome, email, tipo_usuario, cidade, estado, regiao_id, pontos_sustentabilidade, nivel_engajamento) VALUES
('João Silva', 'joao.silva@email.com', 'cidadao', 'São Paulo', 'SP', 1, 1250, 'intermediario'),
('Maria Santos', 'maria.santos@email.com', 'cidadao', 'Rio de Janeiro', 'RJ', 2, 3400, 'avancado'),
('EcoEmpresa SP Ltda', 'contato@ecoempresa.com.br', 'empresa', 'São Paulo', 'SP', 1, 8900, 'especialista'),
('IBAMA Regional', 'ibama.sp@gov.br', 'orgao_publico', 'Brasília', 'DF', 12, 5000, 'especialista'),
('Dr. Carlos Verde', 'carlos.verde@usp.br', 'pesquisador', 'São Paulo', 'SP', 1, 6200, 'especialista'),
('ONG AmazôniaViva', 'contato@amazoniaviva.org', 'ong', 'Manaus', 'AM', 9, 4100, 'avancado'),
('Ana Pereira', 'ana.pereira@email.com', 'cidadao', 'Curitiba', 'PR', 3, 890, 'intermediario'),
('Tech Verde SA', 'bi@techverde.com.br', 'empresa', 'Belo Horizonte', 'MG', 5, 7600, 'especialista'),
('Pedro Costa', 'pedro.costa@email.com', 'cidadao', 'Salvador', 'BA', 6, 340, 'iniciante'),
('Instituto Clima BR', 'dados@climabr.org', 'ong', 'Brasília', 'DF', 12, 9100, 'especialista');

-- FATO: QUALIDADE DO AR (dados últimos 6 meses)
INSERT OR IGNORE INTO fato_qualidade_ar (regiao_id, data_medicao, pm25, pm10, co2_ppm, o3_ppb, no2_ppb, so2_ppb, indice_qualidade_ar, classificacao_ar, temperatura_celsius, umidade_relativa, velocidade_vento_kmh) VALUES
(1, '2025-02-15 08:00:00', 18.5, 32.1, 415, 42, 38, 8, 65, 'moderada', 22.3, 68, 12),
(1, '2025-03-15 08:00:00', 22.1, 38.4, 418, 48, 42, 12, 78, 'moderada', 24.1, 65, 8),
(1, '2025-04-15 08:00:00', 15.3, 28.7, 412, 35, 29, 6, 52, 'boa', 20.8, 72, 15),
(1, '2025-05-15 08:00:00', 12.1, 22.3, 410, 28, 25, 4, 44, 'boa', 18.5, 75, 18),
(1, '2025-06-15 08:00:00', 9.8, 18.5, 408, 22, 19, 3, 38, 'boa', 16.2, 80, 22),
(1, '2025-07-15 08:00:00', 11.2, 20.8, 411, 25, 22, 5, 41, 'boa', 17.4, 78, 20),
(2, '2025-02-15 08:00:00', 25.3, 45.2, 420, 52, 48, 15, 88, 'inadequada', 28.5, 75, 10),
(2, '2025-03-15 08:00:00', 28.7, 51.3, 422, 58, 55, 18, 95, 'inadequada', 29.2, 78, 8),
(2, '2025-04-15 08:00:00', 20.1, 38.2, 416, 44, 39, 11, 72, 'moderada', 26.8, 72, 12),
(2, '2025-05-15 08:00:00', 16.5, 30.1, 413, 35, 30, 8, 58, 'moderada', 24.5, 70, 15),
(3, '2025-02-15 08:00:00', 8.2, 15.3, 405, 18, 15, 2, 32, 'boa', 19.8, 82, 25),
(3, '2025-03-15 08:00:00', 7.5, 14.1, 403, 16, 13, 2, 28, 'boa', 18.2, 85, 28),
(3, '2025-04-15 08:00:00', 6.8, 12.5, 401, 14, 11, 1, 25, 'boa', 16.5, 88, 30),
(9, '2025-02-15 08:00:00', 5.1, 10.2, 398, 12, 8, 1, 20, 'boa', 32.5, 88, 5),
(9, '2025-05-15 08:00:00', 8.8, 18.5, 410, 22, 18, 3, 38, 'boa', 30.2, 85, 6),
(6, '2025-02-15 08:00:00', 19.2, 35.8, 416, 45, 40, 10, 70, 'moderada', 27.8, 80, 8),
(6, '2025-06-15 08:00:00', 28.5, 52.1, 425, 60, 55, 20, 98, 'inadequada', 25.1, 82, 5);

-- FATO: QUALIDADE DA ÁGUA
INSERT OR IGNORE INTO fato_qualidade_agua (regiao_id, tipo_corpo_hidrico, data_medicao, ph, turbidez_ntu, oxigenio_dissolvido_mgl, dbo_mgl, coliformes_totais, nitratos_mgl, fosfatos_mgl, temperatura_celsius, indice_qualidade_agua, classificacao_agua, adequada_consumo) VALUES
(1, 'reservatorio', '2025-02-01', 7.2, 2.5, 7.8, 1.2, 120, 0.8, 0.05, 20.5, 82, 'boa', 1),
(1, 'rio', '2025-02-01', 6.8, 15.2, 5.2, 4.8, 2400, 2.5, 0.35, 22.1, 45, 'razoavel', 0),
(2, 'reservatorio', '2025-02-01', 7.0, 3.1, 7.5, 1.8, 180, 1.0, 0.08, 24.8, 78, 'boa', 1),
(2, 'mar', '2025-02-01', 8.1, 1.2, 8.5, 0.5, 50, 0.2, 0.02, 26.5, 91, 'otima', 0),
(3, 'rio', '2025-02-01', 7.4, 4.2, 8.2, 0.8, 95, 0.5, 0.03, 16.8, 88, 'boa', 1),
(9, 'rio', '2025-02-01', 7.6, 8.5, 7.8, 1.5, 85, 0.4, 0.04, 28.5, 85, 'boa', 1),
(9, 'rio', '2025-05-01', 7.3, 12.8, 7.2, 2.1, 150, 0.8, 0.12, 27.8, 72, 'boa', 1),
(6, 'reservatorio', '2025-02-01', 7.1, 5.8, 7.0, 2.5, 350, 1.5, 0.18, 28.2, 65, 'razoavel', 0),
(12, 'reservatorio', '2025-02-01', 7.3, 3.5, 7.6, 1.3, 110, 0.6, 0.04, 25.5, 82, 'boa', 1),
(1, 'reservatorio', '2025-07-01', 7.4, 2.1, 8.1, 1.0, 95, 0.7, 0.04, 19.8, 85, 'boa', 1);

-- FATO: CONSUMO DE ENERGIA (por mês/região)
INSERT OR IGNORE INTO fato_consumo_energia (regiao_id, fonte_energia_id, data_referencia, consumo_kwh, custo_real, emissao_co2_kg, setor, reducao_vs_mes_anterior_pct, atingiu_meta) VALUES
(1, 3, '2025-01-01', 4250000, 2210000, 102000, 'residencial', -2.5, 0),
(1, 1, '2025-01-01', 850000, 340000, 17000, 'residencial', 5.2, 1),
(1, 3, '2025-02-01', 4180000, 2173600, 100320, 'residencial', -1.6, 0),
(1, 1, '2025-02-01', 920000, 368000, 18400, 'residencial', 8.2, 1),
(1, 3, '2025-03-01', 4050000, 2106000, 97200, 'residencial', -3.1, 1),
(1, 1, '2025-03-01', 1100000, 440000, 22000, 'residencial', 19.6, 1),
(1, 5, '2025-01-01', 1850000, 925000, 906500, 'industrial', -1.0, 0),
(1, 1, '2025-01-01', 650000, 260000, 13000, 'industrial', 12.5, 1),
(2, 3, '2025-01-01', 3820000, 1986400, 91680, 'residencial', -1.8, 0),
(2, 3, '2025-02-01', 3750000, 1950000, 90000, 'residencial', -1.8, 0),
(2, 3, '2025-03-01', 3620000, 1882400, 86880, 'residencial', -3.5, 1),
(3, 3, '2025-01-01', 1920000, 998400, 46080, 'residencial', 0.5, 0),
(3, 1, '2025-01-01', 580000, 232000, 11600, 'residencial', 15.0, 1),
(3, 2, '2025-01-01', 420000, 168000, 4620, 'residencial', 8.0, 1),
(4, 3, '2025-01-01', 1580000, 821600, 37920, 'residencial', -0.8, 0),
(4, 1, '2025-01-01', 620000, 248000, 12400, 'residencial', 18.5, 1),
(9, 3, '2025-01-01', 2150000, 1118000, 51600, 'residencial', 2.5, 0),
(12, 3, '2025-01-01', 2680000, 1393600, 64320, 'residencial', -0.5, 0),
(12, 1, '2025-01-01', 1250000, 500000, 25000, 'residencial', 22.0, 1),
(1, 3, '2025-04-01', 3980000, 2069600, 95520, 'residencial', -1.7, 0),
(1, 3, '2025-05-01', 3850000, 2002000, 92400, 'residencial', -3.3, 1),
(1, 3, '2025-06-01', 3720000, 1934400, 89280, 'residencial', -3.4, 1),
(1, 3, '2025-07-01', 3650000, 1898000, 87600, 'residencial', -1.9, 0);

-- FATO: RECICLAGEM
INSERT OR IGNORE INTO fato_reciclagem (regiao_id, usuario_id, tipo_residuo_id, data_coleta, quantidade_kg, destinacao, ponto_coleta, cooperativa, valor_arrecadado, co2_evitado_kg) VALUES
(1, 1, 2, '2025-01-15', 25.5, 'reciclagem', 'Ecoponto Centro SP', 'CoopRecicla SP', 38.25, 51.0),
(1, 3, 2, '2025-01-20', 180.0, 'reciclagem', 'Galpão Ecoempresa', 'Recicla+', 270.0, 360.0),
(1, 1, 1, '2025-02-10', 15.2, 'reciclagem', 'Ecoponto Centro SP', 'CoopRecicla SP', 12.16, 22.8),
(1, 2, 4, '2025-02-18', 12.8, 'reciclagem', 'Ecoponto Vila Madalena', 'AluBrasil', 57.6, 25.6),
(2, 2, 3, '2025-01-25', 45.0, 'reciclagem', 'Ecoponto Tijuca', 'VidreCoop RJ', 22.5, 9.0),
(3, 7, 5, '2025-01-08', 35.8, 'compostagem', 'Horta Comunitária Bacacheri', 'CompostaCuritiba', 0, 21.48),
(3, 7, 1, '2025-02-05', 22.5, 'reciclagem', 'Ecoponto Batel', 'PapelVerde PR', 18.0, 33.75),
(9, 6, 2, '2025-01-30', 520.0, 'reciclagem', 'Cooperativa Amazônia', 'ReciclaAmazonia', 780.0, 1040.0),
(1, 1, 8, '2025-02-20', 5.0, 'reuso', 'Posto Coleta Óleo SP', 'BioÓleo SP', 15.0, 45.0),
(1, 3, 6, '2025-03-10', 850.0, 'reciclagem', 'Galpão Ecoempresa', 'E-lixo SP', 4250.0, 1700.0),
(1, 1, 2, '2025-03-15', 28.2, 'reciclagem', 'Ecoponto Centro SP', 'CoopRecicla SP', 42.3, 56.4),
(2, 2, 2, '2025-03-20', 35.5, 'reciclagem', 'Ecoponto Ipanema', 'Recicla RJ', 53.25, 71.0),
(4, NULL, 1, '2025-01-12', 180.0, 'reciclagem', 'Ecoponto Farroupilha', 'PapelGaúcho', 144.0, 270.0),
(5, NULL, 4, '2025-01-18', 95.0, 'reciclagem', 'Ecoponto Savassi', 'AlumínioMG', 427.5, 190.0),
(6, 9, 5, '2025-02-25', 42.5, 'compostagem', 'Horta Urbana Salvador', 'CompostaBahia', 0, 25.5),
(1, 5, 2, '2025-04-15', 15.8, 'reciclagem', 'Ecoponto USP', 'ReciclaUSP', 23.7, 31.6),
(1, 1, 2, '2025-05-12', 30.1, 'reciclagem', 'Ecoponto Centro SP', 'CoopRecicla SP', 45.15, 60.2),
(1, 1, 1, '2025-06-08', 18.5, 'reciclagem', 'Ecoponto Centro SP', 'CoopRecicla SP', 14.8, 27.75),
(3, 7, 5, '2025-07-10', 40.2, 'compostagem', 'Horta Comunitária Bacacheri', 'CompostaCuritiba', 0, 24.12);

-- FATO: VEÍCULOS ELÉTRICOS
INSERT OR IGNORE INTO fato_veiculos_eletricos (regiao_id, data_referencia, total_veiculos_eletricos, total_hibridos, total_combustao, novos_emplacamentos_eletricos, eletropostos_ativos, km_rodados_eletricos, co2_evitado_kg, economia_combustivel_litros, modelo_mais_vendido) VALUES
(1, '2020-12-31', 8500, 45200, 8200000, 2100, 180, 85000000, 17000000, 8500000, 'BYD Dolphin'),
(1, '2021-12-31', 14200, 58900, 8350000, 5700, 310, 142000000, 28400000, 14200000, 'BYD Dolphin'),
(1, '2022-12-31', 28900, 78500, 8420000, 14700, 580, 289000000, 57800000, 28900000, 'BYD Dolphin'),
(1, '2023-12-31', 52100, 102300, 8480000, 23200, 890, 521000000, 104200000, 52100000, 'BYD Dolphin'),
(1, '2024-12-31', 89500, 138900, 8520000, 37400, 1450, 895000000, 179000000, 89500000, 'BYD Dolphin'),
(2, '2020-12-31', 3200, 18500, 3850000, 800, 85, 32000000, 6400000, 3200000, 'BYD Dolphin'),
(2, '2021-12-31', 5800, 24200, 3920000, 2600, 150, 58000000, 11600000, 5800000, 'Nissan Leaf'),
(2, '2022-12-31', 11500, 33800, 3980000, 5700, 280, 115000000, 23000000, 11500000, 'BYD Dolphin'),
(2, '2023-12-31', 21800, 45600, 4020000, 10300, 420, 218000000, 43600000, 21800000, 'BYD Dolphin'),
(2, '2024-12-31', 38500, 62100, 4050000, 16700, 680, 385000000, 77000000, 38500000, 'BYD Dolphin'),
(3, '2020-12-31', 2100, 12800, 1420000, 520, 65, 21000000, 4200000, 2100000, 'Volvo XC40'),
(3, '2022-12-31', 7800, 22500, 1480000, 3800, 195, 78000000, 15600000, 7800000, 'BYD Dolphin'),
(3, '2024-12-31', 25200, 42800, 1530000, 11200, 380, 252000000, 50400000, 25200000, 'BYD Dolphin'),
(9, '2022-12-31', 1850, 8200, 920000, 850, 45, 18500000, 3700000, 1850000, 'BYD Dolphin'),
(9, '2024-12-31', 5800, 15200, 950000, 2200, 120, 58000000, 11600000, 5800000, 'BYD Yuan Plus'),
(12, '2022-12-31', 4200, 18500, 1850000, 1800, 95, 42000000, 8400000, 4200000, 'BYD Dolphin'),
(12, '2024-12-31', 12500, 28900, 1920000, 4800, 215, 125000000, 25000000, 12500000, 'BYD Song Plus');

-- FATO: INDICADORES CLIMÁTICOS
INSERT OR IGNORE INTO fato_indicadores_climaticos (regiao_id, data_referencia, temperatura_media, temperatura_max, temperatura_min, precipitacao_mm, eventos_extremos, nivel_reservatorio_pct, anomalia_termica) VALUES
(1, '2025-01-01', 25.8, 31.5, 20.2, 185.5, 2, 72.5, 1.5),
(1, '2025-02-01', 26.2, 32.8, 21.5, 210.8, 3, 75.2, 1.8),
(1, '2025-03-01', 24.5, 30.2, 19.8, 150.2, 1, 71.8, 1.2),
(1, '2025-04-01', 22.1, 27.5, 17.5, 80.5, 0, 68.5, 0.9),
(1, '2025-05-01', 19.8, 24.8, 15.2, 55.2, 0, 65.2, 0.7),
(1, '2025-06-01', 17.5, 22.5, 13.2, 45.8, 0, 62.8, 0.5),
(1, '2025-07-01', 18.2, 23.2, 14.5, 38.5, 0, 60.5, 0.4),
(2, '2025-01-01', 29.5, 35.8, 24.2, 120.5, 1, 55.8, 2.1),
(2, '2025-02-01', 30.2, 36.5, 25.8, 145.2, 2, 58.2, 2.5),
(2, '2025-03-01', 28.8, 34.5, 23.5, 100.8, 1, 52.5, 1.9),
(3, '2025-01-01', 22.5, 28.5, 17.8, 95.2, 0, 80.5, 0.8),
(3, '2025-02-01', 23.2, 29.2, 18.5, 112.5, 1, 82.8, 0.9),
(9, '2025-01-01', 31.5, 35.8, 27.2, 285.5, 0, 85.2, 1.2),
(9, '2025-02-01', 32.2, 36.5, 28.5, 312.8, 1, 88.5, 1.4),
(9, '2025-06-01', 29.8, 34.2, 25.5, 68.5, 0, 72.5, 0.8),
(6, '2025-01-01', 28.2, 33.5, 23.8, 105.2, 1, 48.5, 1.8),
(6, '2025-07-01', 24.5, 29.8, 20.2, 55.8, 0, 42.5, 1.1);

-- FATO: COBERTURA VEGETAL
INSERT OR IGNORE INTO fato_cobertura_vegetal (regiao_id, data_referencia, area_total_ha, area_vegetacao_nativa_ha, area_desmatada_ha, area_reflorestada_ha, area_degradada_ha, taxa_desmatamento_anual_pct, taxa_recuperacao_pct, carbono_estocado_ton, indice_vegetacao, bioma) VALUES
(9, '2023-12-31', 1140109, 892000, 248109, 12500, 85000, 1.2, 0.4, 3568000, 0.72, 'Amazônia'),
(9, '2024-12-31', 1140109, 879000, 261109, 15200, 82000, 1.5, 0.5, 3516000, 0.70, 'Amazônia'),
(10, '2023-12-31', 1064921, 758000, 306921, 8500, 125000, 2.1, 0.3, 3032000, 0.65, 'Amazônia'),
(10, '2024-12-31', 1064921, 742000, 322921, 10200, 118000, 2.1, 0.4, 2968000, 0.63, 'Amazônia'),
(1, '2023-12-31', 152111, 18500, 133611, 2800, 45000, 0.5, 1.2, 74000, 0.28, 'Mata Atlântica'),
(1, '2024-12-31', 152111, 19200, 132911, 3200, 43000, -0.5, 1.5, 76800, 0.29, 'Mata Atlântica'),
(3, '2023-12-31', 43507, 12800, 30707, 850, 8500, 0.3, 2.1, 51200, 0.45, 'Mata Atlântica'),
(3, '2024-12-31', 43507, 13250, 30257, 980, 8200, -0.4, 2.3, 53000, 0.46, 'Mata Atlântica'),
(12, '2023-12-31', 577991, 128500, 449491, 5200, 185000, 1.8, 0.8, 514000, 0.35, 'Cerrado'),
(12, '2024-12-31', 577991, 125200, 452791, 6800, 188000, 2.6, 0.7, 500800, 0.34, 'Cerrado'),
(11, '2024-12-31', 739491, 245800, 493691, 8500, 180000, 1.5, 0.9, 983200, 0.40, 'Cerrado');

-- FATO: EDUCAÇÃO AMBIENTAL
INSERT OR IGNORE INTO fato_educacao_ambiental (usuario_id, regiao_id, data_atividade, tipo_atividade, titulo_atividade, pontuacao, duracao_minutos, categoria_id, concluido, certificado_emitido, nivel_dificuldade) VALUES
(1, 1, '2025-01-10', 'quiz', 'Quiz: Reciclagem Básica', 85, 15, 4, 1, 0, 'basico'),
(1, 1, '2025-01-18', 'video', 'Como economizar energia em casa', 50, 12, 3, 1, 0, 'basico'),
(2, 2, '2025-01-08', 'workshop', 'Workshop: Horta Orgânica Urbana', 120, 180, 4, 1, 1, 'intermediario'),
(2, 2, '2025-01-22', 'quiz', 'Quiz: Biodiversidade Brasileira', 95, 20, 7, 1, 0, 'avancado'),
(3, 1, '2025-01-05', 'treinamento', 'ISO 14001: Gestão Ambiental Empresarial', 200, 480, 9, 1, 1, 'avancado'),
(5, 1, '2025-01-15', 'palestra', 'Mudanças Climáticas e o Brasil', 80, 90, 6, 1, 0, 'intermediario'),
(6, 9, '2025-01-12', 'campanha', 'Campanha Salve a Amazônia', 150, 240, 7, 1, 1, 'intermediario'),
(7, 3, '2025-01-20', 'video', 'Mobilidade Urbana Sustentável', 50, 15, 5, 1, 0, 'basico'),
(7, 3, '2025-01-25', 'quiz', 'Quiz: Veículos Elétricos', 78, 18, 5, 1, 0, 'basico'),
(9, 6, '2025-01-30', 'workshop', 'Compostagem Doméstica', 100, 120, 4, 1, 1, 'basico'),
(1, 1, '2025-02-05', 'quiz', 'Qualidade do Ar e Saúde', 90, 20, 1, 1, 0, 'intermediario'),
(2, 2, '2025-02-12', 'artigo', 'Políticas Ambientais no Brasil', 40, 30, 9, 1, 0, 'avancado'),
(4, 12, '2025-02-08', 'treinamento', 'Legislação Ambiental Brasileira', 180, 360, 9, 1, 1, 'avancado'),
(8, 5, '2025-02-15', 'campanha', 'Semana do Meio Ambiente', 120, 300, 8, 1, 1, 'intermediario'),
(1, 1, '2025-03-10', 'quiz', 'Quiz: Consumo Consciente', 82, 15, 10, 1, 0, 'basico'),
(2, 2, '2025-03-18', 'workshop', 'Energias Renováveis na Prática', 150, 240, 3, 1, 1, 'intermediario'),
(7, 3, '2025-04-05', 'video', 'Sustentabilidade na Culinária', 50, 10, 10, 1, 0, 'basico'),
(1, 1, '2025-05-22', 'quiz', 'Ecoposto: Guia Prático', 88, 20, 5, 1, 0, 'basico'),
(9, 6, '2025-06-15', 'campanha', 'Dia do Meio Ambiente - Salvador', 130, 240, 8, 1, 1, 'intermediario'),
(3, 1, '2025-07-01', 'treinamento', 'ESG para Empresas', 220, 480, 9, 1, 1, 'avancado');

-- FATO: DENÚNCIAS AMBIENTAIS
INSERT OR IGNORE INTO fato_denuncias (usuario_id, regiao_id, data_denuncia, tipo_denuncia, descricao, latitude, longitude, status, orgao_responsavel, impacto_estimado) VALUES
(1, 1, '2025-01-08', 'descarte_ilegal', 'Descarte irregular de resíduos eletrônicos na Av. Paulista', -23.5613, -46.6580, 'resolvido', 'SVMA - SP', 'medio'),
(2, 2, '2025-01-12', 'poluicao_agua', 'Lançamento de efluentes no Rio Guandu', -22.8456, -43.4581, 'em_analise', 'INEA - RJ', 'alto'),
(6, 9, '2025-01-20', 'desmatamento', 'Desmatamento ilegal em área de preservação no AM-010', -3.4281, -60.3481, 'em_analise', 'IBAMA', 'critico'),
(7, 3, '2025-02-05', 'descarte_ilegal', 'Óleo industrial despejado em bocas de lobo', -25.4521, -49.2812, 'resolvido', 'SMMA - Curitiba', 'alto'),
(9, 6, '2025-02-18', 'poluicao_ar', 'Fábrica emitindo fumaça preta sem tratamento', -12.9812, -38.4921, 'pendente', 'INEMA - BA', 'medio'),
(1, 1, '2025-03-01', 'queimada', 'Queimada em área verde no Parque do Estado', -23.6421, -46.6234, 'resolvido', 'Corpo de Bombeiros SP', 'alto'),
(5, 12, '2025-03-10', 'poluicao_agua', 'Contaminação por agrotóxicos no Córrego Samambaia', -15.8234, -47.8921, 'em_analise', 'ANA / IBAMA', 'alto'),
(2, 2, '2025-04-15', 'descarte_ilegal', 'Descarte de resíduos da construção em área pública', -22.9234, -43.2341, 'resolvido', 'SECONSERVA - RJ', 'baixo'),
(7, 3, '2025-04-22', 'poluicao_ar', 'Queima de lixo residencial em área urbana', -25.4812, -49.2234, 'pendente', 'SMMA - Curitiba', 'medio'),
(10, 10, '2025-05-08', 'desmatamento', 'Corte de árvores nativas em margem de rio', -1.5234, -48.5012, 'em_analise', 'SEMAS - PA', 'critico'),
(1, 1, '2025-05-20', 'caca_pesca_ilegal', 'Pesca predatória no Guarapiranga com redes ilegais', -23.7234, -46.7128, 'pendente', 'SVMA - SP', 'medio'),
(4, 12, '2025-06-02', 'desmatamento', 'Supressão vegetal sem autorização em fazenda no DF', -15.9234, -47.9128, 'resolvido', 'IBRAM - DF', 'alto'),
(6, 9, '2025-06-15', 'queimada', 'Incêndio florestal próximo à BR-319', -3.8234, -60.5128, 'em_analise', 'INPA / IBAMA', 'critico'),
(9, 6, '2025-07-01', 'descarte_ilegal', 'Despejo de esgoto no Rio Paraguaçu', -12.7234, -38.9128, 'pendente', 'INEMA - BA', 'alto');

-- FATO: ECOPONTOS
INSERT OR IGNORE INTO fato_ecopontos (nome, regiao_id, latitude, longitude, endereco, bairro, cidade, estado, tipos_residuos_aceitos, capacidade_toneladas_mes, volume_coletado_mes_kg, horario_funcionamento, responsavel, avaliacao_media, total_avaliacoes) VALUES
('Ecoponto Centro SP', 1, -23.5489, -46.6388, 'Rua da Consolação, 500', 'Centro', 'São Paulo', 'SP', '["papel","plastico","vidro","metal","organico"]', 50, 42500, 'Seg-Sex 8h-18h / Sab 8h-14h', 'Ecourbis', 4.5, 234),
('Ecoponto Vila Madalena', 1, -23.5604, -46.6912, 'Rua Fradique Coutinho, 1200', 'Vila Madalena', 'São Paulo', 'SP', '["papel","plastico","vidro","metal","eletronico"]', 35, 28500, 'Seg-Sex 7h-19h / Sab 8h-16h', 'Ecourbis', 4.7, 189),
('Ecoponto Tijuca', 2, -22.9248, -43.2291, 'Rua São Francisco Xavier, 524', 'Tijuca', 'Rio de Janeiro', 'RJ', '["papel","plastico","vidro","metal"]', 40, 32000, 'Seg-Sex 8h-17h', 'Comlurb', 4.2, 156),
('Ecoponto Ipanema', 2, -22.9839, -43.2096, 'Av. Vieira Souto, 90', 'Ipanema', 'Rio de Janeiro', 'RJ', '["papel","plastico","vidro","metal","organico"]', 30, 25500, 'Seg-Dom 7h-20h', 'Comlurb', 4.8, 312),
('Ecoponto Batel', 3, -25.4428, -49.2912, 'Rua Comendador Araújo, 300', 'Batel', 'Curitiba', 'PR', '["papel","plastico","vidro","metal","organico","eletronico"]', 45, 38500, 'Seg-Sex 8h-18h / Sab 8h-14h', 'Prefeitura Curitiba', 4.9, 421),
('Ecoponto Bacacheri', 3, -25.3912, -49.2348, 'Rua José Cadilhe, 200', 'Bacacheri', 'Curitiba', 'PR', '["papel","plastico","vidro","metal","organico"]', 30, 24500, 'Seg-Sex 7h-17h / Sab 7h-13h', 'Prefeitura Curitiba', 4.6, 178),
('Ecoponto Farroupilha', 4, -30.0289, -51.2134, 'Av. Farroupilha, 8001', 'Partenon', 'Porto Alegre', 'RS', '["papel","plastico","vidro","metal"]', 38, 31000, 'Seg-Sex 8h-18h', 'DMLU', 4.3, 145),
('Ecoponto Savassi', 5, -19.9428, -43.9301, 'Rua Fernandes Tourinho, 300', 'Savassi', 'Belo Horizonte', 'MG', '["papel","plastico","vidro","metal","eletronico"]', 42, 35500, 'Seg-Sex 8h-18h / Sab 8h-14h', 'SLU-BH', 4.4, 198),
('Ecoponto Comércio', 6, -12.9742, -38.5234, 'Av. da França, 567', 'Comércio', 'Salvador', 'BA', '["papel","plastico","vidro","metal"]', 28, 22000, 'Seg-Sex 8h-17h', 'Limpurb', 3.9, 89),
('Cooperativa Amazônia Verde', 9, -3.1234, -60.0348, 'Av. Djalma Batista, 1512', 'Chapada', 'Manaus', 'AM', '["papel","plastico","vidro","metal","organico","oleo"]', 60, 52000, 'Seg-Sex 7h-17h / Sab 7h-12h', 'SEMEF Manaus', 4.1, 67),
('Ecoponto Asa Norte', 12, -15.7712, -47.8823, 'SGON Quadra 5', 'Asa Norte', 'Brasília', 'DF', '["papel","plastico","vidro","metal","eletronico","pilha"]', 55, 47500, 'Seg-Sex 8h-18h / Sab 8h-14h', 'SLU-DF', 4.6, 267),
('Ecoponto Trindade', 13, -27.5991, -48.5412, 'Rua Lauro Linhares, 800', 'Trindade', 'Florianópolis', 'SC', '["papel","plastico","vidro","metal","organico"]', 25, 19500, 'Seg-Sex 8h-17h', 'COMCAP', 4.5, 134);

-- KPIs E METAS
INSERT OR IGNORE INTO tb_kpis_metas (categoria_id, nome_kpi, descricao, unidade_medida, valor_meta, valor_atual, ano_referencia, mes_referencia, prazo_meta, status_meta, percentual_atingimento, ods_relacionado) VALUES
(4, 'Taxa de Reciclagem Municipal', 'Percentual de resíduos reciclados em relação ao total coletado', '%', 40, 28.5, 2025, NULL, '2025-12-31', 'em_andamento', 71.25, 'ODS 11, ODS 12'),
(3, 'Penetração Solar Residencial', 'Percentual de residências com painéis solares instalados', '%', 15, 8.2, 2025, NULL, '2025-12-31', 'em_andamento', 54.67, 'ODS 7, ODS 13'),
(5, 'Frota Elétrica Municipal', 'Percentual de veículos elétricos na frota total', '%', 5, 2.8, 2025, NULL, '2025-12-31', 'em_andamento', 56.0, 'ODS 11, ODS 13'),
(1, 'Dias com Ar Boa Qualidade', 'Número de dias por ano com IQA classificado como "Boa"', 'dias', 250, 198, 2025, NULL, '2025-12-31', 'em_andamento', 79.2, 'ODS 3, ODS 11'),
(2, 'Cobertura Água Potável', 'Percentual da população com acesso à água potável tratada', '%', 95, 89.5, 2025, NULL, '2025-12-31', 'em_andamento', 94.21, 'ODS 6'),
(7, 'Área Protegida Ampliada', 'Hectares de novas áreas de preservação criadas', 'ha', 50000, 18500, 2025, NULL, '2025-12-31', 'em_andamento', 37.0, 'ODS 15'),
(8, 'Usuários Educação Ambiental', 'Total de usuários participando de atividades de educação ambiental', 'usuários', 10000, 6842, 2025, NULL, '2025-12-31', 'em_andamento', 68.42, 'ODS 4, ODS 17'),
(9, 'Denúncias Resolvidas', 'Percentual de denúncias ambientais resolvidas dentro do prazo', '%', 80, 65.2, 2025, NULL, '2025-12-31', 'em_andamento', 81.5, 'ODS 16'),
(6, 'Redução Emissões CO2', 'Toneladas de CO2 evitadas pelas ações do projeto', 'ton CO2', 500000, 312580, 2025, NULL, '2025-12-31', 'em_andamento', 62.52, 'ODS 13'),
(3, 'Redução Consumo Energético', 'Percentual de redução no consumo de energia vs. ano anterior', '%', 10, 6.8, 2025, NULL, '2025-12-31', 'em_andamento', 68.0, 'ODS 7, ODS 13');

-- ALERTAS
INSERT OR IGNORE INTO tb_alertas (tipo_alerta, titulo, descricao, regiao_id, severidade, ativo, resolvido) VALUES
('qualidade_ar', 'PM2.5 Elevado em São Paulo', 'Concentração de partículas finas acima do limite recomendado pela OMS na RMSP', 1, 'aviso', 1, 0),
('qualidade_agua', 'Contaminação Detentada no Rio Guandu', 'Análise laboratorial detectou coliformes fecais acima do limite em ponto de captação', 2, 'critico', 1, 0),
('desmatamento', 'Alerta DETER: Desmatamento no Amazonas', 'Sistema DETER detectou anomalias de cobertura vegetal na região do AM-010', 9, 'critico', 1, 0),
('meta_atingida', 'Meta de Reciclagem Superada em Curitiba', 'Curitiba atingiu 45% de taxa de reciclagem, superando a meta de 40%!', 3, 'informativo', 1, 0),
('evento_climatico', 'Previsão de Chuvas Intensas no Sudeste', 'INMET prevê chuvas acima da média para São Paulo, Rio de Janeiro e Minas Gerais', 1, 'aviso', 1, 0),
('qualidade_ar', 'IQA Ótimo Registrado em Florianópolis', 'Florianópolis registra IQA 18 - índice de qualidade do ar ÓTIMO nesta semana', 13, 'informativo', 1, 0);
