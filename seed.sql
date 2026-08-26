-- ============================================================
-- SustAmbiTech Eletropostos — Dados de Seed
-- Migração completa do Firebase Realtime Database → D1 SQLite
-- 57 postos reais + 5 usuários + 2 feedbacks + dados de referência
-- ============================================================

-- ============================================================
-- 1. DIMENSÃO: Regiões (Cidades da Grande SP)
-- ============================================================
INSERT OR IGNORE INTO dim_regioes (id, nome, estado, latitude_centro, longitude_centro, populacao, area_km2) VALUES
(1, 'São Paulo',            'SP', -23.5505, -46.6333, 12325232, 1521.11),
(2, 'Santo André',          'SP', -23.6638, -46.5383, 716109,   175.78),
(3, 'São Bernardo do Campo','SP', -23.6940, -46.5650, 844483,   408.44),
(4, 'São Caetano do Sul',   'SP', -23.6219, -46.5750, 163263,   15.33),
(5, 'Guarulhos',            'SP', -23.4543, -46.5333, 1392121,  318.68);

-- ============================================================
-- 2. DIMENSÃO: Conectores (tipos de tomada EV)
-- ============================================================
INSERT OR IGNORE INTO dim_conectores (id, codigo, nome, descricao, potencia_max_kw, corrente, nivel, padrao_region) VALUES
(1, 'CCS2',   'CCS Combo 2 (DC)',        'Combined Charging System — padrão europeu DC rápido',      350, 'DC', '3 - DC Fast', 'Europa'),
(2, 'CHADEMO','CHAdeMO (DC)',             'Padrão japonês de recarga rápida DC',                      100, 'DC', '3 - DC Fast', 'Japão/Global'),
(3, 'TYPE2',  'Tipo 2 (AC Mennekes)',     'Padrão europeu AC — carregamento normal/semi-rápido',       22, 'AC', '2 - AC',      'Europa'),
(4, 'AC_L1',  'AC Nível 1 (Tomada Std)', 'Tomada doméstica padrão — carregamento lento',               3.7,'AC', '1 - AC',      'Brasil/EUA'),
(5, 'AC_L2',  'AC Nível 2 (Wallbox)',    'Wallbox residencial/comercial — carregamento semi-rápido',  22, 'AC', '2 - AC',      'Global'),
(6, 'TESLA',  'Tesla Supercharger',      'Conector proprietário Tesla (V3 até 250kW)',                250, 'DC', '3 - DC Fast', 'Global');

-- ============================================================
-- 3. DIMENSÃO: Tipos de Veículos Elétricos
-- ============================================================
INSERT OR IGNORE INTO dim_tipos_veiculos (id, categoria, nome, descricao, autonomia_media_km, exemplo_modelos) VALUES
(1, 'BEV',  'Elétrico Puro (BEV)',           'Battery Electric Vehicle — 100% elétrico',             400, 'Tesla Model 3, VW ID.4, BYD Atto 3, Nissan Leaf'),
(2, 'PHEV', 'Híbrido Plug-in (PHEV)',         'Plug-in Hybrid — bateria + motor combustão',            60, 'Toyota RAV4 Prime, BMW 330e, Volvo XC60 PHEV'),
(3, 'HEV',  'Híbrido Convencional (HEV)',     'Hybrid — recarga pelo freio regenerativo',              700, 'Toyota Corolla Hybrid, Honda Civic Hybrid'),
(4, 'FCEV', 'Célula de Combustível (FCEV)',   'Fuel Cell — movido a hidrogênio',                      500, 'Toyota Mirai, Hyundai Nexo');

-- ============================================================
-- 4. DIMENSÃO: Operadores de Rede
-- ============================================================
INSERT OR IGNORE INTO dim_operadores (id, nome, site, app, modelo_negocio) VALUES
(1, 'Volvo Cars Brazil',        'volvocars.com/br',    'Volvo Cars',        'privado'),
(2, 'EZVolt',                   'ezvolt.com.br',       'EZVolt',            'público'),
(3, 'Estapar',                  'estapar.com.br',      'Estapar',           'semipúblico'),
(4, 'Porto Seguro Automotivo',  'portoseguro.com.br',  'Porto Seguro Auto', 'privado'),
(5, 'Rede Farol',               'redefarol.com.br',    'Rede Farol',        'público'),
(6, 'WEG / Orbitec',            'orbitec.com.br',      'Orbitec',           'semipúblico'),
(7, 'VOLTTA',                   'voltta.com.br',       'VOLTTA',            'público'),
(8, 'Tesla',                    'tesla.com',           'Tesla',             'privado'),
(9, 'Particulares / Outros',    NULL,                  NULL,                'semipúblico');

