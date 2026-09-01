-- ============================================================
-- SustAmbiTech BI — Schema MySQL Completo
-- Modelo: Mobilidade Elétrica + Postos de Recarga + Frotas
-- Baseado em: MySQL Workbench Forward Engineering
-- Fontes de dados: ABVE, Carregados.com.br, Power BI Frotas
-- ============================================================
-- Versão  : 2.0
-- Autores : Kayham, Gabriel, Eric Jr, Natan, Leandro
-- ============================================================
-- DECISÃO DE DESIGN:
--   CriadoEm / AtualizadoEm apenas onde há necessidade real
--   de rastreamento temporal de negócio.
--   LogAuditoria centraliza o histórico de mudanças.
--   Tabelas de lookup (NivelUsuario, Status, TipoEnergia)
--   são estáticas — não precisam de timestamps.
-- ============================================================

SET @OLD_UNIQUE_CHECKS   = @@UNIQUE_CHECKS,   UNIQUE_CHECKS   = 0;
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS = 0;
SET @OLD_SQL_MODE = @@SQL_MODE, SQL_MODE =
  'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,
   ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- ============================================================
DROP SCHEMA IF EXISTS `sustambitech`;
CREATE SCHEMA  `sustambitech` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `sustambitech`;

-- ============================================================
-- ██████████████   TABELAS DE LOOKUP (sem timestamps)   ██████
-- ============================================================

-- ------------------------------------------------------------
-- NivelUsuario — perfis de acesso do sistema
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `NivelUsuario` (
  `id_NivelUsuario` INT          NOT NULL AUTO_INCREMENT,
  `nivel`           VARCHAR(45)  NOT NULL UNIQUE   COMMENT 'Ex: admin, operador, comum',
  `descricao`       VARCHAR(200)     NULL,
  PRIMARY KEY (`id_NivelUsuario`)
) ENGINE = InnoDB COMMENT = 'Perfis de acesso dos usuários do sistema';

INSERT INTO `NivelUsuario` (`nivel`, `descricao`) VALUES
  ('admin',    'Acesso total: CRUD em todas as tabelas'),
  ('operador', 'Gerencia postos e tomadas da própria rede'),
  ('comum',    'Apenas leitura e avaliações');

