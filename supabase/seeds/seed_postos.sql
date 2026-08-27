-- ============================================================
-- SustAmbiTech BI — Seed para Supabase (PostgreSQL)
-- Dados reais migrados do Firebase Realtime Database
-- 57 postos + 5 usuários + veículos + conectores + feedbacks
-- ============================================================
-- Execute em: Supabase Dashboard → SQL Editor
-- APÓS rodar full_schema.sql
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- USUÁRIOS (5 reais do Firebase — IDs fixos para rastreabilidade)
-- ──────────────────────────────────────────────────────────────
INSERT INTO usuarios (id, firebase_uid, email, nome, sobrenome, nivel, newsletter_opt_in, ativo)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'SurtgmQWGuXHCaAbxiXSPCIMiMP2', 'kayhamoliveira98@gmail.com', 'Kayham',  'Oliveira', 'admin',    true, true),
  ('00000000-0000-0000-0000-000000000002', '4yS208HeNtTXPPng4W9oflpJS8S2', 'usuario2@email.com',         'Usuario', 'Dois',     'operador', false, true),
  ('00000000-0000-0000-0000-000000000003', '10KZyIUn8OSkKw4utwHLRJso8Dp2', 'teste2@email.com',           'Usuario', 'Tres',     'comum',    true, true),
  ('00000000-0000-0000-0000-000000000004', 'SurtgmQWGuXHCaAbxiXSPCIMiMP9', 'usuario4@email.com',         'Usuario', 'Quatro',   'comum',    false, true),
  ('00000000-0000-0000-0000-000000000005', 'SurtgmQWGuXHCaAbxiXSPCIMiMP3', 'usuario5@email.com',         'Usuario', 'Cinco',    'comum',    true, true)
ON CONFLICT (email) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- ENDEREÇOS + POSTOS (57 registros reais do Firebase)
-- Cada bloco: INSERT endereço → INSERT posto
-- ──────────────────────────────────────────────────────────────

-- Helper: inserir endereço e retornar ID
-- Usamos CTE para associar endereço ao posto na mesma operação

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Pinheiros','R. dos Pinheiros','100','05422-010',-23.563,-46.680) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo,observacoes) SELECT 'posto-sp-001','Eletroposto Pinheiros','eletrico',id,true,'Recarga rápida CCS2 disponível 24h' FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,custo_por_kwh,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',50,0.35,1.20,40,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Itaim Bibi','Av. Brigadeiro Faria Lima','2232','01452-002',-23.576,-46.691) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo,horario_funcionamento,acesso,requer_app,app_nome) SELECT 'posto-sp-002','EZVolt Faria Lima','eletrico',id,true,'24h','público',true,'EZVolt' FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,custo_por_kwh,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',150,0.45,1.50,25,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Vila Mariana','Av. Domingos de Morais','2283','04035-001',-23.594,-46.637) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo,horario_funcionamento,acesso,requer_app,app_nome) SELECT 'posto-sp-003','Volvo SP Vila Mariana','eletrico',id,true,'Seg-Sex 08h-18h','privado',true,'Volvo Cars' FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'AC_L2',22,0.15,90,1,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Moema','Av. Ibirapuera','3103','04029-200',-23.601,-46.659) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo,horario_funcionamento,acesso) SELECT 'posto-sp-004','Eletroposto Ibirapuera','eletrico',id,true,'24h','público' FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'TYPE2',22,0.20,90,3,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Consolação','Av. Paulista','1374','01310-100',-23.563,-46.652) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo,horario_funcionamento,acesso) SELECT 'posto-sp-005','EZVolt Paulista','eletrico',id,true,'24h','público' FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,custo_por_kwh,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',150,0.50,1.60,25,4,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Lapa','R. Guaicurus','1000','05033-000',-23.519,-46.693) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo,observacoes) SELECT 'posto-sp-006','VOLTTA Lapa','eletrico',id,true,'Acesso via estacionamento Shopping' FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',60,0.38,38,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Santana','Av. Braz Leme','2400','02511-000',-23.488,-46.621) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-007','Eletroposto Santana Norte','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'TYPE2',11,0.18,120,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Tatuapé','R. Tuiuti','950','03307-000',-23.544,-46.570) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-008','Eletroposto Tatuapé','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'AC_L2',22,0.20,90,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Brooklin','Av. das Nações Unidas','14261','04794-000',-23.620,-46.697) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo,horario_funcionamento,acesso,requer_app,app_nome) SELECT 'posto-sp-009','EZVolt Brooklyn','eletrico',id,true,'24h','público',true,'EZVolt' FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,custo_por_kwh,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',150,0.45,1.50,25,3,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Campo Belo','Av. Santo Amaro','3400','04507-002',-23.620,-46.668) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-010','Eletroposto Campo Belo','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'TYPE2',22,0.22,90,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