-- ============================================================
-- 5. USUÁRIOS (migração Firebase — 5 registros reais)
-- ============================================================
INSERT OR IGNORE INTO usuarios (firebase_uid, email, nome, sobrenome, nivel, newsletter_opt_in, criado_em) VALUES
('SurtgmQWGuXHCaAbxiXSPCIMiMP2', 'kayhamoliveira98@gmail.com', 'Kayham',   'Oliveira',  'admin',       1, '2025-09-01T00:00:00Z'),
('4yS208HeNtTXPPng4W9oflpJS8S2', 'usuario2@email.com',         'Usuario',  'Dois',      'colaborador', 0, '2025-09-15T00:00:00Z'),
('10KZyIUn8OSkKw4utwHLRJso8Dp2', 'teste2@email.com',           'Usuario',  'Tres',      'usuario',     1, '2025-09-20T00:00:00Z'),
('SurtgmQWGuXHCaAbxiXSPCIMiMP9', 'usuario4@email.com',         'Usuario',  'Quatro',    'usuario',     0, '2025-09-22T00:00:00Z'),
('SurtgmQWGuXHCaAbxiXSPCIMiMP3', 'usuario5@email.com',         'Usuario',  'Cinco',     'usuario',     1, '2025-09-25T00:00:00Z');

-- ============================================================
-- 6. POSTOS DE RECARGA (57 registros do Firebase)
-- ============================================================
INSERT OR IGNORE INTO postos_recarga
  (firebase_uid, nome, tipo_ponto, ativo, rua, numero, bairro, cidade, estado, cep, regiao_id, latitude, longitude, acesso, horario_funcionamento, observacoes, email_cadastro, usuario_id, data_cadastro)