-- ------------------------------------------------------------
-- Status — estados genéricos reutilizáveis
-- (Postos, Tomadas, Reservas compartilham esta tabela)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Status` (
  `id_Status`   INT          NOT NULL AUTO_INCREMENT,
  `contexto`    VARCHAR(30)  NOT NULL                  COMMENT 'posto | tomada | reserva',
  `nomeStatus`  VARCHAR(45)  NOT NULL,
  `descricao`   VARCHAR(200)     NULL,
  PRIMARY KEY (`id_Status`),
  UNIQUE KEY `uq_contexto_nome` (`contexto`, `nomeStatus`)
) ENGINE = InnoDB COMMENT = 'Estados reutilizáveis (postos, tomadas, reservas)';

INSERT INTO `Status` (`contexto`, `nomeStatus`, `descricao`) VALUES
  ('posto',   'ativo',        'Posto em operação normal'),
  ('posto',   'inativo',      'Posto fora de operação'),
  ('posto',   'manutencao',   'Posto em manutenção temporária'),
  ('tomada',  'disponivel',   'Tomada livre para uso'),
  ('tomada',  'ocupada',      'Tomada em uso no momento'),
  ('tomada',  'manutencao',   'Tomada fora de serviço'),
  ('tomada',  'inativa',      'Tomada desativada permanentemente'),
  ('reserva', 'pendente',     'Reserva aguardando confirmação'),
  ('reserva', 'confirmada',   'Reserva confirmada'),
  ('reserva', 'em_andamento', 'Recarga em andamento'),
  ('reserva', 'concluida',    'Recarga finalizada com sucesso'),
  ('reserva', 'cancelada',    'Reserva cancelada pelo usuário ou sistema'),
  ('reserva', 'nao_compareceu','Usuário não compareceu no horário');

-- ------------------------------------------------------------
-- TipoEnergia — classificação de veículos e postos
-- Alinhado com ABVE (BEV, PHEV, HEV, MHEV, FCEV)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `TipoEnergia` (
  `id_TipoEnergia` INT          NOT NULL AUTO_INCREMENT,
  `sigla`          VARCHAR(10)  NOT NULL UNIQUE   COMMENT 'BEV, PHEV, HEV, MHEV, FCEV, AC, DC',
  `nomeTipo`       VARCHAR(60)  NOT NULL,
  `descricao`      VARCHAR(300)     NULL,
  PRIMARY KEY (`id_TipoEnergia`)
) ENGINE = InnoDB COMMENT = 'Tipos de energia/tecnologia — alinhado com classificação ABVE';

INSERT INTO `TipoEnergia` (`sigla`, `nomeTipo`, `descricao`) VALUES
  ('BEV',  'Elétrico Puro',            'Battery Electric Vehicle — 100% elétrico, recarga externa obrigatória'),
  ('PHEV', 'Híbrido Plug-in',          'Plug-in Hybrid — bateria + motor a combustão, recarga externa possível'),
  ('HEV',  'Híbrido Convencional',     'Hybrid Electric Vehicle — recarga pelo freio regenerativo, sem plug'),
  ('MHEV', 'Mild Hybrid',              'Mild Hybrid EV — assistência elétrica leve, sem recarga externa'),
  ('FCEV', 'Célula de Combustível',    'Fuel Cell EV — movido a hidrogênio, emite apenas vapor d''água'),
  ('AC',   'Corrente Alternada (AC)',   'Carregamento AC — Nível 1 (tomada) ou Nível 2 (wallbox)'),
  ('DC',   'Corrente Contínua (DC)',    'Carregamento DC rápido — CHAdeMO, CCS, Tesla Supercharger');

-- ------------------------------------------------------------
-- TipoConector — padrões físicos de tomada
-- Fonte: dados de mercado Carregados.com.br
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `TipoConector` (
  `id_TipoConector` INT          NOT NULL AUTO_INCREMENT,
  `codigo`          VARCHAR(20)  NOT NULL UNIQUE  COMMENT 'CCS2, CHADEMO, TYPE2, AC_L1, AC_L2, TESLA',
  `nome`            VARCHAR(80)  NOT NULL,
  `corrente`        ENUM('AC','DC') NOT NULL,
  `potenciaMaxKw`   DECIMAL(7,2)     NULL          COMMENT 'Potência máxima suportada em kW',
  `nivel`           VARCHAR(30)      NULL          COMMENT '1-AC lento | 2-AC semi | 3-DC rápido',
  `descricao`       VARCHAR(300)     NULL,
  PRIMARY KEY (`id_TipoConector`)
) ENGINE = InnoDB COMMENT = 'Padrões físicos de conectores EV (CCS2, CHAdeMO, Type2, etc.)';

INSERT INTO `TipoConector` (`codigo`, `nome`, `corrente`, `potenciaMaxKw`, `nivel`, `descricao`) VALUES
  ('CCS2',    'CCS Combo 2',            'DC',  350.00, 'Nível 3 — DC rápido',  'Padrão europeu DC — dominante no Brasil para carregamento rápido'),
  ('CHADEMO', 'CHAdeMO',                'DC',  100.00, 'Nível 3 — DC rápido',  'Padrão japonês DC — usado em Nissan Leaf e Mitsubishi'),
  ('TYPE2',   'Tipo 2 (Mennekes)',       'AC',   22.00, 'Nível 2 — AC',         'Padrão europeu AC — wallbox e postos semi-rápidos'),
  ('AC_L1',   'AC Nível 1 (Tomada Std)','AC',    3.70, 'Nível 1 — AC lento',   'Tomada doméstica brasileira — carregamento lento (10-20h)'),
  ('AC_L2',   'AC Nível 2 (Wallbox)',   'AC',   22.00, 'Nível 2 — AC',         'Wallbox residencial/comercial — 3-8h de recarga'),
  ('TESLA',   'Tesla Supercharger V3',  'DC',  250.00, 'Nível 3 — DC rápido',  'Conector proprietário Tesla — V3 até 250kW, adaptador CCS disponível');

-- ============================================================
-- ██████████████   TABELAS PRINCIPAIS (com timestamps)   █████
-- ============================================================
-- Regra: CriadoEm em INSERT-only data; AtualizadoEm apenas
-- onde o registro é editável no sistema.
-- ============================================================

-- ------------------------------------------------------------
-- Usuarios — cadastro de usuários da plataforma
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Usuarios` (
  `id_Usuarios`      INT           NOT NULL AUTO_INCREMENT,
  `nomeUsuario`      VARCHAR(200)  NOT NULL,
  `email`            VARCHAR(100)  NOT NULL,
  `fk_nivelUsuario`  INT               NULL,
  `ativo`            TINYINT(1)    NOT NULL DEFAULT 1,
  `criadoEm`         DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `atualizadoEm`     DATETIME(6)       NULL ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id_Usuarios`),
  UNIQUE  KEY `uq_email`          (`email`),
  INDEX         `fk_nivelUsuario_idx` (`fk_nivelUsuario`),
  CONSTRAINT `fk_usr_nivel`
    FOREIGN KEY (`fk_nivelUsuario`) REFERENCES `NivelUsuario`(`id_NivelUsuario`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Usuários da plataforma SustAmbiTech';

-- ------------------------------------------------------------
-- Enderecos — endereços normalizados (reutilizáveis)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Enderecos` (
  `id_Enderecos` INT           NOT NULL AUTO_INCREMENT,
  `logradouro`   VARCHAR(200)      NULL,
  `numero`       VARCHAR(20)       NULL,
  `complemento`  VARCHAR(100)      NULL,
  `bairro`       VARCHAR(80)       NULL,
  `cidade`       VARCHAR(80)   NOT NULL,
  `estado`       CHAR(2)       NOT NULL  COMMENT 'UF — SP, RJ, MG...',
  `pais`         VARCHAR(50)   NOT NULL  DEFAULT 'Brasil',
  `cep`          VARCHAR(10)       NULL,
  `latitude`     DECIMAL(10,8)     NULL  COMMENT 'WGS84 — ex: -23.5505',
  `longitude`    DECIMAL(11,8)     NULL  COMMENT 'WGS84 — ex: -46.6333',
  PRIMARY KEY (`id_Enderecos`),
  INDEX `idx_cidade_estado` (`cidade`, `estado`),
  INDEX `idx_latlon`        (`latitude`, `longitude`)
) ENGINE = InnoDB COMMENT = 'Endereços georreferenciados (WGS84)';

-- ------------------------------------------------------------
-- Postos — eletropostos e pontos de recarga
-- Inspirado em: carregados.com.br (11.783 estações ativas)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Postos` (
  `id_Postos`      INT           NOT NULL AUTO_INCREMENT,
  `nomePosto`      VARCHAR(200)  NOT NULL,
  `descricao`      VARCHAR(500)      NULL,
  `fk_tipoEnergia` INT               NULL  COMMENT 'Tipo predominante do posto (AC ou DC)',
  `fk_endereco`    INT           NOT NULL,
  `fk_status`      INT               NULL,
  `operador`       VARCHAR(100)      NULL  COMMENT 'Nome da rede/operadora (EZVolt, Voltta, Tesla...)',
  `acesso`         ENUM('publico','restrito','privado') NOT NULL DEFAULT 'publico',
  `requerApp`      TINYINT(1)    NOT NULL DEFAULT 0,
  `appNome`        VARCHAR(80)       NULL,
  `horario`        VARCHAR(100)      NULL  COMMENT 'Ex: "Seg-Sex 08h-22h | Sáb 09h-18h"',
  `criadoEm`       DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `atualizadoEm`   DATETIME(6)       NULL ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id_Postos`),
  INDEX `fk_posto_endereco_idx`  (`fk_endereco`),
  INDEX `fk_posto_tipo_idx`      (`fk_tipoEnergia`),
  INDEX `fk_posto_status_idx`    (`fk_status`),
  INDEX `idx_posto_acesso`       (`acesso`),
  CONSTRAINT `fk_posto_endereco`
    FOREIGN KEY (`fk_endereco`)    REFERENCES `Enderecos`(`id_Enderecos`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_posto_tipo`
    FOREIGN KEY (`fk_tipoEnergia`) REFERENCES `TipoEnergia`(`id_TipoEnergia`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_posto_status`
    FOREIGN KEY (`fk_status`)      REFERENCES `Status`(`id_Status`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Eletropostos e estações de recarga EV';

-- ------------------------------------------------------------
-- Tomadas — conectores físicos de cada posto
-- Fonte: distribuição de tipos (Carregados: CCS2 predominante)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Tomadas` (
  `id_Tomadas`       INT            NOT NULL AUTO_INCREMENT,
  `fk_posto`         INT            NOT NULL,
  `fk_tipoConector`  INT            NOT NULL,
  `fk_status`        INT                NULL,
  `potenciaKw`       DECIMAL(7, 2)      NULL  COMMENT 'Potência real instalada em kW',
  `custoPorMinuto`   DECIMAL(10, 4) NOT NULL DEFAULT 0.0000 COMMENT 'R$ por minuto de recarga',
  `custoPorKwh`      DECIMAL(10, 4)     NULL  COMMENT 'R$ por kWh (modelo alternativo)',
  `tempoRecargaMin`  SMALLINT           NULL  COMMENT 'Estimativa 0→80% em minutos',
  `quantidade`       TINYINT        NOT NULL DEFAULT 1 COMMENT 'Nº de unidades deste conector no posto',
  PRIMARY KEY (`id_Tomadas`),
  INDEX `fk_tomada_posto_idx`     (`fk_posto`),
  INDEX `fk_tomada_conector_idx`  (`fk_tipoConector`),
  INDEX `fk_tomada_status_idx`    (`fk_status`),
  CONSTRAINT `fk_tomada_posto`
    FOREIGN KEY (`fk_posto`)        REFERENCES `Postos`(`id_Postos`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tomada_conector`
    FOREIGN KEY (`fk_tipoConector`) REFERENCES `TipoConector`(`id_TipoConector`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tomada_status`
    FOREIGN KEY (`fk_status`)       REFERENCES `Status`(`id_Status`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Conectores/tomadas de cada posto com custo e tempo de recarga';

-- ------------------------------------------------------------
-- Veiculos — catálogo EV/PHEV
-- Fonte: Top models Carregados (BYD Song, Dolphin, GWM Haval H6...)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Veiculos` (
  `id_Veiculos`          INT            NOT NULL AUTO_INCREMENT,
  `marca`                VARCHAR(80)    NOT NULL,
  `modelo`               VARCHAR(80)    NOT NULL,
  `anoLancamento`        YEAR               NULL,
  `fk_tipoEnergia`       INT                NULL,
  `capacidadeBateria`    DECIMAL(6, 2)      NULL  COMMENT 'kWh da bateria principal',
  `autonomiaKm`          SMALLINT           NULL  COMMENT 'Autonomia WLTP em km',
  `precoEstimado`        DECIMAL(12, 2)     NULL  COMMENT 'Preço médio R$ no mercado BR',
  `conectoresCompativeis`VARCHAR(200)       NULL  COMMENT 'Ex: CCS2,TYPE2,AC_L2',
  `fonte`                VARCHAR(500)       NULL  COMMENT 'URL do fabricante ou ficha técnica',
  PRIMARY KEY (`id_Veiculos`),
  UNIQUE KEY `uq_veiculo` (`marca`, `modelo`, `anoLancamento`),
  INDEX `fk_veiculo_tipo_idx` (`fk_tipoEnergia`),
  CONSTRAINT `fk_veiculo_tipo`
    FOREIGN KEY (`fk_tipoEnergia`) REFERENCES `TipoEnergia`(`id_TipoEnergia`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Catálogo de veículos elétricos e híbridos — top modelos Brasil';

-- ------------------------------------------------------------
-- Usuarios_Veiculos — N:N usuário ↔ veículo (frota pessoal)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Usuarios_Veiculos` (
  `id_Usuarios_Veiculos` INT  NOT NULL AUTO_INCREMENT,
  `fk_Veiculos`          INT  NOT NULL,
  `fk_Usuarios`          INT  NOT NULL,
  `placa`                VARCHAR(10) NULL COMMENT 'Placa do veículo deste usuário',
  `principal`            TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = veículo principal do usuário',
  PRIMARY KEY (`id_Usuarios_Veiculos`),
  UNIQUE KEY `uq_usuario_placa` (`fk_Usuarios`, `placa`),
  INDEX `fk_uv_veiculo_idx`  (`fk_Veiculos`),
  INDEX `fk_uv_usuario_idx`  (`fk_Usuarios`),
  CONSTRAINT `fk_uv_veiculo`
    FOREIGN KEY (`fk_Veiculos`) REFERENCES `Veiculos`(`id_Veiculos`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_uv_usuario`
    FOREIGN KEY (`fk_Usuarios`) REFERENCES `Usuarios`(`id_Usuarios`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Frota pessoal: associação N:N usuário ↔ veículo';

-- ------------------------------------------------------------
-- Reservas — agendamento de sessão de recarga
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Reservas` (
  `id_Reservas`     INT          NOT NULL AUTO_INCREMENT,
  `fk_usuario`      INT          NOT NULL,
  `fk_posto`        INT          NOT NULL,
  `fk_tomada`       INT              NULL  COMMENT 'Tomada específica reservada (opcional)',
  `fk_status`       INT              NULL,
  `inicioPrevisto`  DATETIME(6)  NOT NULL,
  `fimPrevisto`     DATETIME(6)  NOT NULL,
  `inicioReal`      DATETIME(6)      NULL  COMMENT 'Momento real do início do carregamento',
  `fimReal`         DATETIME(6)      NULL  COMMENT 'Momento real do fim do carregamento',
  `kwhConsumidos`   DECIMAL(6,3)     NULL  COMMENT 'kWh efetivamente carregados',
  `valorCobrado`    DECIMAL(10,2)    NULL  COMMENT 'R$ cobrado na sessão',
  `criadoEm`        DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `atualizadoEm`    DATETIME(6)      NULL ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id_Reservas`),
  INDEX `fk_res_usuario_idx` (`fk_usuario`),
  INDEX `fk_res_posto_idx`   (`fk_posto`),
  INDEX `fk_res_tomada_idx`  (`fk_tomada`),
  INDEX `fk_res_status_idx`  (`fk_status`),
  INDEX `idx_res_inicio`     (`inicioPrevisto`),
  CONSTRAINT `fk_res_usuario`
    FOREIGN KEY (`fk_usuario`) REFERENCES `Usuarios`(`id_Usuarios`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_res_posto`
    FOREIGN KEY (`fk_posto`)   REFERENCES `Postos`(`id_Postos`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_res_tomada`
    FOREIGN KEY (`fk_tomada`)  REFERENCES `Tomadas`(`id_Tomadas`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_res_status`
    FOREIGN KEY (`fk_status`)  REFERENCES `Status`(`id_Status`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Agendamento e histórico de sessões de recarga';

-- ------------------------------------------------------------
-- Avaliacao — notas e comentários de usuários sobre postos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Avaliacao` (
  `id_Avaliacao` INT            NOT NULL AUTO_INCREMENT,
  `fk_usuario`   INT            NOT NULL,
  `fk_posto`     INT            NOT NULL,
  `nota`         TINYINT        NOT NULL CHECK (`nota` BETWEEN 1 AND 5),
  `comentario`   TEXT               NULL,
  `criadoEm`     DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id_Avaliacao`),
  UNIQUE KEY `uq_avaliacao` (`fk_usuario`, `fk_posto`),
  INDEX `fk_aval_posto_idx`   (`fk_posto`),
  INDEX `fk_aval_usuario_idx` (`fk_usuario`),
  CONSTRAINT `fk_aval_usuario`
    FOREIGN KEY (`fk_usuario`) REFERENCES `Usuarios`(`id_Usuarios`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_aval_posto`
    FOREIGN KEY (`fk_posto`)   REFERENCES `Postos`(`id_Postos`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Avaliações de usuários sobre postos (1-5 estrelas)';

-- ============================================================
-- ██████  TABELAS BI — dados agregados de fontes externas  ███
-- Fonte: ABVE (frotas), Carregados.com.br (estações/emplacamentos)
-- ============================================================

-- ------------------------------------------------------------
-- BI_EmplacamentosNacionais — emplacamentos BEV+PHEV por ano/estado
-- Fonte: carregados.com.br/api/public/market-data (vehicleSales)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `BI_EmplacamentosNacionais` (
  `id`            INT          NOT NULL AUTO_INCREMENT,
  `ano`           YEAR         NOT NULL,
  `estado`        CHAR(2)          NULL  COMMENT 'NULL = total nacional',
  `siglaEstado`   VARCHAR(30)      NULL  COMMENT 'Ex: "São Paulo (SP)"',
  `tecnologia`    ENUM('BEV','PHEV','HEV','MHEV','TOTAL') NOT NULL DEFAULT 'TOTAL',
  `totalVendas`   INT          NOT NULL DEFAULT 0,
  `fonte`         VARCHAR(100) NOT NULL DEFAULT 'carregados.com.br',
  `referenciaEm`  DATE             NULL  COMMENT 'Data de referência do snapshot',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_emplacamento` (`ano`, `estado`, `tecnologia`),
  INDEX `idx_emp_ano`   (`ano`),
  INDEX `idx_emp_estado`(`estado`)
) ENGINE = InnoDB COMMENT = 'Emplacamentos nacionais BEV+PHEV por ano/estado — fonte Carregados';

-- ------------------------------------------------------------
-- BI_ModelosTop — top modelos vendidos no Brasil
-- Fonte: vehicleSales.topModels (Carregados API)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `BI_ModelosTop` (
  `id`          INT           NOT NULL AUTO_INCREMENT,
  `maker`       VARCHAR(80)   NOT NULL,
  `model`       VARCHAR(80)   NOT NULL,
  `tecnologia`  ENUM('BEV','PHEV','HEV','MHEV') NOT NULL,
  `totalVendas` INT           NOT NULL DEFAULT 0,
  `posicaoRank` TINYINT           NULL,
  `referenciaEm`DATE              NULL,
  `fonte`       VARCHAR(100)  NOT NULL DEFAULT 'carregados.com.br',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_modelo_top` (`maker`, `model`),
  INDEX `idx_top_maker` (`maker`)
) ENGINE = InnoDB COMMENT = 'Top modelos elétricos vendidos no Brasil — ranking Carregados';

-- ------------------------------------------------------------
-- BI_EstacoesNacionais — infraestrutura por estado
-- Fonte: stations.byState (Carregados API)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `BI_EstacoesNacionais` (
  `id`                   INT          NOT NULL AUTO_INCREMENT,
  `estado`               VARCHAR(40)  NOT NULL,
  `siglaUF`              CHAR(2)      NOT NULL,
  `totalEstacoes`        INT          NOT NULL DEFAULT 0,
  `estacoesPublicasRapidas` INT       NOT NULL DEFAULT 0,
  `emplacamentosEV`      INT          NOT NULL DEFAULT 0,
  `veiculosPorEstacao`   DECIMAL(8,2)     NULL,
  `referenciaEm`         DATE             NULL,
  `fonte`                VARCHAR(100) NOT NULL DEFAULT 'carregados.com.br',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_estado_ref` (`siglaUF`, `referenciaEm`)
) ENGINE = InnoDB COMMENT = 'Infraestrutura de estações por estado — snapshot Carregados';

-- ------------------------------------------------------------
-- BI_FrotasABVE — dados de frotas eletrificadas (ABVE)
-- Fonte: abve.org.br/bi-frotas | abve.org.br/bi-geral
-- Representa: emplacamentos MG, emplacamentos MHEV,
--             frotas corporativas eletrificadas
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `BI_FrotasABVE` (
  `id`              INT          NOT NULL AUTO_INCREMENT,
  `periodo`         DATE         NOT NULL  COMMENT 'Competência: primeiro dia do mês (2025-01-01)',
  `categoria`       ENUM('BEV','PHEV','HEV','MHEV','FCEV','TOTAL_EV','FROTA_CORPORATIVA') NOT NULL,
  `segmento`        VARCHAR(80)      NULL  COMMENT 'Hatchback, SUV, Picape, Comercial...',
  `fabricante`      VARCHAR(80)      NULL,
  `modelo`          VARCHAR(80)      NULL,
  `estado`          CHAR(2)          NULL  COMMENT 'NULL = dados nacionais',
  `totalUnidades`   INT          NOT NULL DEFAULT 0,
  `variacaoMensal`  DECIMAL(6,2)     NULL  COMMENT '% vs mês anterior',
  `variacaoAnual`   DECIMAL(6,2)     NULL  COMMENT '% vs mesmo mês do ano anterior',
  `participacaoMkt` DECIMAL(6,4)     NULL  COMMENT 'Share de mercado (0.0000-1.0000)',
  `fonte`           VARCHAR(100) NOT NULL DEFAULT 'abve.org.br',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_frota_abve` (`periodo`, `categoria`, `fabricante`, `modelo`, `estado`),
  INDEX `idx_frota_periodo`   (`periodo`),
  INDEX `idx_frota_categoria` (`categoria`),
  INDEX `idx_frota_fabricante`(`fabricante`)
) ENGINE = InnoDB COMMENT = 'Dados de frotas eletrificadas — fonte ABVE (bi-frotas, bi-geral)';

-- ------------------------------------------------------------
-- BI_ClimaHistorico — snapshots Open-Meteo para correlação
-- Correlação: condição climática vs emplacamentos vs uso de postos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `BI_ClimaHistorico` (
  `id`                  INT            NOT NULL AUTO_INCREMENT,
  `cidade`              VARCHAR(80)    NOT NULL,
  `estado`              CHAR(2)        NOT NULL DEFAULT 'SP',
  `dataHora`            DATETIME(6)    NOT NULL,
  `temperaturaAtual`    DECIMAL(5, 2)      NULL,
  `temperaturaMax`      DECIMAL(5, 2)      NULL,
  `temperaturaMin`      DECIMAL(5, 2)      NULL,
  `sensacaoTermica`     DECIMAL(5, 2)      NULL,
  `umidadePercent`      TINYINT            NULL,
  `precipitacaoMm`      DECIMAL(6, 2)  NOT NULL DEFAULT 0.00,
  `ventoKmh`            DECIMAL(6, 2)      NULL,
  `codigoClima`         SMALLINT           NULL  COMMENT 'WMO Weather Interpretation Code',
  `condicaoClimatica`   VARCHAR(100)       NULL  COMMENT 'Descrição textual do código WMO',
  `previsaoJson`        JSON               NULL  COMMENT '[{data,tMax,tMin,precip,codigo}] próximos 7 dias',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_clima` (`cidade`, `dataHora`),
  INDEX `idx_clima_cidade_data` (`cidade`, `dataHora`)
) ENGINE = InnoDB COMMENT = 'Histórico climático Open-Meteo — usado para correlação no Power BI';

-- ============================================================
-- ████████████████   AUDITORIA (centralizada)   ██████████████
-- ============================================================

-- ------------------------------------------------------------
-- LogAuditoria — registro de todas as mudanças no banco
-- Sem CriadoEm nas tabelas principais onde LogAuditoria cobre
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `LogAuditoria` (
  `id_LogAuditoria` INT            NOT NULL AUTO_INCREMENT,
  `nomeTabela`      VARCHAR(60)    NOT NULL,
  `operacao`        ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  `registroId`      INT            NOT NULL  COMMENT 'PK do registro afetado',
  `dadosAntigos`    JSON               NULL  COMMENT 'Snapshot antes da mudança (NULL em INSERT)',
  `dadosNovos`      JSON               NULL  COMMENT 'Snapshot após a mudança (NULL em DELETE)',
  `usuarioDB`       VARCHAR(80)    NOT NULL DEFAULT (CURRENT_USER()),
  `realizadoEm`     DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id_LogAuditoria`),
  INDEX `idx_audit_tabela`  (`nomeTabela`),
  INDEX `idx_audit_data`    (`realizadoEm`),
  INDEX `idx_audit_registro`(`nomeTabela`, `registroId`)
) ENGINE = InnoDB COMMENT = 'Log centralizado de auditoria CRUD — append-only';

-- ============================================================
-- ████████████████   TRIGGERS   ██████████████████████████████
-- ============================================================
-- Estratégia: triggers de auditoria apenas nas tabelas
-- transacionais (Postos, Tomadas, Reservas, Avaliacao, Usuarios)
-- Tabelas BI e lookup não precisam de auditoria de linha.
-- ============================================================

DELIMITER $$

-- ── Postos ──────────────────────────────────────────────────
CREATE TRIGGER `trg_Postos_afterInsert`
AFTER INSERT ON `Postos` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosNovos`)
  VALUES('Postos','INSERT',NEW.id_Postos,JSON_OBJECT(
    'nomePosto',NEW.nomePosto,'fk_tipoEnergia',NEW.fk_tipoEnergia,
    'fk_endereco',NEW.fk_endereco,'fk_status',NEW.fk_status,'acesso',NEW.acesso));
END$$

CREATE TRIGGER `trg_Postos_afterUpdate`
AFTER UPDATE ON `Postos` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosAntigos`,`dadosNovos`)
  VALUES('Postos','UPDATE',NEW.id_Postos,
    JSON_OBJECT('nomePosto',OLD.nomePosto,'fk_status',OLD.fk_status,'acesso',OLD.acesso),
    JSON_OBJECT('nomePosto',NEW.nomePosto,'fk_status',NEW.fk_status,'acesso',NEW.acesso));
END$$

CREATE TRIGGER `trg_Postos_afterDelete`
AFTER DELETE ON `Postos` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosAntigos`)
  VALUES('Postos','DELETE',OLD.id_Postos,JSON_OBJECT(
    'nomePosto',OLD.nomePosto,'fk_endereco',OLD.fk_endereco,'acesso',OLD.acesso));
END$$

-- ── Tomadas ─────────────────────────────────────────────────
CREATE TRIGGER `trg_Tomadas_afterInsert`
AFTER INSERT ON `Tomadas` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosNovos`)
  VALUES('Tomadas','INSERT',NEW.id_Tomadas,JSON_OBJECT(
    'fk_posto',NEW.fk_posto,'fk_tipoConector',NEW.fk_tipoConector,
    'potenciaKw',NEW.potenciaKw,'custoPorMinuto',NEW.custoPorMinuto,'fk_status',NEW.fk_status));
END$$

CREATE TRIGGER `trg_Tomadas_afterUpdate`
AFTER UPDATE ON `Tomadas` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosAntigos`,`dadosNovos`)
  VALUES('Tomadas','UPDATE',NEW.id_Tomadas,
    JSON_OBJECT('fk_status',OLD.fk_status,'custoPorMinuto',OLD.custoPorMinuto),
    JSON_OBJECT('fk_status',NEW.fk_status,'custoPorMinuto',NEW.custoPorMinuto));
END$$

CREATE TRIGGER `trg_Tomadas_afterDelete`
AFTER DELETE ON `Tomadas` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosAntigos`)
  VALUES('Tomadas','DELETE',OLD.id_Tomadas,JSON_OBJECT(
    'fk_posto',OLD.fk_posto,'fk_tipoConector',OLD.fk_tipoConector));
END$$

-- ── Reservas ────────────────────────────────────────────────
CREATE TRIGGER `trg_Reservas_afterInsert`
AFTER INSERT ON `Reservas` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosNovos`)
  VALUES('Reservas','INSERT',NEW.id_Reservas,JSON_OBJECT(
    'fk_usuario',NEW.fk_usuario,'fk_posto',NEW.fk_posto,
    'inicioPrevisto',NEW.inicioPrevisto,'fimPrevisto',NEW.fimPrevisto,'fk_status',NEW.fk_status));
END$$

CREATE TRIGGER `trg_Reservas_afterUpdate`
AFTER UPDATE ON `Reservas` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosAntigos`,`dadosNovos`)
  VALUES('Reservas','UPDATE',NEW.id_Reservas,
    JSON_OBJECT('fk_status',OLD.fk_status,'inicioReal',OLD.inicioReal,'fimReal',OLD.fimReal),
    JSON_OBJECT('fk_status',NEW.fk_status,'inicioReal',NEW.inicioReal,'fimReal',NEW.fimReal,'kwhConsumidos',NEW.kwhConsumidos,'valorCobrado',NEW.valorCobrado));
END$$

-- ── Avaliacao ───────────────────────────────────────────────
CREATE TRIGGER `trg_Avaliacao_afterInsert`
AFTER INSERT ON `Avaliacao` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosNovos`)
  VALUES('Avaliacao','INSERT',NEW.id_Avaliacao,JSON_OBJECT(
    'fk_usuario',NEW.fk_usuario,'fk_posto',NEW.fk_posto,'nota',NEW.nota));
END$$

CREATE TRIGGER `trg_Avaliacao_afterDelete`
AFTER DELETE ON `Avaliacao` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosAntigos`)
  VALUES('Avaliacao','DELETE',OLD.id_Avaliacao,JSON_OBJECT(
    'fk_usuario',OLD.fk_usuario,'fk_posto',OLD.fk_posto,'nota',OLD.nota));
END$$

-- ── Usuarios ────────────────────────────────────────────────
CREATE TRIGGER `trg_Usuarios_afterUpdate`
AFTER UPDATE ON `Usuarios` FOR EACH ROW
BEGIN
  INSERT INTO `LogAuditoria`(`nomeTabela`,`operacao`,`registroId`,`dadosAntigos`,`dadosNovos`)
  VALUES('Usuarios','UPDATE',NEW.id_Usuarios,
    JSON_OBJECT('nomeUsuario',OLD.nomeUsuario,'email',OLD.email,'fk_nivelUsuario',OLD.fk_nivelUsuario,'ativo',OLD.ativo),
    JSON_OBJECT('nomeUsuario',NEW.nomeUsuario,'email',NEW.email,'fk_nivelUsuario',NEW.fk_nivelUsuario,'ativo',NEW.ativo));
END$$

DELIMITER ;

-- ============================================================
-- ████████████████   VIEWS PARA POWER BI   ███████████████████
-- ============================================================

-- Resumo por cidade (KPIs mapa)
CREATE OR REPLACE VIEW `vw_resumo_cidade` AS
SELECT
  e.cidade, e.estado,
  COUNT(DISTINCT p.id_Postos)                                     AS total_postos,
  SUM(CASE WHEN s.nomeStatus = 'ativo' THEN 1 ELSE 0 END)        AS postos_ativos,
  SUM(CASE WHEN p.acesso = 'publico'   THEN 1 ELSE 0 END)        AS postos_publicos,
  COUNT(DISTINCT t.id_Tomadas)                                    AS total_tomadas,
  ROUND(AVG(a.nota), 2)                                           AS media_nota,
  ROUND(AVG(t.custoPorMinuto), 4)                                 AS custo_medio_min,
  GROUP_CONCAT(DISTINCT tc.codigo ORDER BY tc.codigo SEPARATOR ',') AS conectores_disponiveis,
  AVG(e.latitude)                                                 AS lat_media,
  AVG(e.longitude)                                                AS lon_media
FROM `Postos` p
JOIN `Enderecos` e         ON p.fk_endereco   = e.id_Enderecos
LEFT JOIN `Status` s       ON p.fk_status     = s.id_Status
LEFT JOIN `Tomadas` t      ON t.fk_posto      = p.id_Postos
LEFT JOIN `TipoConector` tc ON t.fk_tipoConector = tc.id_TipoConector
LEFT JOIN `Avaliacao` a    ON a.fk_posto      = p.id_Postos
GROUP BY e.cidade, e.estado;

-- Custo por posto/tomada (filtro Power BI: menor custo por região)
CREATE OR REPLACE VIEW `vw_custo_por_posto` AS
SELECT
  p.id_Postos, p.nomePosto, p.acesso, p.operador, p.horario,
  e.cidade, e.estado, e.bairro, e.latitude, e.longitude,
  te.sigla    AS tipo_energia,
  tc.codigo   AS tipo_conector,
  t.potenciaKw, t.custoPorMinuto, t.custoPorKwh, t.tempoRecargaMin,
  ROUND(t.custoPorMinuto * t.tempoRecargaMin, 2)  AS custo_recarga_estimado,
  s_t.nomeStatus AS status_tomada,
  ROUND(AVG(a.nota), 2)   AS media_nota,
  COUNT(a.id_Avaliacao)   AS total_avaliacoes
FROM `Postos` p
JOIN `Enderecos` e          ON p.fk_endereco      = e.id_Enderecos
LEFT JOIN `TipoEnergia` te  ON p.fk_tipoEnergia   = te.id_TipoEnergia
JOIN `Tomadas` t            ON t.fk_posto         = p.id_Postos
JOIN `TipoConector` tc      ON t.fk_tipoConector  = tc.id_TipoConector
LEFT JOIN `Status` s_t      ON t.fk_status        = s_t.id_Status
LEFT JOIN `Avaliacao` a     ON a.fk_posto         = p.id_Postos
GROUP BY p.id_Postos, t.id_Tomadas;

-- Emplacamentos × infraestrutura por estado (Power BI mapa nacional)
CREATE OR REPLACE VIEW `vw_mercado_nacional` AS
SELECT
  en.siglaUF, en.estado,
  en.totalEstacoes, en.estacoesPublicasRapidas, en.emplacamentosEV,
  en.veiculosPorEstacao,
  COALESCE(SUM(CASE WHEN em.tecnologia='BEV'  THEN em.totalVendas END), 0) AS vendas_bev,
  COALESCE(SUM(CASE WHEN em.tecnologia='PHEV' THEN em.totalVendas END), 0) AS vendas_phev,
  en.referenciaEm
FROM `BI_EstacoesNacionais` en
LEFT JOIN `BI_EmplacamentosNacionais` em
  ON en.siglaUF = em.estado AND en.referenciaEm = em.referenciaEm
GROUP BY en.siglaUF, en.estado, en.totalEstacoes, en.estacoesPublicasRapidas,
         en.emplacamentosEV, en.veiculosPorEstacao, en.referenciaEm;

-- Top modelos × tipo de energia
CREATE OR REPLACE VIEW `vw_top_modelos` AS
SELECT
  mt.maker AS fabricante, mt.model AS modelo, mt.tecnologia,
  mt.totalVendas, mt.posicaoRank,
  ROUND(mt.totalVendas * 100.0 / SUM(mt.totalVendas) OVER(), 2) AS share_pct,
  mt.referenciaEm
FROM `BI_ModelosTop` mt
ORDER BY mt.posicaoRank;

-- Frotas ABVE por período/categoria (série temporal)
CREATE OR REPLACE VIEW `vw_frotas_abve` AS
SELECT
  DATE_FORMAT(fa.periodo, '%Y-%m') AS competencia,
  fa.categoria, fa.segmento, fa.fabricante, fa.modelo,
  fa.estado, fa.totalUnidades,
  fa.variacaoMensal, fa.variacaoAnual, fa.participacaoMkt
FROM `BI_FrotasABVE` fa
ORDER BY fa.periodo DESC, fa.categoria, fa.totalUnidades DESC;

-- Reservas com KPIs de uso por posto
CREATE OR REPLACE VIEW `vw_uso_postos` AS
SELECT
  p.id_Postos, p.nomePosto, e.cidade, e.estado,
  COUNT(r.id_Reservas)                     AS total_reservas,
  SUM(CASE WHEN s.nomeStatus='concluida'   THEN 1 ELSE 0 END) AS concluidas,
  SUM(CASE WHEN s.nomeStatus='cancelada'   THEN 1 ELSE 0 END) AS canceladas,
  ROUND(AVG(r.kwhConsumidos), 2)           AS kwh_medio,
  ROUND(SUM(r.valorCobrado), 2)            AS receita_total,
  ROUND(AVG(r.valorCobrado), 2)            AS ticket_medio
FROM `Postos` p
JOIN `Enderecos` e    ON p.fk_endereco = e.id_Enderecos
LEFT JOIN `Reservas` r ON r.fk_posto   = p.id_Postos
LEFT JOIN `Status` s   ON r.fk_status  = s.id_Status
GROUP BY p.id_Postos, p.nomePosto, e.cidade, e.estado;

-- ============================================================
-- SEED INICIAL — Usuários do time
-- ============================================================
INSERT INTO `Usuarios` (`nomeUsuario`, `email`, `fk_nivelUsuario`) VALUES
  ('Kayham Cristoffer', 'kayhamoliveira98@gmail.com', 1),  -- admin
  ('Gabriel',           'gabriel@sustambitech.dev',  2),  -- operador
  ('Eric Jr',           'eric@sustambitech.dev',     2),  -- operador
  ('Natan',             'natan@sustambitech.dev',    2),  -- operador
  ('Leandro',           'leandro@sustambitech.dev',  2);  -- operador

-- Seed BI_EstacoesNacionais (snapshot 2026-08-31 — Carregados API)
INSERT INTO `BI_EstacoesNacionais`
  (`estado`,`siglaUF`,`totalEstacoes`,`estacoesPublicasRapidas`,`emplacamentosEV`,`veiculosPorEstacao`,`referenciaEm`)
VALUES
  ('São Paulo',           'SP', 2641, 1814, 167465, 92.32, '2026-08-31'),
  ('Minas Gerais',        'MG', 1055,  760,  41045, 54.01, '2026-08-31'),
  ('Rio Grande do Sul',   'RS', 1031,  799,  34247, 42.86, '2026-08-31'),
  ('Santa Catarina',      'SC',  959,  707,  36933, 52.24, '2026-08-31'),
  ('Paraná',              'PR',  861,  672,  42642, 63.46, '2026-08-31'),
  ('Rio de Janeiro',      'RJ',  825,  419,  36027, 85.98, '2026-08-31'),
  ('Goiás',               'GO',  544,  409,  18210, 44.52, '2026-08-31'),
  ('Bahia',               'BA',  532,  392,  22876, 58.36, '2026-08-31'),
  ('Pernambuco',          'PE',  431,  336,  21309, 63.42, '2026-08-31'),
  ('Ceará',               'CE',  426,  334,  15674, 46.93, '2026-08-31'),
  ('Distrito Federal',    'DF',  424,  318,  55408,174.24, '2026-08-31');

-- Seed BI_ModelosTop (top 10 — Carregados API 2026-08-31)
INSERT INTO `BI_ModelosTop`(`maker`,`model`,`tecnologia`,`totalVendas`,`posicaoRank`,`referenciaEm`) VALUES
  ('BYD',         'Song',       'PHEV', 96070,  1, '2026-08-31'),
  ('BYD',         'Dolphin Mini','BEV', 95221,  2, '2026-08-31'),
  ('BYD',         'Dolphin',    'BEV',  61590,  3, '2026-08-31'),
  ('GWM',         'Haval H6',   'PHEV', 54900,  4, '2026-08-31'),
  ('BYD',         'King',       'PHEV', 27158,  5, '2026-08-31'),
  ('Geely',       'EX2',        'BEV',  23119,  6, '2026-08-31'),
  ('BYD',         'Song Plus',  'PHEV', 18989,  7, '2026-08-31'),
  ('Volvo',       'XC60',       'PHEV', 14671,  8, '2026-08-31'),
  ('Omoda Jaecoo','Jaecoo 7',   'PHEV', 13716,  9, '2026-08-31'),
  ('GWM',         'ORA 03',     'BEV',  12482, 10, '2026-08-31');

-- Seed BI_EmplacamentosNacionais (série 2022-2026 — Carregados API)
INSERT INTO `BI_EmplacamentosNacionais`(`ano`,`estado`,`tecnologia`,`totalVendas`,`referenciaEm`) VALUES
  (2022, NULL, 'TOTAL',  19960, '2026-08-31'),
  (2023, NULL, 'TOTAL',  52359, '2026-08-31'),
  (2024, NULL, 'TOTAL', 125625, '2026-08-31'),
  (2025, NULL, 'TOTAL', 180175, '2026-08-31'),
  (2026, NULL, 'TOTAL', 213288, '2026-08-31');

-- ============================================================
-- RESTAURAR CONFIGURAÇÕES
-- ============================================================
SET SQL_MODE              = @OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS    = @OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS         = @OLD_UNIQUE_CHECKS;

-- ============================================================
-- VERIFICAÇÃO FINAL
-- ============================================================
SELECT
  TABLE_NAME                             AS tabela,
  TABLE_COMMENT                          AS descricao,
  TABLE_ROWS                             AS linhas_estimadas
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'sustambitech'
  AND TABLE_TYPE   = 'BASE TABLE'
ORDER BY TABLE_NAME;