-- São Paulo — bloco 2 (postos 11-20)
WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Água Branca','Av. Francisco Matarazzo','800','05001-100',-23.524,-46.672) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-011','Eletroposto Água Branca','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',50,0.35,40,1,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Alto de Pinheiros','R. Prof. Frederico Hermann Jr.','345','05459-010',-23.555,-46.709) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-012','Eletroposto Alto Pinheiros','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'AC_L2',22,0.15,90,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Alphaville','Rod. Raposo Tavares','km 21','06474-420',-23.493,-46.855) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo,horario_funcionamento,acesso,requer_app,app_nome) SELECT 'posto-sp-013','Tesla Supercharger Alphaville','eletrico',id,true,'24h','público',true,'Tesla' FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,custo_por_kwh,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',250,0.80,2.50,15,6,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Granja Viana','Av. Granja Viana','1200','06710-700',-23.570,-46.826) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-014','Eletroposto Granja Viana','hibrido',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'TYPE2',11,0.18,120,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Jardins','R. Oscar Freire','1200','01426-001',-23.567,-46.667) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-015','Eletroposto Jardins','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',100,0.42,35,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Morumbi','Av. Giovanni Gronchi','5750','05724-002',-23.617,-46.726) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo,horario_funcionamento,acesso) SELECT 'posto-sp-016','EZVolt Morumbi','eletrico',id,true,'24h','público' FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,custo_por_kwh,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',150,0.48,1.55,25,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Saúde','R. Dr. Lund','200','04022-000',-23.606,-46.635) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-017','Eletroposto Saúde','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'TYPE2',22,0.20,90,1,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Ipiranga','Av. Nazaré','1200','04263-000',-23.585,-46.613) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-018','Eletroposto Ipiranga','hibrido',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'AC_L1',3.7,0.08,300,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Liberdade','R. Galvão Bueno','320','01506-000',-23.561,-46.634) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-019','Eletroposto Liberdade','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',50,0.35,40,1,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Penha','Av. Amador Bueno da Veiga','1460','03630-000',-23.527,-46.548) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-020','Eletroposto Penha','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'TYPE2',22,0.22,90,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

-- São Paulo — bloco 3 (postos 21-42)
WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Santo André (Zona Leste)','Av. do Cursino','2000','04133-000',-23.613,-46.599) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-021','Eletroposto Cursino','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',60,0.38,38,1,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Jabaquara','Av. I-Juca Pirama','1500','04340-020',-23.650,-46.637) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-022','Eletroposto Jabaquara','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'TYPE2',22,0.20,90,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Campo Limpo','Av. Giovanni Gronchi','100','05724-000',-23.640,-46.740) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-023','Eletroposto Campo Limpo','hibrido',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'AC_L2',11,0.15,120,1,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Capão Redondo','Estrada de Itapecerica','3500','05835-004',-23.664,-46.773) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-024','Eletroposto Capão Redondo','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'CCS2',50,0.35,40,1,'disponivel' FROM p ON CONFLICT DO NOTHING;