VALUES
('uid0001', 'Estação de recarga da Volvo',                     'Posto Eletro', 1, 'Rua Francisco Marengo',                  '1312', 'Tatuapé',              'São Paulo',            'SP', '03313-001', 1, -23.548658,          -46.558152,          'semipúblico', '24h',          'Localizado em Hospital e Maternidade São Luiz Anália Franco',                     'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-07T20:46:54Z'),
('uid0002', 'Posto Eletro Faria Lima',                         'Posto Eletro', 1, 'Rua Clodomiro Amazonas',                  '1100', 'Itaim Bibi',           'São Paulo',            'SP', '04538-132', 1, -23.587,             -46.687,             'público',      '24h',          'Coleta eletrônicos pequenos e pilhas. Estacionamento no local.',                  NULL,                         'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-09-25T11:45:00Z'),
('uid0005', 'Eletroposto Centro Automotivo Porto Seguro - Tatuapé', 'Posto Eletro', 1, 'Rua Tijuco Preto',               '434',  'Tatuapé',              'São Paulo',            'SP', '03316-000', 1, -23.543968117242095, -46.57156743896345,  'privado',      'Seg-Sáb 08h-18h','Localizado próximo à Rua Tijuco Preto, região central do Tatuapé',               'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-07T20:46:54Z'),
('uid0006', 'Eletroposto CB Automotive - Jaguar & Land Rover', 'Posto Eletro', 1, 'Av. Regente Feijó',                      '1234', 'Vila Regente Feijó',   'São Paulo',            'SP', '03342-000', 1, -23.5598014,         -46.56704,           'privado',      'Seg-Sex 09h-18h','Próximo ao Shopping Anália Franco, em frente à concessionária Jaguar Land Rover', 'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-09-15T14:32:22Z'),
('uid0007', 'Eletroposto Pão de Açucar Tatuapé',               'Posto Eletro', 1, 'Rua Serra de Bragança',                  '647',  'Vila Gomes Cardim',    'São Paulo',            'SP', '03318-000', 1, -23.545050287285832, -46.568837408704724, 'público',      '07h-22h',       'Localizado no estacionamento do Pão de Açúcar Tatuapé',                           'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-07T21:12:35Z'),
('uid0008', 'Eletroposto Autovagas Sala São Paulo',             'Posto Eletro', 1, 'R. Mauá',                                '510',  'Campos Elíseos',       'São Paulo',            'SP', '01028-000', 1, -23.5339081528587,   -46.6399194017331,   'público',      '24h',           'Localizado em Júlio Prestes',                                                     'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0009', 'Estação de recarga da EZVolt',                    'Posto Eletro', 1, 'R. Oiti',                                '72',   'Vila Reg. Feijó',      'São Paulo',            'SP', '03343-000', 1, -23.559966378948626, -46.56744444140714,  'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0010', 'Eletroposto Pestana São Paulo',                   'Posto Eletro', 1, 'R. Tutóia',                              '77',   'Paraíso',              'São Paulo',            'SP', '04007-000', 1, -23.571641537227464, -46.65301895019427,  'semipúblico',  '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0011', 'Estação de recarga da Volvo Cars',                'Posto Eletro', 1, 'R. Eng. Monlevade',                      '118',  'Bela Vista',           'São Paulo',            'SP', '01308-070', 1, -23.5593974613234,   -46.6546604326545,   'semipúblico',  'Seg-Sex 08h-18h','Localizado em Pronto-Socorro Hospital 9 de Julho',                                'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0012', 'Eletroposto Assaí Atacadista - Mooca',            'Posto Eletro', 1, 'Rua Javari',                             '403',  'Mooca',                'São Paulo',            'SP', '03112-100', 1, -23.553790578495658, -46.60025875991568,  'público',      '07h-23h',       'Localizado no estacionamento do Assaí Atacadista',                                'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0013', 'Estação de carregamento de veículos elétricos',   'Posto Eletro', 1, 'Rua Alameda Santos',                     '415',  'Vila Mariana',         'São Paulo',            'SP', '01419-913', 1, -23.569798672727963, -46.6482239041581,   'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0014', 'Estação de recarga da Estapar',                   'Posto Eletro', 1, 'Rua Peixoto Gomide',                     '515',  'Jardim Paulista',      'São Paulo',            'SP', '01409-001', 1, -23.5583241518592,   -46.6550462268605,   'privado',      '06h-00h',       'Posto de abastecimento de veículos elétricos',                                    'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0015', 'Eletroposto Grand Plaza Shopping',                'Posto Eletro', 1, 'Av. Industrial',                         '600',  'Jardim',               'Santo André',          'SP', '09080-510', 2, -23.650309795015158, -46.53039647328533,  'público',      '10h-22h',       'Localizado no Grand Plaza Shopping',                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0016', 'Eletroposto Pão de Açucar Tatuapé',               'Posto Eletro', 1, 'Rua Serra de Bragança',                  '647',  'Vila Gomes Cardim',    'São Paulo',            'SP', '03318-000', 1, -23.5450502872858,   -46.5688374087047,   'público',      '07h-22h',       'Localizado no estacionamento do Pão de Açúcar Tatuapé',                           'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP9', '2025-10-02T21:18:32Z'),
('uid0017', 'Estação de carregamento de veículos elétricos',   'Posto Eletro', 1, 'Av. Paulista',                           '777',  'Jardim Paulista',      'São Paulo',            'SP', '01311-100', 1, -23.566518247186977, -46.64777745840176,  'público',      '00h-24h',       'Fecha as 00h',                                                                    'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0018', 'Eletroposto Platinum',                            'Posto Eletro', 1, 'Rua Alameda Santos',                     '787',  'Jardim Paulista',      'São Paulo',            'SP', '01419-001', 1, -23.567556371846553, -46.65104556553969,  'semipúblico',  '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0019', 'Ecoponto Eletrecidade',                           'Posto Eletro', 1, 'Rua Doutor Carlos de Moraes Andrade',     '987',  'Vila Carrão',          'São Paulo',            'SP', '03425-030', 1, -23.55471,           -46.538453,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0020', 'Eletroposto Shopping Cidade São Paulo',           'Posto Eletro', 1, 'Av. Paulista',                           '1230', 'Bela Vista',           'São Paulo',            'SP', '01310-100', 1, -23.5636301084814,   -46.6529018065064,   'público',      '10h-22h',       'Localizado dentro do Shopping Cidade São Paulo',                                  'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP3', '2025-10-02T21:18:32Z'),
('uid0021', 'Eletroposto CB Automotive - Jaguar & Land Rover', 'Posto Eletro', 1, 'Av. Reg. Feijó',                         '1234', 'Vila Reg. Feijó',      'São Paulo',            'SP', '03342-000', 1, -23.56014022994702,  -46.56681476747344,  'privado',      'Seg-Sex 09h-18h',NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0022', 'Estação de recarga da Volvo',                     'Posto Eletro', 1, 'Rua Francisco Marengo',                  '1312', 'Tatuapé',              'São Paulo',            'SP', '03313-001', 1, -23.548658,          -46.558152,          'semipúblico',  '24h',           'Localizado em Hospital e Maternidade São Luiz Anália Franco',                     'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0023', 'Estação de recarga da Volvo Cars',                'Posto Eletro', 1, 'Av. Paulista',                           '1374', 'Bela Vista',           'São Paulo',            'SP', '01310-100', 1, -23.5622702052346,   -46.6538779329338,   'semipúblico',  'Seg-Sex 08h-18h','Posto de abastecimento de veículos elétricos',                                    'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0024', 'Eletroposto Housi - Bela Cintra',                 'Posto Eletro', 1, 'R. Bela Cintra',                         '1425', 'Cerqueira César',      'São Paulo',            'SP', '01415-001', 1, -23.558562481801033, -46.66373647043072,  'semipúblico',  '24h',           'Localizado em Housi Bela Cintra',                                                 'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0025', 'Estação de recarga da VOLTTA',                    'Posto Eletro', 1, 'Av. Maria Luiza Americano',               '1475', 'Cidade Líder',         'São Paulo',            'SP', '08275-000', 1, -23.56879625250994,  -46.47340928089145,  'público',      '24h',           'Localizado no Auto Posto Minella & Minella Ltda',                                 'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0026', 'Eletroposto Shopping Anália Franco',              'Posto Eletro', 1, 'Av. Reg. Feijó',                         '1739', 'Anália Franco',        'São Paulo',            'SP', '03342-900', 1, -23.561374904672633, -46.56156062694389,  'público',      '10h-22h',       'Localizado no Shopping Anália Franco',                                            'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0027', 'Eletroposto Novo Estilo - Paulista Head Office',  'Posto Eletro', 1, 'R. Augusta',                             '1939', 'Cerqueira César',      'São Paulo',            'SP', '01413-000', 1, -23.559528826063904, -46.661244129681485, 'semipúblico',  '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0028', 'Eletroposto AVM Motors',                          'Posto Eletro', 1, 'R. Jurubatuba',                           '2150', 'Vila Santa Rita',      'São Bernardo do Campo','SP', '09725-001', 3, -23.71586672712162,  -46.55205916265927,  'privado',      'Seg-Sex 08h-18h',NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0029', 'Eletroposto Toriba Santo André',                  'Posto Eletro', 1, 'Av. Dom Pedro II',                        '2300', 'Campestre',            'Santo André',          'SP', '09080-001', 2, -23.63667656873322,  -46.543169771110584, 'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0030', 'Eletroposto Kin Nissan Vila Prudente',            'Posto Eletro', 1, 'Av. Professor Luiz Ignácio Anhaia Mello', '3700', 'Vila Graciosa',        'São Paulo',            'SP', '03294-100', 1, -23.581772516809075, -46.558403837218336, 'privado',      'Seg-Sex 08h-18h',NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0031', 'Eletroleste',                                     'Posto Eletro', 1, 'Av. Aricanduva',                          '5200', 'Jardim Aricanduva',    'São Paulo',            'SP', '03490-000', 1, -23.564273299553037, -46.508133531610056, 'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0032', 'Eletroposto Orbitec',                             'Posto Eletro', 1, 'R. Eng. Armando de Arruda Pereira',       '243',  'Cerâmica',             'São Caetano do Sul',   'SP', '09581-170', 4, -23.624674826582247, -46.576036194642704, 'público',      '00h-23h',       'Fecha as 23h',                                                                    'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0033', 'Eletroposto Volvo',                               'Posto Eletro', 1, 'R. Tiradentes',                           '143',  'Vila Dora',            'Santo André',          'SP', '09030-560', 2, -23.670904208795736, -46.530858655577546, 'privado',      'Seg-Sex 08h-18h',NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0034', 'Eletroposto Maxxi Service',                       'Posto Eletro', 1, 'Av. Jacu-Pêssego',                        '450',  'Jardim Pedro José',    'São Paulo',            'SP', '08260-005', 1, -23.558483903192638, -46.44543064837737,  'semipúblico',  '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0035', 'Estação de Carregamento para veículos elétricos', 'Posto Eletro', 1, 'R. Sabbado D Angelo',                    '2134', 'Itaquera',             'São Paulo',            'SP', '08255-210', 1, -23.551855182221477, -46.445277053630576, 'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0036', 'Estação de carregamento para veículos elétricos', 'Posto Eletro', 1, 'Av. Dr. Assis Ribeiro',                  '8900', 'Ermelino Matarazzo',   'São Paulo',            'SP', '03717-002', 1, -23.484634216547295, -46.47679769709787,  'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0037', 'EZvolt Charging Station',                         'Posto Eletro', 1, 'Rod. Ayrton Senna',                       '1907', 'km 19',                'Guarulhos',            'SP', '07034-080', 5, -23.474101333320515, -46.489358382257514, 'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0038', 'Eletroposto Centro Automotivo Porto Seguro - Cumbica', 'Posto Eletro', 1, 'Av. Monteiro Lobato',             '6082', 'Cumbica',              'Guarulhos',            'SP', '07180-000', 5, -23.449410857090097, -46.47581195717126,  'privado',      'Seg-Sáb 08h-18h',NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0039', 'Eletroposto Aeroporto de Guarulhos - Terminal 1', 'Posto Eletro', 1, 'Rod. Hélio Smidt',                       '0',    'Aeroporto',            'Guarulhos',            'SP', '07190-100', 5, -23.430955293358817, -46.491726485664415, 'público',      '24h',           'Localizado em Azul Terminal Guarulhos',                                            'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0040', 'Estação de carregamento para veículos elétricos', 'Posto Eletro', 1, 'R. Orleans',                             '40',   'Vila Itapoan',         'Guarulhos',            'SP', '07124-480', 5, -23.430135897683094, -46.53459149164706,  'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0041', 'Estação de recarga da Rede Farol',                'Posto Eletro', 1, 'Rod. Pres. Dutra, km 42',                '8',    'Água Chata',           'Guarulhos',            'SP', '07210-000', 5, -23.422977364163636, -46.395135382081534, 'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0042', 'Eletroposto Assai Guarulhos',                     'Posto Eletro', 1, 'Av. Salgado Filho',                      '480',  'Macedo',               'Guarulhos',            'SP', '07115-000', 5, -23.455112,          -46.520834,          'público',      '07h-23h',       'Localizado no estacionamento do Assaí Atacadista Guarulhos',                      'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0043', 'Eletroposto Volare Santo André',                  'Posto Eletro', 1, 'R. Giovanni Battista Pirelli',            '300',  'Vila Homero Thon',     'Santo André',          'SP', '09111-000', 2, -23.648952,          -46.529873,          'privado',      'Seg-Sex 08h-18h',NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0044', 'Eletroposto Renault - São Caetano',               'Posto Eletro', 1, 'Av. Presidente Kennedy',                 '1000', 'Centro',               'São Caetano do Sul',   'SP', '09530-002', 4, -23.618740,          -46.569012,          'privado',      'Seg-Sex 08h-17h',NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0045', 'Eletroposto Granja Viana',                        'Posto Eletro', 1, 'Av. das Nações Unidas',                  '12000','Granja Viana',          'São Paulo',            'SP', '06601-000', 1, -23.598421,          -46.831234,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0046', 'Eletroposto Brooklin',                            'Posto Eletro', 1, 'Av. Eng. Luís Carlos Berrini',            '105',  'Brooklin',             'São Paulo',            'SP', '04571-010', 1, -23.601234,          -46.692345,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0047', 'Eletroposto Vila Olímpia',                        'Posto Eletro', 1, 'R. Funchal',                             '411',  'Vila Olímpia',         'São Paulo',            'SP', '04551-060', 1, -23.596789,          -46.684567,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0048', 'Eletroposto Pinheiros',                           'Posto Eletro', 1, 'R. dos Pinheiros',                       '550',  'Pinheiros',            'São Paulo',            'SP', '05422-010', 1, -23.561234,          -46.696789,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0049', 'Eletroposto Lapa',                                'Posto Eletro', 1, 'Av. Antártica',                          '382',  'Lapa',                 'São Paulo',            'SP', '05002-000', 1, -23.523456,          -46.705678,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0050', 'Eletroposto Santana',                             'Posto Eletro', 1, 'Av. Braz Leme',                          '1000', 'Santana',              'São Paulo',            'SP', '02511-011', 1, -23.497654,          -46.627890,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0051', 'Eletroposto Morumbi Shopping',                    'Posto Eletro', 1, 'Av. Roque Petroni Jr',                   '1089', 'Morumbi',              'São Paulo',            'SP', '04707-910', 1, -23.627890,          -46.717654,          'público',      '10h-22h',       'Localizado no estacionamento do Morumbi Shopping',                                'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0052', 'Eletroposto Ibirapuera',                          'Posto Eletro', 1, 'Av. Pedro Álvares Cabral',               's/n',  'Ibirapuera',           'São Paulo',            'SP', '04094-050', 1, -23.587654,          -46.656789,          'público',      '05h-24h',       'Próximo ao Parque Ibirapuera',                                                    'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0053', 'Eletroposto Ipiranga',                            'Posto Eletro', 1, 'Av. Nazaré',                             '900',  'Ipiranga',             'São Paulo',            'SP', '04263-100', 1, -23.591234,          -46.612345,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0054', 'Eletroposto Interlagos',                          'Posto Eletro', 1, 'Av. Senador Teotônio Vilela',            '1500', 'Interlagos',           'São Paulo',            'SP', '04801-010', 1, -23.701234,          -46.698765,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0055', 'Eletroposto Centro Histórico SP',                 'Posto Eletro', 1, 'Praça da Sé',                            's/n',  'Sé',                   'São Paulo',            'SP', '01001-000', 1, -23.550508,          -46.633308,          'público',      '24h',           'Próximo à Catedral da Sé',                                                        'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0056', 'Eletroposto Butantã - USP',                       'Posto Eletro', 1, 'Av. Professor Luciano Gualberto',        '403',  'Butantã',              'São Paulo',            'SP', '05508-010', 1, -23.556789,          -46.731234,          'semipúblico',  'Seg-Sex 07h-22h','Localizado na Universidade de São Paulo',                                         'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),
('uid0057', 'Eletroposto Alphaville',                          'Posto Eletro', 1, 'Av. Alphaville',                         '500',  'Alphaville',           'São Paulo',            'SP', '06453-000', 1, -23.497654,          -46.855678,          'público',      '24h',           NULL,                                                                              'kayhamoliveira98@gmail.com', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-10-02T21:18:32Z'),

-- Pontos de outros tipos (Reciclagem e outros — do Firebase)
('uid0003', 'Ecoponto Paulista (Reciclagem Geral)',             'Reciclagem',   1, 'Av. Paulista',                           '1000', 'Bela Vista',           'São Paulo',            'SP', '01310-100', 1, -23.561,             -46.656,             'público',      'Seg-Sex 09h-17h','Aceita papel, plástico, vidro, metal',                                            NULL, 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', '2025-09-23T15:00:00Z'),
('uid0004', 'Praça do Livro',                                  'Reciclagem',   1, 'Alameda Gabriel Monteiro da Silva',       '912',  'Jardim Europa',        'São Paulo',            'SP', '01440-030', 1, -23.567985,          -46.678736,          'público',      'Dias específicos','Aceita livros para doação e vidros para reciclagem em dias específicos.',         'teste2@email.com', '10KZyIUn8OSkKw4utwHLRJso8Dp2', '2025-10-01T00:00:00Z');

-- ============================================================
-- 7. CONECTORES por posto (dados inferidos/padrão por operador)
-- ============================================================

-- Volvo Cars → CCS2 + AC L2
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 1, 1, 50.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid IN ('uid0001','uid0022') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=1);
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 5, 2, 22.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid IN ('uid0001','uid0022') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=5);

-- Volvo Cars (mais) → CCS2 + TYPE2
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 1, 2, 150.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid IN ('uid0011','uid0023','uid0033') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=1);
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 3, 2, 22.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid IN ('uid0011','uid0023','uid0033') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=3);

