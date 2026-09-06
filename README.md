# SustAmbiTech BI — Plataforma de Mobilidade Elétrica no Brasil

> **Grupo SustAmbiTechBI** · GitHub Pages · v5.1 · 2026

---

## 🔗 Links

| | URL |
|---|---|
| **Site (GitHub Pages)** | https://kayhamcristoffer.github.io/SustAmbiTechBI.io/ |
| **Repositório BI** | https://github.com/KayhamCristoffer/SustAmbiTechBI.io |
| **Projeto Original** | https://github.com/KayhamCristoffer/SustAmbiTech |
| **Issues / Contato** | https://github.com/KayhamCristoffer/SustAmbiTechBI.io/issues |

---

## 👥 Integrantes

| Nome | RA | Curso |
|---|---|---|
| Kayham C. G. de Oliveira | 232000577 | CCO |
| Gabriel Luz Gomes da Silva | 251004471 | ADS |
| Eric Junior Santos | 251004675 | ADS |
| Natan Arroyo | 252005106 | ADS |
| Leandro Gama dos Santos | 252005142 | ADS |

---

## ✅ Funcionalidades Implementadas

### Dashboard Power BI
- 4 painéis embarcados diretamente no portal via `<iframe>` (sem abrir site externo)
- Abas com `setPBITab()` trocam o `src` do iframe: Frotas ABVE, Eletromobilidade, Eletrificados+MHEV, SustAmbiTech BI
- Botão de abrir em nova aba apenas no ícone externo

### Mapa de Estações de Recarga
- Iframe espelho do **Carregados.com.br/mapa** (dados reais, 11.783 estações)
- Filtros por estado: Nacional, SP, MG, RJ, RS, PR, SC
- Geolocalização: botão "Minha Localização" solicita permissão GPS e centraliza o mapa
- Fallback automático para **MapLibre GL + OpenFreeMap** (sem API key) se o iframe for bloqueado por CSP

### Buscador de Clima (Botão Flutuante)
- Botão FAB fixo no canto inferior direito da tela (todas as páginas)
- Abre painel deslizante com busca por cidade ou geolocalização automática
- API: **Open-Meteo** (100% gratuita, sem chave)
- Exibe: temperatura, sensação, umidade, vento, pressão, UV, radiação, precipitação
- Previsão de **7 dias** com ícones por código WMO
- Cidades rápidas: SP, RJ, Curitiba, BH, Brasília, POA, Fortaleza, Salvador

### Páginas SPA
| Página | Descrição |
|---|---|
| **Início (Home)** | Hero, KPIs animados, faixa ABVE, Dashboard PBI, Mapa, Time |
| **Sobre** | História, missão, metodologia, processo de desenvolvimento, equipe |
| **Serviços** | Dashboards PBI, Mapa, Clima, Análise por Estado, ABVE, Código Aberto, Responsivo |
| **Contato** | GitHub Issues, repositório, projeto original, cards dos integrantes |
| **Fontes** | ABVE, Carregados, ANEEL, IBGE, Open-Meteo, OpenFreeMap |
| **Políticas** | Privacidade, cookies, uso de dados, código de conduta |

---

## 📊 Fontes de Dados

| Fonte | Dados | Acesso |
|---|---|---|
| **ABVE** | Emplacamentos, frotas, BEV/PHEV/HEV/MHEV/FCEV | Power BI embed (gratuito) |
| **Carregados.com.br** | 11.783 estações de recarga | Iframe + API pública |
| **Open-Meteo** | Clima em tempo real + previsão 7 dias | REST API (sem chave) |
| **OpenFreeMap** | Tiles de mapa vetorial | CDN (sem chave) |
| **MapLibre GL** | Renderização de mapas WebGL | CDN (open source) |

---

## 🏗️ Arquitetura

```
SustAmbiTechBI.io/
├── index.html          # Portal estático completo (SPA vanilla JS)
├── src/
│   └── index.tsx       # Hono backend (Cloudflare Workers/Pages)
├── public/
│   └── static/         # Assets estáticos
├── README.md           # Este arquivo
└── package.json        # Scripts de build e deploy
```

**Stack tecnológica:**
- **Frontend**: HTML5 + CSS3 + Vanilla JS (SPA sem framework)
- **Estilo**: Custom CSS dark theme + Google Fonts (Orbitron + Inter) + FontAwesome 6
- **Mapa**: MapLibre GL JS + OpenFreeMap tiles
- **Backend (opcional)**: Hono + TypeScript + Cloudflare Pages
- **Hospedagem portal**: GitHub Pages (estático)
- **Hospedagem backend**: Cloudflare Pages / Workers

---

## 🚀 Deploy

### GitHub Pages (portal estático)
O arquivo `index.html` na raiz é servido diretamente pelo GitHub Pages.  
Nenhuma build necessária — é HTML puro.

```bash
git add index.html
git commit -m "update"
git push origin main
```

### Cloudflare Pages (backend Hono)
```bash
npm run build
npx wrangler pages deploy dist --project-name sustambitech-bi
```

---

## 📝 Histórico de Versões

| Versão | Commit | Mudanças |
|---|---|---|
| v5.1 | atual | `scrollToSection()` sem conflito com `window.scrollTo`; FAB clima corrigido no footer; goHome() garante scroll ao topo; avatares SVG todos os membros com RA |
| v5.0 | `6ce59b5` | Botão FAB clima, iframe Carregados + geoloc, avatares SVG com RAs, página Contato, nav corrigida |
| v4.0 | `42484d6` | Páginas Sobre/Serviços/Fontes/Políticas, setPBITab() iframe, setMap() Carregados |
| v3.0 | `a1eebd2` | Redesign dark theme, Power BI embed, Leaflet map, equipe |
| v2.0 | `5c28267` | Supabase → MySQL, schema inicial |
| v1.0 | `f2cafd6` | Setup inicial Hono + Cloudflare |

---

## 📄 Licença

Projeto acadêmico — código aberto para fins educacionais.  
Dados de terceiros (ABVE, Carregados.com.br) pertencem às suas respectivas fontes.