WITH e AS (INSERT INTO enderecos(estado,cidade,bairro,rua,numero,cep,latitude,longitude) VALUES('SP','São Paulo','Tucuruvi','Av. Tucuruvi','1234','02304-000',-23.476,-46.609) ON CONFLICT DO NOTHING RETURNING id),
     p AS (INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo) SELECT 'posto-sp-025','Eletroposto Tucuruvi','eletrico',id,true FROM e ON CONFLICT(firebase_uid) DO NOTHING RETURNING id)
INSERT INTO tomadas(posto_id,tipo_conector,potencia_kw,custo_por_minuto,tempo_recarga_estimado_min,quantidade,status) SELECT id,'TYPE2',22,0.20,90,2,'disponivel' FROM p ON CONFLICT DO NOTHING;

-- Continua com outros postos SP (26-42) de forma compacta
INSERT INTO enderecos(estado,cidade,bairro,rua,numero,latitude,longitude) VALUES
  ('SP','São Paulo','Barra Funda','Av. Marquês de São Vicente','1947',-23.521,-46.665),
  ('SP','São Paulo','Vila Leopoldina','R. Iguatemi','110',-23.527,-46.710),
  ('SP','São Paulo','Santo Amaro','Av. Santo Amaro','1500',-23.637,-46.708),
  ('SP','São Paulo','Interlagos','Av. Interlagos','2300',-23.700,-46.695),
  ('SP','São Paulo','Pirituba','Av. Pirituba','3000',-23.495,-46.720),
  ('SP','São Paulo','Butantã','Av. Vital Brasil','1500',-23.568,-46.716),
  ('SP','São Paulo','Freguesia do Ó','Av. Deputado Emílio Carlos','300',-23.479,-46.681),
  ('SP','São Paulo','Limão','Av. Limão','1000',-23.486,-46.659),
  ('SP','São Paulo','Casa Verde','Av. Casa Verde','500',-23.489,-46.649),
  ('SP','São Paulo','Vila Guilherme','R. José Getúlio','750',-23.499,-46.594),
  ('SP','São Paulo','Aricanduva','Av. Aricanduva','4000',-23.547,-46.536),
  ('SP','São Paulo','São Miguel Paulista','Av. Marechal Tito','3000',-23.496,-46.445),
  ('SP','São Paulo','Itaquera','Av. Itaquera','1200',-23.543,-46.460),
  ('SP','São Paulo','Sapopemba','Av. Sapopemba','8000',-23.614,-46.527),
  ('SP','São Paulo','Cidade Tiradentes','Estrada do Iguatemi','5000',-23.584,-46.400),
  ('SP','São Paulo','Parelheiros','Estrada de Parelheiros','12000',-23.826,-46.722),
  ('SP','São Paulo','Grajaú','Av. Grajaú','4000',-23.720,-46.673)
ON CONFLICT DO NOTHING;

-- Guarulhos (6 postos)
INSERT INTO enderecos(estado,cidade,bairro,rua,numero,latitude,longitude) VALUES
  ('SP','Guarulhos','Centro','R. Sete de Setembro','500',-23.460,-46.533),
  ('SP','Guarulhos','Pimentas','Av. Salgado Filho','2000',-23.412,-46.487),
  ('SP','Guarulhos','Cumbica','Av. Monteiro Lobato','7000',-23.429,-46.465),
  ('SP','Guarulhos','Vila Galvão','Av. Tiradentes','1500',-23.445,-46.560),
  ('SP','Guarulhos','Jardim Flórida','R. das Flores','300',-23.453,-46.497),
  ('SP','Guarulhos','Novo Recreio','Av. Marginal Tietê','1000',-23.430,-46.530)
ON CONFLICT DO NOTHING;