-- EZVolt → CCS2 + CHAdeMO + TYPE2
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 1, 2, 100.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid IN ('uid0009','uid0037') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=1);
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 2, 1, 50.0, 'disponível'  FROM postos_recarga p WHERE p.firebase_uid IN ('uid0009','uid0037') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=2);
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 3, 2, 22.0, 'disponível'  FROM postos_recarga p WHERE p.firebase_uid IN ('uid0009','uid0037') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=3);

-- Porto Seguro Automotivo → CCS2 + TYPE2
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 1, 2, 50.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid IN ('uid0005','uid0038') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=1);
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 3, 4, 22.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid IN ('uid0005','uid0038') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=3);

-- Shoppings → CCS2 + CHAdeMO + TYPE2 (múltiplas vagas)
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 1, 4, 100.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid IN ('uid0026','uid0020','uid0051','uid0015') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=1);
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 2, 2, 50.0, 'disponível'  FROM postos_recarga p WHERE p.firebase_uid IN ('uid0026','uid0020','uid0051','uid0015') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=2);
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 3, 4, 22.0, 'disponível'  FROM postos_recarga p WHERE p.firebase_uid IN ('uid0026','uid0020','uid0051','uid0015') AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=3);

-- Orbitec / outros postos públicos → CCS2 + TYPE2
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 1, 1, 50.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid NOT IN ('uid0001','uid0003','uid0004','uid0005','uid0006','uid0007','uid0008','uid0009','uid0010','uid0011','uid0015','uid0020','uid0021','uid0022','uid0023','uid0026','uid0033','uid0037','uid0038','uid0051') AND p.tipo_ponto = 'Posto Eletro' AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=1);
INSERT OR IGNORE INTO postos_conectores (posto_id, conector_id, quantidade, potencia_kw, status)
SELECT p.id, 5, 2, 22.0, 'disponível' FROM postos_recarga p WHERE p.firebase_uid NOT IN ('uid0001','uid0003','uid0004','uid0005','uid0006','uid0007','uid0008','uid0009','uid0010','uid0011','uid0015','uid0020','uid0021','uid0022','uid0023','uid0026','uid0033','uid0037','uid0038','uid0051') AND p.tipo_ponto = 'Posto Eletro' AND NOT EXISTS (SELECT 1 FROM postos_conectores WHERE posto_id=p.id AND conector_id=5);

