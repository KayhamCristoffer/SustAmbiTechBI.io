# ⚡ SustAmbiTech Eletropostos

**Plataforma de Postos de Recarga para Veículos Elétricos e Híbridos — Grande São Paulo**

Desenvolvido por **Kayham** | Migração completa Firebase → Cloudflare D1

---

## 🌟 Funcionalidades Implementadas

| Página | URL | Descrição |
|--------|-----|-----------|
| Dashboard | `/` | KPIs em tempo real, tabela de postos, clima, gráficos |
| Mapa Interativo | `/mapa` | Leaflet.js com 57+ pins e filtros |
| Importar Excel | `/admin/upload` | Upload `.xlsx` com SheetJS, preview e log |
| Mapa Mental BI | `/mindmap` | SVG interativo: caixas vermelhas=tabelas, círculos=site |
| Tutorial Deploy | `/tutorial` | Guia passo a passo gratuito CF Pages + D1 |

### APIs REST

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/api/postos` | GET | Lista postos com filtros (cidade, tipo, conector) |
| `/api/postos/:id` | GET | Detalhes + avaliações de um posto |
| `/api/resumo` | GET | KPIs: total, por cidade, conectores, tipos |
| `/api/mapa` | GET | Dados geoespaciais para Leaflet |
| `/api/conectores` | GET | Tipos de tomada (CCS2, CHAdeMO, Type2, AC) |
| `/api/veiculos` | GET | Tipos de veículos e compatibilidade |
| `/api/regioes` | GET | Cidades com contagem de postos |
| `/api/avaliacoes` | GET/POST | Avaliações dos postos |
| `/api/clima` | GET | Temperatura atual + histórico (OpenMeteo) |
| `/api/bi/resumo-regional` | GET | Resumo por cidade para Power BI |
| `/api/bi/conectores-distribuicao` | GET | Distribuição de conectores para Power BI |
| `/api/bi/postos-full` | GET | Todos os postos detalhados para Power BI |
| `/api/upload/postos` | POST | Importação de registros via JSON/Excel |
| `/api/log` | GET | Histórico de importações |
| `/api/schema` | GET | Documentação do schema |

> Todos os endpoints de BI suportam `?format=csv` para exportação direta ao Power BI.

---

## 🗄️ Banco de Dados — Cloudflare D1 (SQLite)

### Tabelas Principais

```
postos_recarga       → 57 postos reais migrados do Firebase
dim_conectores       → CCS2, CHAdeMO, Type2, AC_L1, AC_L2, Tesla
postos_conectores    → Relação N:N postos × tomadas
dim_tipos_veiculos   → BEV, PHEV, HEV, FCEV
veiculos_conectores  → Matriz de compatibilidade veículo × conector
dim_regioes          → 5 cidades da Grande SP
dim_operadores       → Redes: EZVolt, Volvo, Estapar, Porto Seguro...
usuarios             → 5 usuários migrados do Firebase
avaliacoes_postos    → Avaliações com nota 1-5
feedbacks            → 2 feedbacks migrados do Firebase
clima_historico      → Histórico de temperatura São Paulo
log_importacoes      → Auditoria de uploads Excel
kpis_ev              → Metas de infraestrutura elétrica
```

### Views (para Power BI)

- `vw_resumo_cidades` — Contagem e métricas por cidade
- `vw_postos_detalhado` — Postos com conectores e avaliações

### Planos Cloudflare D1

| | **Gratuito (Free)** | **Pago (US$5/mês)** |
|---|---|---|
| Storage | 5 GB | 25 GB |
| Leituras/dia | 5 milhões | 25 milhões |
| Escritas/dia | 100 mil | 500 mil |
| CPU/request | 10ms | 30ms |

---

## 🚀 Setup e Deploy

### Desenvolvimento Local (sem conta Cloudflare)

```bash
# 1. Instalar dependências
npm install

# 2. Build
npm run build

# 3. Criar banco local e popular dados
npm run db:schema:local
npm run db:seed:local