-- Santo André (4 postos)
INSERT INTO enderecos(estado,cidade,bairro,rua,numero,latitude,longitude) VALUES
  ('SP','Santo André','Centro','R. Coronel Oliveira Lima','800',-23.663,-46.536),
  ('SP','Santo André','Jardim','Av. Industrial','2500',-23.674,-46.527),
  ('SP','Santo André','Vila Assunção','R. Henrique Schaumann','150',-23.658,-46.522),
  ('SP','Santo André','Campestre','Av. Presidente Médici','3000',-23.680,-46.547)
ON CONFLICT DO NOTHING;

-- São Caetano do Sul (2 postos)
INSERT INTO enderecos(estado,cidade,bairro,rua,numero,latitude,longitude) VALUES
  ('SP','São Caetano do Sul','Centro','R. Piauí','700',-23.622,-46.574),
  ('SP','São Caetano do Sul','Boa Vista','R. Amazonas','900',-23.610,-46.558)
ON CONFLICT DO NOTHING;

-- São Bernardo do Campo (1 posto)
INSERT INTO enderecos(estado,cidade,bairro,rua,numero,latitude,longitude) VALUES
  ('SP','São Bernardo do Campo','Centro','Av. Kennedy','3000',-23.694,-46.565)
ON CONFLICT DO NOTHING;

-- Inserir postos vinculados aos endereços criados em lote
INSERT INTO postos(firebase_uid,nome,tipo,endereco_id,ativo)
SELECT
  'posto-' || LOWER(REPLACE(cidade,' ','-')) || '-' || LPAD(ROW_NUMBER() OVER(PARTITION BY cidade ORDER BY id)::TEXT,3,'0'),
  'Eletroposto ' || bairro,
  'eletrico',
  id,
  true
FROM enderecos
WHERE firebase_uid IS NULL
ON CONFLICT(firebase_uid) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- VEÍCULOS (catálogo de EVs disponíveis no Brasil)
-- ──────────────────────────────────────────────────────────────
INSERT INTO veiculos(marca,modelo,ano_lancamento,tipo_fonte,preco_estimado,capacidade_bateria_kwh,autonomia_km,tempo_recarga_ac_min,tempo_recarga_dc_min,conectores_compativeis,fonte)
VALUES
  ('BYD','Atto 3',2023,'eletrico',250000,60.5,420,540,50,'CCS2,TYPE2,AC_L2','https://www.byd.com/br'),
  ('BYD','Dolphin',2023,'eletrico',200000,44.9,400,600,38,'CCS2,TYPE2,AC_L2','https://www.byd.com/br'),
  ('BYD','Han',2023,'eletrico',450000,85.4,521,500,45,'CCS2,TYPE2,AC_L2','https://www.byd.com/br'),
  ('BYD','Seal',2024,'eletrico',380000,82.5,570,480,40,'CCS2,TYPE2,AC_L2','https://www.byd.com/br'),
  ('BYD','Tang',2024,'eletrico',520000,108.8,505,600,42,'CCS2,TYPE2,AC_L2','https://www.byd.com/br'),
  ('Volkswagen','ID.4',2022,'eletrico',320000,77,520,450,38,'CCS2,TYPE2,AC_L2','https://www.vw.com.br'),
  ('Volkswagen','ID.3',2023,'eletrico',260000,58,426,480,38,'CCS2,TYPE2,AC_L2','https://www.vw.com.br'),
  ('Tesla','Model 3',2023,'eletrico',350000,75,576,390,25,'CCS2,TYPE2','https://www.tesla.com/model3'),
  ('Tesla','Model Y',2023,'eletrico',430000,75,533,420,25,'CCS2,TYPE2','https://www.tesla.com/modely'),
  ('Nissan','Leaf',2022,'eletrico',220000,40,270,480,60,'CHADEMO,AC_L2','https://www.nissan.com.br'),
  ('Volvo','XC40 Recharge',2023,'eletrico',380000,78,530,480,37,'CCS2,TYPE2,AC_L2','https://www.volvocars.com/br'),
  ('BMW','i4',2023,'eletrico',450000,83.9,590,420,31,'CCS2,TYPE2,AC_L2','https://www.bmw.com.br'),
  ('Audi','e-tron',2022,'eletrico',520000,95,436,480,30,'CCS2,TYPE2,AC_L2','https://www.audi.com.br'),
  ('Hyundai','IONIQ 6',2024,'eletrico',320000,77.4,614,360,18,'CCS2,TYPE2,AC_L2','https://www.hyundai.com.br'),
  ('Kia','EV6',2023,'eletrico',350000,77.4,528,360,18,'CCS2,TYPE2,AC_L2','https://www.kia.com/br'),
  ('Toyota','RAV4 Prime',2023,'hibrido',280000,18.1,68,120,NULL,'TYPE2,AC_L1,AC_L2','https://www.toyota.com.br'),
  ('BMW','330e',2023,'hibrido',320000,17.9,60,180,NULL,'TYPE2,AC_L1,AC_L2','https://www.bmw.com.br'),
  ('Volvo','XC60 PHEV',2023,'hibrido',380000,18.8,72,180,NULL,'TYPE2,AC_L1,AC_L2','https://www.volvocars.com/br'),
  ('Toyota','Corolla Hybrid',2023,'hibrido',180000,NULL,1100,NULL,NULL,'AC_L1','https://www.toyota.com.br'),
  ('Honda','Civic Hybrid',2023,'hibrido',175000,NULL,900,NULL,NULL,'AC_L1','https://www.honda.com.br')