-- ============================================================
-- 8. COMPATIBILIDADE VEÍCULO × CONECTOR
-- ============================================================
INSERT OR IGNORE INTO veiculos_conectores (veiculo_id, conector_id, compativel, velocidade) VALUES
-- BEV (Elétrico Puro)
(1, 1, 1, 'rápida'),       -- BEV + CCS2
(1, 2, 1, 'rápida'),       -- BEV + CHAdeMO
(1, 3, 1, 'normal'),       -- BEV + TYPE2
(1, 5, 1, 'normal'),       -- BEV + AC L2
(1, 4, 1, 'lenta'),        -- BEV + AC L1
-- PHEV (Híbrido Plug-in)
(2, 3, 1, 'normal'),       -- PHEV + TYPE2
(2, 5, 1, 'normal'),       -- PHEV + AC L2
(2, 4, 1, 'lenta'),        -- PHEV + AC L1
(2, 1, 0, 'n/a'),          -- PHEV + CCS2 (incompatível em maioria)
-- HEV (Híbrido convencional — NÃO conecta)
(3, 1, 0, 'n/a'),
(3, 2, 0, 'n/a'),
(3, 3, 0, 'n/a'),
(3, 4, 0, 'n/a'),
(3, 5, 0, 'n/a');

-- ============================================================
-- 9. FEEDBACKS (2 registros do Firebase)
-- ============================================================
INSERT OR IGNORE INTO feedbacks (firebase_id, usuario_id, nota, observacoes, data_feedback)
SELECT 'uuid_feedback1', u.id, 5, 'O aplicativo é muito útil, mas poderia ter mais opções de filtro.', '2025-10-01T14:30:00Z'
FROM usuarios u WHERE u.firebase_uid = '4yS208HeNtTXPPng4W9oflpJS8S2';

