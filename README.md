# 🌱 SustAmbiTech BI — Plataforma de Inteligência Ambiental

## Visão Geral

Extensão do projeto [SustAmbiTech](https://github.com/KayhamCristoffer/SustAmbiTech) com banco de dados completo, APIs REST e dashboard de Business Intelligence para análise de dados ambientais com Power BI.

## 🔗 URLs

- **Dashboard:** https://sustambitech-bi.pages.dev *(após deploy)*
- **Mapa Mental:** /mindmap
- **API Docs:** /api/schema
- **Repositório Base:** https://github.com/KayhamCristoffer/SustAmbiTech

## 🚀 Funcionalidades Implementadas

| Módulo | Descrição | Status |
|--------|-----------|--------|
| Dashboard BI | KPIs, gráficos e indicadores em tempo real | ✅ |
| Mapa Mental | Análise visual do projeto com sugestões | ✅ |
| Qualidade do Ar | PM2.5, PM10, CO2, IQA por região | ✅ |
| Qualidade da Água | pH, turbidez, IQA de corpos hídricos | ✅ |
| Energia | Consumo por fonte, emissões CO2 | ✅ |
| Reciclagem | Volume por tipo, CO2 evitado, ecopontos | ✅ |
| Veículos Elétricos | Frota, eletropostos, evolução anual | ✅ |
| Indicadores Climáticos | Temperatura, precipitação, anomalias | ✅ |
| Cobertura Vegetal | Desmatamento, reflorestamento, carbono | ✅ |
| Educação Ambiental | Atividades, pontuações, certificados | ✅ |
| Denúncias | Geolocalização, status, impacto | ✅ |
| KPIs & Metas | ODS ONU, percentual de atingimento | ✅ |
| Exportação Power BI | 19 endpoints JSON/CSV para integração | ✅ |

## 🗄️ Banco de Dados (Cloudflare D1 - Gratuito)

### Modelo Estrela para Power BI

**Tabelas Dimensão (5):**
- `dim_regioes` — Cidades/estados do Brasil
- `dim_categorias` — Áreas temáticas de sustentabilidade
- `dim_usuarios` — Perfis de usuários da plataforma
- `dim_tipos_residuos` — Classificação de resíduos sólidos
- `dim_fontes_energia` — Tipos de fontes de energia

**Tabelas Fato (12):**
- `fato_qualidade_ar` — Indicadores PM2.5, PM10, CO2, IQA
- `fato_qualidade_agua` — pH, turbidez, IQA de corpos hídricos
- `fato_consumo_energia` — Consumo por fonte/região/setor
- `fato_reciclagem` — Coletas, destino, CO2 evitado
- `fato_veiculos_eletricos` — Frota e eletropostos
- `fato_indicadores_climaticos` — Temperatura, chuva, eventos
- `fato_cobertura_vegetal` — Desmatamento e reflorestamento
- `fato_educacao_ambiental` — Atividades e engajamento
- `fato_denuncias` — Ocorrências ambientais
- `fato_consumo_consciente` — Análise de produtos ecológicos
- `fato_politicas_ambientais` — Legislação ambiental
- `fato_ecopontos` — Pontos de coleta georreferenciados

**Tabelas de Suporte (3):**
- `tb_kpis_metas` — Metas e ODS da ONU
- `tb_alertas` — Notificações e alertas
- `tb_logs_atividade` — Auditoria de ações

## 📊 APIs para Power BI (19 endpoints)

```
GET /api/kpis                       → KPIs gerais
GET /api/qualidade-ar?format=csv    → Dados de qualidade do ar
GET /api/qualidade-agua?format=csv  → Dados de qualidade da água
GET /api/energia/por-fonte          → Consumo agrupado por fonte
GET /api/energia?format=csv         → Série histórica de energia
GET /api/reciclagem/por-tipo        → Volume por tipo de resíduo
GET /api/reciclagem?format=csv      → Todas as coletas
GET /api/veiculos-eletricos/evolucao → Crescimento anual da frota
GET /api/veiculos-eletricos?format=csv → Dados por região
GET /api/clima?format=csv           → Indicadores climáticos
GET /api/cobertura-vegetal?format=csv → Desmatamento
GET /api/denuncias?format=csv       → Denúncias ambientais
GET /api/ecopontos?format=csv       → Pontos de coleta
GET /api/metas?format=csv           → KPIs e metas
GET /api/alertas                    → Alertas ativos
GET /api/bi/resumo-regional?format=csv → Visão por cidade
GET /api/bi/tendencias              → Série mensal
GET /api/bi/emissoes-co2            → CO2 por fonte/região
GET /api/bi/ranking-denuncias       → Taxa de resolução
```

## 🔧 Configuração Local

```bash
# 1. Clonar repositório
git clone https://github.com/KayhamCristoffer/SustAmbiTechBI.io

# 2. Instalar dependências
npm install

# 3. Criar banco de dados local e aplicar migrations
npm run db:migrate:local

# 4. Inserir dados de exemplo
npm run db:seed:local

# 5. Build e iniciar servidor
npm run build
pm2 start ecosystem.config.cjs
```

## 🌐 Integração com Power BI

1. Abra o **Power BI Desktop**
2. **Obter Dados → Web**
3. Insira a URL do endpoint desejado (ex: `https://sustambitech-bi.pages.dev/api/reciclagem?format=csv`)
4. Para JSON: use o conector Web padrão
5. Para CSV: use o conector de arquivo de texto/CSV
6. Configure **atualização agendada** para dados sempre frescos

## 🛠️ Stack Técnico

- **Backend:** Hono + TypeScript (Cloudflare Workers)
- **Banco de Dados:** Cloudflare D1 (SQLite gratuito, 5GB)
- **Frontend:** HTML/CSS/JS + Chart.js + Tailwind CSS
- **Deploy:** Cloudflare Pages
- **Build:** Vite

## 👥 Integrantes

- Caio Porto Santos — ADS
- Erick Alves Bezerra — ADS
- Kayham Cristoffer G. de Oliveira — CCD
- Vitor Leonardo Vasconcelos — ADS

## 📅 Atualização

**Última atualização:** 2025-08  
**Status:** ✅ Ativo