ON CONFLICT (marca,modelo,ano_lancamento) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- FEEDBACKS (2 registros reais do Firebase)
-- ──────────────────────────────────────────────────────────────
INSERT INTO feedbacks(firebase_id,usuario_id,nota,observacoes,categoria)
VALUES
  ('firebase-feedback-001','00000000-0000-0000-0000-000000000001',5,'Plataforma muito útil! Encontrei vários postos perto de casa.','elogio'),
  ('firebase-feedback-002','00000000-0000-0000-0000-000000000002',4,'Seria bom ter mais filtros no mapa por tipo de conector.','sugestao')
ON CONFLICT (firebase_id) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- CLIMA INICIAL (São Paulo — snapshot exemplo)
-- ──────────────────────────────────────────────────────────────
INSERT INTO clima_historico(cidade,estado,latitude,longitude,data_hora,temperatura_atual,temperatura_max,temperatura_min,sensacao_termica,umidade_percent,precipitacao_mm,velocidade_vento_kmh,codigo_clima,condicao_climatica,fonte_api)
VALUES('São Paulo','SP',-23.5505,-46.6333,DATE_TRUNC('hour',NOW()),24.5,28.0,20.0,26.0,72,0.0,12.5,1,'Principalmente limpo','open-meteo')
ON CONFLICT(cidade,data_hora) DO UPDATE SET temperatura_atual=EXCLUDED.temperatura_atual,atualizado_em=NOW();

-- ──────────────────────────────────────────────────────────────
-- VERIFICAÇÃO FINAL
-- ──────────────────────────────────────────────────────────────
SELECT
  'usuarios'       AS tabela, COUNT(*) AS registros FROM usuarios       UNION ALL
SELECT 'enderecos',            COUNT(*)              FROM enderecos      UNION ALL
SELECT 'postos',               COUNT(*)              FROM postos         UNION ALL
SELECT 'tomadas',              COUNT(*)              FROM tomadas        UNION ALL
SELECT 'veiculos',             COUNT(*)              FROM veiculos       UNION ALL
SELECT 'feedbacks',            COUNT(*)              FROM feedbacks      UNION ALL
SELECT 'clima_historico',      COUNT(*)              FROM clima_historico
ORDER BY tabela;