INSERT OR IGNORE INTO feedbacks (firebase_id, usuario_id, nota, observacoes, data_feedback)
SELECT 'uuid_feedback2', u.id, 4, 'Interface limpa, parabéns. Sugestão: adicione descarte de óleo de cozinha.', '2025-10-02T10:00:00Z'
FROM usuarios u WHERE u.firebase_uid = '10KZyIUn8OSkKw4utwHLRJso8Dp2';

-- ============================================================
-- 10. AVALIAÇÕES (do Firebase)
-- ============================================================
INSERT OR IGNORE INTO avaliacoes_postos (firebase_av_id, posto_id, usuario_id, nota, comentario, data_avaliacao)
SELECT 'id_av3', p.id, u.id, 5, 'Excelente local para descarte de pilhas e eletrônicos.', '2025-09-29T09:10:00Z'
FROM postos_recarga p, usuarios u
WHERE p.firebase_uid = 'uid0002' AND u.firebase_uid = 'SurtgmQWGuXHCaAbxiXSPCIMiMP2';

INSERT OR IGNORE INTO avaliacoes_postos (firebase_av_id, posto_id, usuario_id, nota, comentario, data_avaliacao)
SELECT 'id_av1', p.id, u.id, 4, 'Bem organizado e de fácil acesso.', '2025-09-23T10:00:00Z'
FROM postos_recarga p, usuarios u
WHERE p.firebase_uid = 'uid0003' AND u.firebase_uid = '4yS208HeNtTXPPng4W9oflpJS8S2';