# 4. Iniciar servidor
npm run dev:pm2
# Acesse: http://localhost:3000
```

### Deploy em Produção (Cloudflare — 100% Gratuito)

```bash
# 1. Login na Cloudflare
npx wrangler login

# 2. Criar banco D1 de produção
npm run db:create:prod
# → Copie o database_id e cole no wrangler.jsonc

# 3. Popular banco de produção
npm run db:schema:prod
npm run db:seed:prod

# 4. Deploy
npm run deploy
```

### Vincular D1 ao Pages (obrigatório)

No dashboard Cloudflare:
1. **Workers & Pages** → seu projeto → **Settings** → **Functions**
2. **D1 database bindings** → Add binding
3. Variable name: `DB` | Database: `sustambitech-production`
4. **Save** → **Redeploy**

---

## 📊 Power BI Integration

No Power BI Desktop → **Obter Dados → Web** → cole a URL:

```
https://seu-projeto.pages.dev/api/bi/resumo-regional?format=csv
https://seu-projeto.pages.dev/api/bi/conectores-distribuicao?format=csv
https://seu-projeto.pages.dev/api/bi/postos-full?format=csv
```

---

## 📥 Importar Excel

Acesse `/admin/upload` e faça upload de um `.xlsx` com as colunas:

| Coluna | Obrigatório | Exemplo |
|--------|-------------|---------|
| nome | ✅ | Eletroposto Centro |
| cidade | ✅ | São Paulo |
| latitude | ✅ | -23.5505 |
| longitude | ✅ | -46.6333 |
| rua | — | Av. Paulista |
| numero | — | 1000 |
| bairro | — | Bela Vista |
| estado | — | SP |
| cep | — | 01310-100 |
| tipo_ponto | — | Posto Eletro |
| acesso | — | público |
| horario_funcionamento | — | 24h |

Baixe o template em `/admin/upload` → botão **Template**.

---

## 🌡️ Widget de Clima

Dados fornecidos pela API gratuita [Open-Meteo](https://open-meteo.com/):
- Temperatura atual em São Paulo
- Previsão dos próximos 7 dias
- Histórico de temperaturas (banco D1 local)

---

## 🛠️ Stack Tecnológica

| Camada | Tecnologia |
|--------|-----------|
| Backend | Hono v4 + TypeScript |
| Banco | Cloudflare D1 (SQLite) |
| Hospedagem | Cloudflare Pages |
| Build | Vite + @hono/vite-cloudflare-pages |
| Mapa | Leaflet.js 1.9.4 |
| Gráficos | Chart.js |
| Excel | SheetJS (xlsx) |
| CSS | Tailwind CSS CDN |
| Clima | Open-Meteo API (free) |
| Runtime local | Wrangler + PM2 |

---

## 📁 Estrutura do Projeto

```
webapp/
├── src/
│   └── index.tsx              # App principal Hono — todas as rotas
├── public/
│   └── static/
│       ├── dashboard.js       # JS do dashboard (Chart.js, filtros)
│       ├── mapa.js            # JS do mapa Leaflet
│       └── upload.js          # JS do upload Excel (SheetJS)
├── migrations/
│   └── 0001_initial_schema.sql  # Schema completo (13 tabelas, 2 views)
├── seed.sql                   # 57 postos + 5 usuários + dados de ref.
├── wrangler.jsonc             # Config Cloudflare (comentada, free/paid)
├── package.json               # Scripts completos
├── ecosystem.config.cjs       # PM2 para desenvolvimento local
├── vite.config.ts             # Build config
└── tsconfig.json              # TypeScript config
```

---

## 🔗 Links

- **GitHub**: https://github.com/KayhamCristoffer/SustAmbiTechBI.io
- **Cloudflare**: https://dash.cloudflare.com (para deploy)
- **Tutorial completo**: `/tutorial` (no próprio site)

---

## 👤 Créditos

**Desenvolvido por Kayham** — Projeto SustAmbiTech  
Foco: Mobilidade Elétrica e Sustentabilidade Urbana na Grande São Paulo

*Dados migrados do Firebase Realtime Database — 57 postos reais cadastrados*