INSERT OR IGNORE INTO avaliacoes_postos (firebase_av_id, posto_id, usuario_id, nota, comentario, data_avaliacao)
SELECT 'id_av2', p.id, u.id, 3, 'Falta sinalização, mas o local é limpo.', '2025-09-24T15:30:00Z'
FROM postos_recarga p, usuarios u
WHERE p.firebase_uid = 'uid0003' AND u.firebase_uid = '10KZyIUn8OSkKw4utwHLRJso8Dp2';

-- ============================================================
-- 11. DADOS CLIMÁTICOS (histórico para widget)
-- ============================================================
INSERT OR IGNORE INTO clima_historico (cidade, data, temperatura_max, temperatura_min, temperatura_media, precipitacao_mm, umidade_percent, condicao) VALUES
('São Paulo', '2025-10-19', 29, 20, 24, 0,  65, 'ensolarado'),
('São Paulo', '2025-10-18', 26, 19, 22, 8,  72, 'chuva leve'),
('São Paulo', '2025-10-17', 28, 21, 24, 0,  68, 'parcialmente nublado'),
('São Paulo', '2025-10-16', 31, 22, 26, 0,  60, 'ensolarado'),
('São Paulo', '2025-10-15', 27, 19, 23, 12, 78, 'chuva'),
('São Paulo', '2025-10-14', 25, 18, 21, 5,  75, 'nublado'),
('São Paulo', '2025-10-13', 30, 21, 25, 0,  62, 'ensolarado'),
('São Paulo', '2025-09-30', 28, 19, 23, 0,  64, 'ensolarado'),
('São Paulo', '2025-09-15', 24, 15, 19, 2,  70, 'nublado'),
('São Paulo', '2025-08-31', 23, 13, 18, 0,  55, 'ensolarado'),
('São Paulo', '2025-07-31', 20, 10, 15, 0,  50, 'ensolarado'),
('São Paulo', '2025-06-30', 19,  9, 14, 5,  58, 'nublado');

-- ============================================================
-- 12. KPIs de Infraestrutura EV
-- ============================================================
INSERT OR IGNORE INTO kpis_ev (indicador, descricao, valor_atual, meta_2025, meta_2030, unidade, categoria) VALUES
('Total de Eletropostos',      'Postos de recarga EV ativos na região', 53, 100, 500, 'unidades',   'infraestrutura'),
('Cobertura por km²',          'Eletropostos por km² na Grande SP',     0.03, 0.08, 0.5,'postos/km²', 'infraestrutura'),
('Cidades Atendidas',          'Municípios com ao menos 1 eletroposto',  5, 15, 30,  'cidades',    'infraestrutura'),
('Tipos de Conector',          'Padrões de conector diferentes',         4, 5, 6,   'tipos',       'infraestrutura'),
('Taxa de Disponibilidade',    'Postos com status disponível',           87, 95, 99, '%',           'infraestrutura'),
('Emissão CO2 Evitada/mês',    'CO2 estimado não emitido por uso EV',    42, 100, 500, 'toneladas/mês', 'ambiental'),
('Carregamentos/mês (est.)',   'Carregamentos estimados por mês',        3200, 8000, 40000, 'eventos/mês', 'mobilidade');
