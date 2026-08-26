import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { serveStatic } from 'hono/cloudflare-workers'

type Bindings = { DB: D1Database }
const app = new Hono<{ Bindings: Bindings }>()

app.use('/api/*', cors())
app.use('/static/*', serveStatic({ root: './public' }))

// ============================================================
// HELPERS
// ============================================================
function toCsv(rows: Record<string, unknown>[]): string {
  if (!rows.length) return ''
  const keys = Object.keys(rows[0])
  const lines = [keys.join(','), ...rows.map(r => keys.map(k => `"${String(r[k] ?? '').replace(/"/g, '""')}"`).join(','))]
  return lines.join('\n')
}
function jsonOrCsv(c: any, rows: Record<string, unknown>[]) {
  if (c.req.query('format') === 'csv') {
    c.header('Content-Type', 'text/csv; charset=utf-8')
    c.header('Content-Disposition', 'attachment; filename="export.csv"')
    return c.body(toCsv(rows))
  }
  return c.json({ total: rows.length, data: rows })
}

// ============================================================
// API ROUTES
// ============================================================

app.get('/api/postos', async (c) => {
  const { cidade, tipo, ativo, conector, limit = '100', offset = '0' } = c.req.query() as Record<string, string>
  let sql = `SELECT p.*, ROUND(AVG(a.nota),1) as media_nota, COUNT(DISTINCT a.id) as total_avaliacoes,
    GROUP_CONCAT(DISTINCT c.codigo) as conectores, COUNT(DISTINCT pc.id) as num_tomadas
    FROM postos_recarga p
    LEFT JOIN avaliacoes_postos a ON p.id = a.posto_id
    LEFT JOIN postos_conectores pc ON p.id = pc.posto_id
    LEFT JOIN dim_conectores c ON pc.conector_id = c.id
    WHERE 1=1`
  const params: unknown[] = []
  if (cidade) { sql += ' AND LOWER(p.cidade) LIKE LOWER(?)'; params.push(`%${cidade}%`) }
  if (tipo) { sql += ' AND p.tipo_ponto = ?'; params.push(tipo) }
  if (ativo !== undefined) { sql += ' AND p.ativo = ?'; params.push(ativo === 'true' || ativo === '1' ? 1 : 0) }
  if (conector) { sql += ' AND c.codigo = ?'; params.push(conector.toUpperCase()) }
  sql += ' GROUP BY p.id ORDER BY p.nome LIMIT ? OFFSET ?'
  params.push(parseInt(limit), parseInt(offset))
  const rows = (await c.env.DB.prepare(sql).bind(...params).all()).results
  return jsonOrCsv(c, rows as Record<string, unknown>[])
})

app.get('/api/postos/:id', async (c) => {
  const id = c.req.param('id')
  const posto = await c.env.DB.prepare(`
    SELECT p.*, GROUP_CONCAT(DISTINCT c.codigo) as conectores,
    ROUND(AVG(a.nota),1) as media_nota, COUNT(DISTINCT a.id) as total_avaliacoes
    FROM postos_recarga p
    LEFT JOIN postos_conectores pc ON p.id = pc.posto_id
    LEFT JOIN dim_conectores c ON pc.conector_id = c.id
    LEFT JOIN avaliacoes_postos a ON p.id = a.posto_id
    WHERE p.id = ? GROUP BY p.id
  `).bind(id).first()
  if (!posto) return c.json({ error: 'Posto não encontrado' }, 404)
  const avaliacoes = (await c.env.DB.prepare('SELECT * FROM avaliacoes_postos WHERE posto_id = ? ORDER BY data_avaliacao DESC').bind(id).all()).results
  return c.json({ ...posto, avaliacoes })
})

app.get('/api/resumo', async (c) => {
  const [total, cidades, conectores, tiposCount, kpis] = await Promise.all([
    c.env.DB.prepare(`SELECT COUNT(*) as total, SUM(CASE WHEN ativo=1 THEN 1 ELSE 0 END) as ativos FROM postos_recarga WHERE tipo_ponto='Posto Eletro'`).first(),
    c.env.DB.prepare(`SELECT cidade, COUNT(*) as quantidade FROM postos_recarga WHERE tipo_ponto='Posto Eletro' AND ativo=1 GROUP BY cidade ORDER BY quantidade DESC`).all(),
    c.env.DB.prepare(`SELECT c.codigo, c.nome, c.corrente, c.nivel, c.potencia_max_kw, c.descricao, COUNT(DISTINCT pc.posto_id) as num_postos, SUM(pc.quantidade) as total_tomadas FROM postos_conectores pc JOIN dim_conectores c ON pc.conector_id = c.id GROUP BY c.id ORDER BY num_postos DESC`).all(),
    c.env.DB.prepare(`SELECT tipo_ponto, COUNT(*) as qtd FROM postos_recarga GROUP BY tipo_ponto`).all(),
    c.env.DB.prepare(`SELECT * FROM kpis_ev`).all()
  ])
  return c.json({ resumo: total, por_cidade: cidades.results, conectores: conectores.results, tipos: tiposCount.results, kpis: kpis.results })
})

app.get('/api/mapa', async (c) => {
  const rows = (await c.env.DB.prepare(`
    SELECT p.id, p.nome, p.tipo_ponto, p.ativo, p.latitude, p.longitude,
    p.bairro, p.cidade, p.estado, p.rua, p.numero, p.horario_funcionamento, p.acesso, p.observacoes,
    GROUP_CONCAT(DISTINCT c.codigo) as conectores,
    ROUND(AVG(a.nota),1) as media_nota
    FROM postos_recarga p
    LEFT JOIN postos_conectores pc ON p.id = pc.posto_id
    LEFT JOIN dim_conectores c ON pc.conector_id = c.id
    LEFT JOIN avaliacoes_postos a ON p.id = a.posto_id
    WHERE p.latitude IS NOT NULL AND p.longitude IS NOT NULL
    GROUP BY p.id
  `).all()).results
  return c.json({ total: rows.length, data: rows })
})

app.get('/api/conectores', async (c) => {
  const rows = (await c.env.DB.prepare('SELECT * FROM dim_conectores ORDER BY nivel, potencia_max_kw DESC').all()).results
  return c.json({ total: rows.length, data: rows })
})

app.get('/api/veiculos', async (c) => {
  const rows = (await c.env.DB.prepare(`
    SELECT tv.*, GROUP_CONCAT(DISTINCT c.codigo) as conectores_compativeis
    FROM dim_tipos_veiculos tv
    LEFT JOIN veiculos_conectores vc ON tv.id = vc.veiculo_id AND vc.compativel = 1
    LEFT JOIN dim_conectores c ON vc.conector_id = c.id
    GROUP BY tv.id
  `).all()).results
  return c.json({ total: rows.length, data: rows })
})

app.get('/api/regioes', async (c) => {
  const rows = (await c.env.DB.prepare(`
    SELECT r.*, COUNT(DISTINCT p.id) as total_postos,
    COUNT(DISTINCT CASE WHEN p.ativo=1 AND p.tipo_ponto='Posto Eletro' THEN p.id END) as eletropostos_ativos
    FROM dim_regioes r
    LEFT JOIN postos_recarga p ON p.regiao_id = r.id
    GROUP BY r.id ORDER BY total_postos DESC
  `).all()).results
  return c.json({ total: rows.length, data: rows })
})

app.get('/api/avaliacoes', async (c) => {
  const posto_id = c.req.query('posto_id')
  let sql = 'SELECT a.*, u.nome, u.sobrenome FROM avaliacoes_postos a LEFT JOIN usuarios u ON a.usuario_id = u.id WHERE 1=1'
  const params: unknown[] = []
  if (posto_id) { sql += ' AND a.posto_id = ?'; params.push(posto_id) }
  sql += ' ORDER BY a.data_avaliacao DESC LIMIT 100'
  const rows = (await c.env.DB.prepare(sql).bind(...params).all()).results
  return c.json({ total: rows.length, data: rows })
})

app.post('/api/avaliacoes', async (c) => {
  const body = await c.req.json()
  const { posto_id, nota, comentario } = body
  if (!posto_id || !nota) return c.json({ error: 'posto_id e nota são obrigatórios' }, 400)
  if (nota < 1 || nota > 5) return c.json({ error: 'Nota deve ser entre 1 e 5' }, 400)
  const result = await c.env.DB.prepare('INSERT INTO avaliacoes_postos (posto_id, nota, comentario) VALUES (?, ?, ?)').bind(posto_id, nota, comentario || '').run()
  return c.json({ success: true, id: result.meta.last_row_id }, 201)
})

app.get('/api/clima', async (c) => {
  const cidade = c.req.query('cidade') || 'São Paulo'
  const historico = (await c.env.DB.prepare('SELECT * FROM clima_historico WHERE cidade = ? ORDER BY data DESC LIMIT 30').bind(cidade).all()).results
  let atual = null
  try {
    const url = 'https://api.open-meteo.com/v1/forecast?latitude=-23.5505&longitude=-46.6333&current=temperature_2m,relative_humidity_2m,precipitation,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode&forecast_days=7&timezone=America/Sao_Paulo'
    const resp = await fetch(url)
    if (resp.ok) atual = await resp.json()
  } catch (_) {}
  return c.json({ cidade, atual, historico })
})

app.get('/api/bi/resumo-regional', async (c) => {
  const rows = (await c.env.DB.prepare('SELECT * FROM vw_resumo_cidades').all()).results
  return jsonOrCsv(c, rows as Record<string, unknown>[])
})

app.get('/api/bi/conectores-distribuicao', async (c) => {
  const rows = (await c.env.DB.prepare(`
    SELECT c.codigo, c.nome, c.corrente, c.nivel, c.potencia_max_kw,
    COUNT(DISTINCT pc.posto_id) as num_postos, SUM(pc.quantidade) as total_tomadas
    FROM dim_conectores c LEFT JOIN postos_conectores pc ON c.id = pc.conector_id
    GROUP BY c.id ORDER BY num_postos DESC
  `).all()).results
  return jsonOrCsv(c, rows as Record<string, unknown>[])
})

app.get('/api/bi/postos-full', async (c) => {
  const rows = (await c.env.DB.prepare('SELECT * FROM vw_postos_detalhado').all()).results
  return jsonOrCsv(c, rows as Record<string, unknown>[])
})

app.post('/api/upload/postos', async (c) => {
  const body = await c.req.json()
  const { registros } = body
  if (!Array.isArray(registros) || !registros.length) return c.json({ error: 'Lista de registros inválida' }, 400)
  let importados = 0, erros = 0
  const detalhes: string[] = []
  for (const r of registros) {
    try {
      if (!r.nome || !r.cidade || !r.latitude || !r.longitude) {
        erros++; detalhes.push(`Linha ${importados + erros}: campos obrigatórios ausentes`); continue
      }
      await c.env.DB.prepare(`INSERT INTO postos_recarga (nome, tipo_ponto, ativo, rua, numero, bairro, cidade, estado, cep, latitude, longitude, acesso, horario_funcionamento, observacoes, email_cadastro, data_cadastro) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)`)
        .bind(r.nome, r.tipo_ponto || 'Posto Eletro', r.ativo !== false ? 1 : 0, r.rua || '', r.numero || '', r.bairro || '', r.cidade, r.estado || 'SP', r.cep || '', parseFloat(r.latitude), parseFloat(r.longitude), r.acesso || 'público', r.horario_funcionamento || '', r.observacoes || '', r.email || '').run()
      importados++
    } catch (e) { erros++; detalhes.push(`Erro: ${(e as Error).message}`) }
  }
  await c.env.DB.prepare('INSERT INTO log_importacoes (tipo, arquivo_nome, registros_importados, registros_erros, detalhes_erros) VALUES (?,?,?,?,?)').bind('postos', body.arquivo || 'upload', importados, erros, detalhes.join('\n')).run()
  return c.json({ success: true, importados, erros, detalhes })
})

app.get('/api/log', async (c) => {
  const rows = (await c.env.DB.prepare('SELECT * FROM log_importacoes ORDER BY importado_em DESC LIMIT 50').all()).results
  return c.json({ total: rows.length, data: rows })
})

app.get('/api/schema', (c) => {
  return c.json({
    tabelas: ['postos_recarga','dim_conectores','postos_conectores','dim_tipos_veiculos','veiculos_conectores','dim_regioes','dim_operadores','usuarios','avaliacoes_postos','feedbacks','clima_historico','log_importacoes','kpis_ev'],
    views: ['vw_resumo_cidades','vw_postos_detalhado'],
    endpoints: ['/api/postos','/api/postos/:id','/api/resumo','/api/mapa','/api/conectores','/api/veiculos','/api/regioes','/api/avaliacoes','/api/clima','/api/bi/resumo-regional','/api/bi/conectores-distribuicao','/api/bi/postos-full','/api/upload/postos','/api/log','/api/schema']
  })
})

// ============================================================
// PÁGINAS HTML
// ============================================================

const NAV = `
<nav style="position:sticky;top:0;z-index:50;display:flex;align-items:center;gap:8px;padding:12px 16px;border-bottom:1px solid #1e293b;background:#0a0f1e;">
  <a href="/" style="display:flex;align-items:center;gap:6px;text-decoration:none;margin-right:8px;">
    <span style="font-size:1.5rem">&#9889;</span>
    <span style="font-weight:700;color:white">SustAmbiTech</span>
    <span style="font-size:.7rem;color:#4ade80;font-weight:600">Eletropostos</span>
  </a>
  <a href="/"          style="padding:6px 12px;border-radius:8px;color:#d1d5db;text-decoration:none;font-size:.875rem;">&#127968; Dashboard</a>
  <a href="/mapa"      style="padding:6px 12px;border-radius:8px;color:#d1d5db;text-decoration:none;font-size:.875rem;">&#128205; Mapa</a>
  <a href="/admin/upload" style="padding:6px 12px;border-radius:8px;color:#d1d5db;text-decoration:none;font-size:.875rem;">&#128196; Importar</a>
  <a href="/mindmap"   style="padding:6px 12px;border-radius:8px;color:#d1d5db;text-decoration:none;font-size:.875rem;">&#128301; Mapa Mental</a>
  <a href="/tutorial"  style="padding:6px 12px;border-radius:8px;color:#d1d5db;text-decoration:none;font-size:.875rem;">&#127891; Tutorial</a>
  <span style="margin-left:auto;font-size:.75rem;color:#4b5563">by Kayham</span>
</nav>`

// ============================================================
// GET / — Dashboard Principal
// ============================================================
app.get('/', (c) => {
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>SustAmbiTech Eletropostos</title>
<script src="https://cdn.tailwindcss.com"></script>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.4.0/css/all.min.css">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
body{font-family:'Segoe UI',system-ui,sans-serif;background:#0a0f1e;color:#e2e8f0;}
.card{background:linear-gradient(135deg,#0f1629 0%,#1a2340 100%);border:1px solid #2d3748;border-radius:12px;}
.card-green{border-color:#22c55e;background:linear-gradient(135deg,#052e16 0%,#0f2a1a 100%);}
.card-blue{border-color:#3b82f6;background:linear-gradient(135deg,#0a1628 0%,#0f1e38 100%);}
.card-yellow{border-color:#f59e0b;background:linear-gradient(135deg,#1a1000 0%,#241800 100%);}
.card-purple{border-color:#a855f7;background:linear-gradient(135deg,#1a0a2e 0%,#200f38 100%);}
.kpi-val{font-size:2.2rem;font-weight:700;line-height:1;}
.tag{padding:2px 8px;border-radius:99px;font-size:.75rem;font-weight:600;}
.tag-green{background:#14532d;color:#4ade80;}
.tag-blue{background:#1e3a5f;color:#60a5fa;}
.tag-red{background:#450a0a;color:#f87171;}
.conector-badge{padding:3px 8px;border-radius:6px;font-size:.78rem;font-weight:700;border:1px solid;display:inline-block;margin:1px;}
.clima-day{background:#1a2340;border-radius:10px;padding:8px 12px;text-align:center;min-width:70px;}
table{width:100%;border-collapse:collapse;}
th{background:#1a2340;padding:10px 14px;text-align:left;font-size:.85rem;color:#94a3b8;}
td{padding:10px 14px;border-bottom:1px solid #1e293b;font-size:.9rem;}
tr:hover td{background:rgba(59,130,246,.05);}
.tab-btn{padding:.4rem .9rem;border-radius:8px;font-size:.875rem;cursor:pointer;transition:all .2s;color:#94a3b8;background:none;border:none;}
.tab-btn.active{background:#3b82f6;color:white;}
</style>
</head>
<body>
${NAV}
<main class="max-w-7xl mx-auto px-4 py-6">
  <div class="mb-6">
    <h1 class="text-3xl font-bold text-white mb-1">Infraestrutura de Recarga El&#233;trica</h1>
    <p class="text-gray-400">Grande S&#227;o Paulo &#8212; Dados reais de 57+ eletropostos migrados do Firebase</p>
  </div>

  <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
    <div class="card card-green p-5"><div class="text-green-400 text-sm mb-1"><i class="fas fa-charging-station mr-1"></i>Eletropostos Ativos</div><div class="kpi-val text-green-400" id="kpiTotal">...</div></div>
    <div class="card card-blue  p-5"><div class="text-blue-400  text-sm mb-1"><i class="fas fa-city mr-1"></i>Cidades Atendidas</div><div class="kpi-val text-blue-400"  id="kpiCidades">...</div></div>
    <div class="card card-yellow p-5"><div class="text-yellow-400 text-sm mb-1"><i class="fas fa-plug mr-1"></i>Tipos de Conector</div><div class="kpi-val text-yellow-400" id="kpiConectores">...</div></div>
    <div class="card card-purple p-5"><div class="text-purple-400 text-sm mb-1"><i class="fas fa-bolt mr-1"></i>Tomadas Instaladas</div><div class="kpi-val text-purple-400" id="kpiTomadas">...</div></div>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-6">
    <div class="card p-5 lg:col-span-2">
      <div class="flex gap-2 mb-4 flex-wrap">
        <button class="tab-btn active" onclick="showTab('postos',event)"><i class="fas fa-list mr-1"></i>Postos</button>
        <button class="tab-btn" onclick="showTab('cidades',event)"><i class="fas fa-city mr-1"></i>Por Cidade</button>
        <button class="tab-btn" onclick="showTab('conectores-tab',event)"><i class="fas fa-plug mr-1"></i>Conectores</button>
        <button class="tab-btn" onclick="showTab('veiculos-tab',event)"><i class="fas fa-car mr-1"></i>Ve&#237;culos</button>
      </div>
      <div id="tab-postos">
        <div class="flex gap-2 mb-3">
          <input id="searchInput" type="text" placeholder="Buscar nome, bairro..." class="flex-1 bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-sm text-white" onkeyup="filterTable()">
          <select id="cityFilter" class="bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-sm text-white" onchange="filterTable()">
            <option value="">Todas</option>
          </select>
        </div>
        <div class="overflow-auto max-h-72">
          <table id="postosTable">
            <thead><tr><th>Nome</th><th>Cidade/Bairro</th><th>Conectores</th><th>Nota</th><th>Status</th></tr></thead>
            <tbody id="postosBody"><tr><td colspan="5" class="text-center text-gray-500 py-4">Carregando...</td></tr></tbody>
          </table>
        </div>
      </div>
      <div id="tab-cidades" style="display:none"><canvas id="chartCidades" height="200"></canvas></div>
      <div id="tab-conectores-tab" style="display:none"><div id="conectoresList"></div></div>
      <div id="tab-veiculos-tab" style="display:none"><div id="veiculosList"></div></div>
    </div>

    <div class="card p-5">
      <div class="flex items-center gap-2 mb-4">
        <i class="fas fa-cloud-sun text-yellow-400 text-xl"></i>
        <h3 class="font-semibold text-white">Clima &#8212; S&#227;o Paulo</h3>
      </div>
      <div id="climaAtual" class="mb-4 text-center">
        <div class="text-5xl font-bold text-yellow-300" id="tempAtual">--&#176;C</div>
        <div class="text-gray-400 text-sm mt-1" id="condicaoAtual">Carregando...</div>
        <div class="flex justify-center gap-4 mt-2 text-sm">
          <span class="text-red-400"><i class="fas fa-arrow-up"></i> <span id="tempMax">--</span></span>
          <span class="text-blue-400"><i class="fas fa-arrow-down"></i> <span id="tempMin">--</span></span>
        </div>
      </div>
      <div class="flex gap-1 overflow-x-auto pb-1" id="previsaoSemana"></div>
      <div class="mt-4">
        <div class="text-xs text-gray-500 mb-2">Hist&#243;rico (&#176;C)</div>
        <canvas id="chartClima" height="120"></canvas>
      </div>
    </div>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
    <div class="card p-5">
      <h3 class="font-semibold text-white mb-3"><i class="fas fa-plug text-yellow-400 mr-2"></i>Distribui&#231;&#227;o de Conectores</h3>
      <canvas id="chartConectores" height="200"></canvas>
    </div>
    <div class="card p-5">
      <h3 class="font-semibold text-white mb-3"><i class="fas fa-chart-bar text-blue-400 mr-2"></i>Postos x Tomadas por Padr&#227;o</h3>
      <canvas id="chartPostosCidade" height="200"></canvas>
    </div>
  </div>

  <div class="card p-5 mb-6">
    <h3 class="font-semibold text-white mb-3"><i class="fas fa-database text-green-400 mr-2"></i>Endpoints para Power BI</h3>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <a href="/api/bi/resumo-regional?format=csv" class="flex items-center gap-2 bg-gray-900 hover:bg-gray-800 p-3 rounded-lg border border-gray-700 text-sm text-blue-400 transition">
        <i class="fas fa-file-csv text-green-400"></i>/api/bi/resumo-regional
      </a>
      <a href="/api/bi/conectores-distribuicao?format=csv" class="flex items-center gap-2 bg-gray-900 hover:bg-gray-800 p-3 rounded-lg border border-gray-700 text-sm text-blue-400 transition">
        <i class="fas fa-file-csv text-green-400"></i>/api/bi/conectores-distribuicao
      </a>
      <a href="/api/bi/postos-full?format=csv" class="flex items-center gap-2 bg-gray-900 hover:bg-gray-800 p-3 rounded-lg border border-gray-700 text-sm text-blue-400 transition">
        <i class="fas fa-file-csv text-green-400"></i>/api/bi/postos-full
      </a>
    </div>
  </div>
</main>
<footer class="text-center py-4 text-gray-600 text-sm border-t border-gray-800">
  &#9889; SustAmbiTech Eletropostos &#8212; Desenvolvido por <strong class="text-green-400">Kayham</strong>
</footer>
<script>
function showTab(tab,ev) {
  document.querySelectorAll('[id^="tab-"]').forEach(function(el){ el.style.display='none' })
  document.getElementById('tab-'+tab).style.display='block'
  document.querySelectorAll('.tab-btn').forEach(function(b){ b.classList.remove('active') })
  if(ev&&ev.target) ev.target.classList.add('active')
}
</script>
<script src="/static/dashboard.js"></script>
</body>
</html>`
  return c.html(html)
})

// ============================================================
// GET /mapa
// ============================================================
app.get('/mapa', (c) => {
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Mapa de Eletropostos</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<style>
body{margin:0;background:#0a0f1e;color:#e2e8f0;font-family:'Segoe UI',system-ui,sans-serif;}
#map{height:calc(100vh - 56px);width:100%;}
.leaflet-popup-content-wrapper{background:#1a2340;color:#e2e8f0;border:1px solid #2d3748;}
.leaflet-popup-tip{background:#1a2340;}
.filter-bar{background:#0f1629;border-bottom:1px solid #2d3748;padding:8px 16px;display:flex;gap:8px;align-items:center;flex-wrap:wrap;height:56px;}
.filter-bar select{background:#1a2340;border:1px solid #374151;border-radius:8px;padding:5px 10px;color:#e2e8f0;font-size:.85rem;}
.stat-pill{background:#1a2340;border:1px solid #374151;padding:3px 10px;border-radius:99px;font-size:.8rem;}
</style>
</head>
<body>
${NAV}
<div class="filter-bar">
  <select id="filterTipo" onchange="applyFilters()">
    <option value="">Todos os tipos</option>
    <option value="Posto Eletro">Posto Eletro</option>
    <option value="Reciclagem">Reciclagem</option>
  </select>
  <select id="filterCidade" onchange="applyFilters()"><option value="">Todas as cidades</option></select>
  <select id="filterConector" onchange="applyFilters()">
    <option value="">Todos os conectores</option>
    <option>CCS2</option><option>CHADEMO</option><option>TYPE2</option><option>AC_L2</option>
  </select>
  <span class="stat-pill" id="statsText">Carregando...</span>
  <span style="margin-left:auto;font-size:.75rem;color:#4b5563">&#11044; Verde=Eletroposto &nbsp; &#11044; Azul=Reciclagem</span>
</div>
<div id="map"></div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script src="/static/mapa.js"></script>
</body>
</html>`
  return c.html(html)
})

// ============================================================
// GET /admin/upload
// ============================================================
app.get('/admin/upload', (c) => {
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Importar Dados</title>
<script src="https://cdn.tailwindcss.com"></script>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.4.0/css/all.min.css">
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<style>
body{background:#0a0f1e;color:#e2e8f0;font-family:'Segoe UI',system-ui,sans-serif;}
.card{background:#0f1629;border:1px solid #2d3748;border-radius:12px;}
.drop-zone{border:2px dashed #374151;border-radius:12px;padding:2rem;text-align:center;cursor:pointer;transition:all .2s;}
.drop-zone:hover,.drop-zone.drag{border-color:#3b82f6;background:rgba(59,130,246,.07);}
.btn{padding:8px 20px;border-radius:8px;font-weight:600;cursor:pointer;transition:all .2s;border:none;}
.btn-primary{background:#3b82f6;color:white;}.btn-primary:hover{background:#2563eb;}
.btn-success{background:#22c55e;color:white;}.btn-success:hover{background:#16a34a;}
.tag{padding:2px 8px;border-radius:99px;font-size:.75rem;font-weight:600;}
.tag-green{background:#14532d;color:#4ade80;}.tag-red{background:#450a0a;color:#f87171;}
table{width:100%;border-collapse:collapse;font-size:.85rem;}
th{background:#1a2340;padding:8px 12px;text-align:left;color:#94a3b8;}
td{padding:8px 12px;border-bottom:1px solid #1e293b;}
</style>
</head>
<body>
${NAV}
<main class="max-w-4xl mx-auto px-4 py-8">
  <div class="card p-6 mb-6">
    <h2 class="text-xl font-bold text-white mb-2"><i class="fas fa-file-excel text-green-400 mr-2"></i>Upload de Arquivo .xlsx</h2>
    <p class="text-gray-400 text-sm mb-4">Importe novos eletropostos em lote. Colunas obrigat&#243;rias: <strong>nome, cidade, latitude, longitude</strong></p>
    <div class="drop-zone mb-4" id="dropZone"><div class="text-4xl mb-2">&#128202;</div><div class="text-gray-300 font-medium">Arraste o arquivo Excel aqui</div><div class="text-gray-500 text-sm">ou clique para selecionar</div></div>
    <input type="file" id="fileInput" accept=".xlsx,.xls,.csv" class="hidden">
    <div id="preview" style="display:none">
      <div class="flex items-center justify-between mb-3">
        <h3 class="font-semibold text-white">Pr&#233;via (<span id="rowCount">0</span> registros)</h3>
        <div class="flex gap-2">
          <button class="btn btn-primary" onclick="baixarTemplate()"><i class="fas fa-download mr-1"></i>Template</button>
          <button class="btn btn-success" onclick="importar()" id="btnImportar"><i class="fas fa-cloud-upload-alt mr-1"></i>Importar</button>
        </div>
      </div>
      <div class="overflow-auto max-h-60 rounded-lg"><table><thead id="previewHead"></thead><tbody id="previewBody"></tbody></table></div>
    </div>
    <div id="template-info" class="mt-4 bg-gray-900 rounded-lg p-4 border border-gray-700">
      <div class="flex items-center justify-between mb-2">
        <span class="text-sm font-semibold text-white">Baixar template Excel</span>
        <button class="btn btn-primary text-sm" onclick="baixarTemplate()"><i class="fas fa-download mr-1"></i>Baixar</button>
      </div>
      <div class="mt-2 flex flex-wrap gap-1">
        <span class="tag tag-red">nome*</span><span class="tag tag-red">cidade*</span><span class="tag tag-red">latitude*</span><span class="tag tag-red">longitude*</span>
        <span class="tag tag-green">rua</span><span class="tag tag-green">numero</span><span class="tag tag-green">bairro</span><span class="tag tag-green">tipo_ponto</span>
      </div>
    </div>
    <div id="resultado" style="display:none" class="mt-4 card p-4"></div>
  </div>
  <div class="card p-6">
    <h3 class="text-lg font-semibold text-white mb-3"><i class="fas fa-history text-blue-400 mr-2"></i>Hist&#243;rico de Importa&#231;&#245;es</h3>
    <div id="logList" class="text-gray-400 text-sm">Carregando...</div>
  </div>
</main>
<script src="/static/upload.js"></script>
</body>
</html>`
  return c.html(html)
})

// ============================================================
// GET /mindmap
// ============================================================
app.get('/mindmap', (c) => {
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mapa Mental BI</title>
<style>
body{margin:0;background:#0a0f1e;color:#e2e8f0;font-family:'Segoe UI',system-ui,sans-serif;}
svg text{font-family:'Segoe UI',system-ui,sans-serif;}
.legend-item{display:inline-flex;align-items:center;gap:8px;font-size:.8rem;margin:0 8px;}
</style>
</head>
<body>
${NAV}
<div style="padding:8px 16px;border-bottom:1px solid #1e293b;background:#0f1629;display:flex;align-items:center;gap:16px;flex-wrap:wrap;">
  <strong style="color:white;font-size:.9rem">Legenda:</strong>
  <span class="legend-item"><div style="width:14px;height:8px;background:#ef4444;border-radius:2px"></div>Tabelas de Dados (BI)</span>
  <span class="legend-item"><div style="width:14px;height:14px;background:#0a1628;border:2px solid #3b82f6;border-radius:50%"></div>Conte&#250;do do Site</span>
  <span class="legend-item"><div style="width:24px;height:10px;background:#0a1628;border:2px solid #a855f7;border-radius:8px"></div>Integra&#231;&#245;es/Features</span>
</div>
<div style="overflow:auto;padding:16px;min-height:calc(100vh - 120px)">
<svg viewBox="0 0 1200 900" width="100%" style="min-width:900px;max-width:1400px;margin:auto;display:block">
  <defs>
    <marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#4b5563"/>
    </marker>
  </defs>
  <line x1="600" y1="450" x2="320" y2="200" stroke="#374151" stroke-width="1.5" marker-end="url(#arr)"/>
  <line x1="600" y1="450" x2="600" y2="160" stroke="#374151" stroke-width="1.5" marker-end="url(#arr)"/>
  <line x1="600" y1="450" x2="880" y2="200" stroke="#374151" stroke-width="1.5" marker-end="url(#arr)"/>
  <line x1="600" y1="450" x2="200" y2="450" stroke="#374151" stroke-width="1.5" marker-end="url(#arr)"/>
  <line x1="600" y1="450" x2="1000" y2="450" stroke="#374151" stroke-width="1.5" marker-end="url(#arr)"/>
  <line x1="600" y1="450" x2="320" y2="700" stroke="#374151" stroke-width="1.5" marker-end="url(#arr)"/>
  <line x1="600" y1="450" x2="600" y2="730" stroke="#374151" stroke-width="1.5" marker-end="url(#arr)"/>
  <line x1="600" y1="450" x2="880" y2="700" stroke="#374151" stroke-width="1.5" marker-end="url(#arr)"/>
  <line x1="320" y1="200" x2="130" y2="90" stroke="#1f2937" stroke-width="1" marker-end="url(#arr)"/>
  <line x1="320" y1="200" x2="155" y2="248" stroke="#1f2937" stroke-width="1" marker-end="url(#arr)"/>
  <line x1="880" y1="200" x2="1060" y2="90" stroke="#1f2937" stroke-width="1" marker-end="url(#arr)"/>
  <line x1="880" y1="200" x2="1042" y2="258" stroke="#1f2937" stroke-width="1" marker-end="url(#arr)"/>
  <line x1="600" y1="160" x2="475" y2="55" stroke="#1f2937" stroke-width="1" marker-end="url(#arr)"/>
  <line x1="600" y1="160" x2="725" y2="55" stroke="#1f2937" stroke-width="1" marker-end="url(#arr)"/>

  <!-- CENTRO -->
  <rect x="478" y="408" width="244" height="84" rx="12" fill="#0f1f0f" stroke="#22c55e" stroke-width="2.5"/>
  <text x="600" y="440" text-anchor="middle" fill="#22c55e" font-size="15" font-weight="700">&#9889; SustAmbiTech</text>
  <text x="600" y="460" text-anchor="middle" fill="#4ade80" font-size="12">Eletropostos &#8212; Grande SP</text>
  <text x="600" y="478" text-anchor="middle" fill="#86efac" font-size="10">57 postos reais | Firebase &#8594; D1</text>

  <!-- postos_recarga -->
  <rect x="178" y="138" width="284" height="122" rx="6" fill="#1a0505" stroke="#ef4444" stroke-width="2"/>
  <text x="320" y="163" text-anchor="middle" fill="#ef4444" font-size="12" font-weight="700">&#128203; postos_recarga</text>
  <text x="320" y="181" text-anchor="middle" fill="#fca5a5" font-size="10">id &#183; firebase_uid &#183; nome &#183; tipo_ponto</text>
  <text x="320" y="197" text-anchor="middle" fill="#fca5a5" font-size="10">rua &#183; bairro &#183; cidade &#183; cep &#183; lat/lon</text>
  <text x="320" y="213" text-anchor="middle" fill="#fca5a5" font-size="10">ativo &#183; acesso &#183; horario &#183; operador_id</text>
  <text x="320" y="229" text-anchor="middle" fill="#f87171" font-size="9" font-style="italic">Tabela principal &#8212; 57 postos reais</text>
  <text x="320" y="247" text-anchor="middle" fill="#374151" font-size="9">BI: contagem, filtros, KPI por cidade</text>

  <!-- dim_conectores -->
  <rect x="458" y="78" width="284" height="104" rx="6" fill="#1a0505" stroke="#ef4444" stroke-width="2"/>
  <text x="600" y="103" text-anchor="middle" fill="#ef4444" font-size="12" font-weight="700">&#128268; dim_conectores</text>
  <text x="600" y="121" text-anchor="middle" fill="#fca5a5" font-size="10">CCS2 &#183; CHAdeMO &#183; Type2 &#183; AC_L1/L2</text>
  <text x="600" y="137" text-anchor="middle" fill="#fca5a5" font-size="10">corrente &#183; n&#237;vel &#183; potencia_max_kw</text>
  <text x="600" y="153" text-anchor="middle" fill="#f87171" font-size="9" font-style="italic">Padr&#245;es internacionais de tomada EV</text>
  <text x="600" y="169" text-anchor="middle" fill="#374151" font-size="9">BI: distribui&#231;&#227;o de padr&#245;es</text>

  <!-- postos_conectores -->
  <rect x="738" y="138" width="284" height="104" rx="6" fill="#1a0505" stroke="#ef4444" stroke-width="2"/>
  <text x="880" y="163" text-anchor="middle" fill="#ef4444" font-size="12" font-weight="700">&#128279; postos_conectores</text>
  <text x="880" y="181" text-anchor="middle" fill="#fca5a5" font-size="10">posto_id &#183; conector_id &#183; quantidade</text>
  <text x="880" y="197" text-anchor="middle" fill="#fca5a5" font-size="10">potencia_kw &#183; status</text>
  <text x="880" y="213" text-anchor="middle" fill="#f87171" font-size="9" font-style="italic">Rela&#231;&#227;o N:N postos &#215; tomadas</text>
  <text x="880" y="229" text-anchor="middle" fill="#374151" font-size="9">BI: total tomadas, disponibilidade</text>

  <!-- usuarios -->
  <rect x="48" y="378" width="224" height="104" rx="6" fill="#1a0505" stroke="#ef4444" stroke-width="2"/>
  <text x="160" y="403" text-anchor="middle" fill="#ef4444" font-size="12" font-weight="700">&#128100; usuarios</text>
  <text x="160" y="421" text-anchor="middle" fill="#fca5a5" font-size="10">firebase_uid &#183; email &#183; nome</text>
  <text x="160" y="437" text-anchor="middle" fill="#fca5a5" font-size="10">nivel &#183; newsletter_opt_in</text>
  <text x="160" y="453" text-anchor="middle" fill="#f87171" font-size="9" font-style="italic">5 usu&#225;rios migrados do Firebase</text>
  <text x="160" y="469" text-anchor="middle" fill="#374151" font-size="9">BI: engajamento, cadastros</text>

  <!-- avaliacoes_postos -->
  <rect x="878" y="378" width="264" height="104" rx="6" fill="#1a0505" stroke="#ef4444" stroke-width="2"/>
  <text x="1010" y="403" text-anchor="middle" fill="#ef4444" font-size="12" font-weight="700">&#11088; avaliacoes_postos</text>
  <text x="1010" y="421" text-anchor="middle" fill="#fca5a5" font-size="10">posto_id &#183; usuario_id &#183; nota (1-5)</text>
  <text x="1010" y="437" text-anchor="middle" fill="#fca5a5" font-size="10">comentario &#183; data_avaliacao</text>
  <text x="1010" y="453" text-anchor="middle" fill="#f87171" font-size="9" font-style="italic">Migrado do Firebase + novas</text>
  <text x="1010" y="469" text-anchor="middle" fill="#374151" font-size="9">BI: NPS, m&#233;dia por posto/cidade</text>

  <!-- kpis_ev -->
  <rect x="738" y="638" width="284" height="104" rx="6" fill="#1a0505" stroke="#ef4444" stroke-width="2"/>
  <text x="880" y="663" text-anchor="middle" fill="#ef4444" font-size="12" font-weight="700">&#128202; kpis_ev</text>
  <text x="880" y="681" text-anchor="middle" fill="#fca5a5" font-size="10">indicador &#183; valor_atual &#183; meta_2025</text>
  <text x="880" y="697" text-anchor="middle" fill="#fca5a5" font-size="10">meta_2030 &#183; unidade &#183; categoria</text>
  <text x="880" y="713" text-anchor="middle" fill="#f87171" font-size="9" font-style="italic">Metas de infraestrutura el&#233;trica</text>
  <text x="880" y="729" text-anchor="middle" fill="#374151" font-size="9">BI: scorecards, gauge charts</text>

  <!-- log_importacoes -->
  <rect x="458" y="748" width="284" height="92" rx="6" fill="#1a0505" stroke="#ef4444" stroke-width="2"/>
  <text x="600" y="773" text-anchor="middle" fill="#ef4444" font-size="12" font-weight="700">&#128229; log_importacoes</text>
  <text x="600" y="791" text-anchor="middle" fill="#fca5a5" font-size="10">tipo &#183; arquivo &#183; importados &#183; erros</text>
  <text x="600" y="807" text-anchor="middle" fill="#fca5a5" font-size="10">detalhes_erros &#183; importado_em</text>
  <text x="600" y="823" text-anchor="middle" fill="#374151" font-size="9">Auditoria de uploads Excel</text>

  <!-- feedbacks -->
  <rect x="178" y="638" width="264" height="104" rx="6" fill="#1a0505" stroke="#ef4444" stroke-width="2"/>
  <text x="310" y="663" text-anchor="middle" fill="#ef4444" font-size="12" font-weight="700">&#128172; feedbacks</text>
  <text x="310" y="681" text-anchor="middle" fill="#fca5a5" font-size="10">usuario_id &#183; nota &#183; observacoes</text>
  <text x="310" y="697" text-anchor="middle" fill="#fca5a5" font-size="10">data_feedback &#183; firebase_id</text>
  <text x="310" y="713" text-anchor="middle" fill="#f87171" font-size="9" font-style="italic">2 feedbacks do Firebase migrados</text>
  <text x="310" y="729" text-anchor="middle" fill="#374151" font-size="9">BI: satisfa&#231;&#227;o do app</text>

  <!-- C&#237;rculos Azuis (Conte&#250;do) -->
  <circle cx="130" cy="80" r="52" fill="#0a1628" stroke="#3b82f6" stroke-width="2"/>
  <text x="130" y="73" text-anchor="middle" fill="#3b82f6" font-size="11" font-weight="700">Dashboard</text>
  <text x="130" y="89" text-anchor="middle" fill="#93c5fd" font-size="9">KPIs &#183; gr&#225;ficos</text>
  <text x="130" y="104" text-anchor="middle" fill="#93c5fd" font-size="9">Chart.js</text>

  <circle cx="155" cy="248" r="52" fill="#0a1628" stroke="#3b82f6" stroke-width="2"/>
  <text x="155" y="241" text-anchor="middle" fill="#3b82f6" font-size="11" font-weight="700">Mapa</text>
  <text x="155" y="257" text-anchor="middle" fill="#93c5fd" font-size="9">Leaflet.js</text>
  <text x="155" y="272" text-anchor="middle" fill="#93c5fd" font-size="9">57+ pins</text>

  <circle cx="1060" cy="80" r="52" fill="#0a1628" stroke="#3b82f6" stroke-width="2"/>
  <text x="1060" y="73" text-anchor="middle" fill="#3b82f6" font-size="11" font-weight="700">Clima</text>
  <text x="1060" y="89" text-anchor="middle" fill="#93c5fd" font-size="9">OpenMeteo</text>
  <text x="1060" y="104" text-anchor="middle" fill="#93c5fd" font-size="9">Previs&#227;o 7d</text>

  <circle cx="1042" cy="258" r="50" fill="#0a1628" stroke="#3b82f6" stroke-width="2"/>
  <text x="1042" y="251" text-anchor="middle" fill="#3b82f6" font-size="11" font-weight="700">Upload</text>
  <text x="1042" y="267" text-anchor="middle" fill="#93c5fd" font-size="9">Excel .xlsx</text>
  <text x="1042" y="282" text-anchor="middle" fill="#93c5fd" font-size="9">SheetJS</text>

  <circle cx="475" cy="42" r="35" fill="#0a1628" stroke="#3b82f6" stroke-width="2"/>
  <text x="475" y="36" text-anchor="middle" fill="#3b82f6" font-size="9" font-weight="700">Ve&#237;culos</text>
  <text x="475" y="51" text-anchor="middle" fill="#93c5fd" font-size="8">BEV PHEV HEV</text>

  <circle cx="725" cy="42" r="35" fill="#0a1628" stroke="#3b82f6" stroke-width="2"/>
  <text x="725" y="36" text-anchor="middle" fill="#3b82f6" font-size="9" font-weight="700">Compat.</text>
  <text x="725" y="51" text-anchor="middle" fill="#93c5fd" font-size="8">Ve&#237;culo&#215;Conector</text>

  <!-- C&#225;psulas Roxas (Integra&#231;&#245;es) -->
  <rect x="48" y="510" width="184" height="54" rx="27" fill="#0a1628" stroke="#a855f7" stroke-width="2"/>
  <text x="140" y="532" text-anchor="middle" fill="#a855f7" font-size="10" font-weight="700">Power BI</text>
  <text x="140" y="549" text-anchor="middle" fill="#c4b5fd" font-size="9">CSV/JSON endpoints</text>

  <rect x="878" y="510" width="184" height="54" rx="27" fill="#0a1628" stroke="#a855f7" stroke-width="2"/>
  <text x="970" y="532" text-anchor="middle" fill="#a855f7" font-size="10" font-weight="700">Tutorial Deploy</text>
  <text x="970" y="549" text-anchor="middle" fill="#c4b5fd" font-size="9">CF Pages + D1 gr&#225;tis</text>

  <text x="600" y="870" text-anchor="middle" fill="#374151" font-size="10">Tabelas: dim_regioes &#183; dim_tipos_veiculos &#183; dim_operadores &#183; veiculos_conectores &#183; clima_historico</text>
</svg>
</div>
<div style="text-align:center;padding:12px;font-size:.85rem;color:#4b5563;border-top:1px solid #1e293b;">
  <strong style="color:#ef4444">Ret&#226;ngulos vermelhos</strong> = Tabelas de dados para BI &nbsp;|&nbsp;
  <strong style="color:#3b82f6">C&#237;rculos azuis</strong> = Funcionalidades do site &nbsp;|&nbsp;
  <strong style="color:#a855f7">C&#225;psulas roxas</strong> = Integra&#231;&#245;es extras
</div>
</body>
</html>`
  return c.html(html)
})

// ============================================================
// GET /tutorial
// ============================================================
app.get('/tutorial', (c) => {
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Tutorial Deploy Gratuito</title>
<script src="https://cdn.tailwindcss.com"></script>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.4.0/css/all.min.css">
<style>
body{background:#0a0f1e;color:#e2e8f0;font-family:'Segoe UI',system-ui,sans-serif;}
.card{background:#0f1629;border:1px solid #2d3748;border-radius:12px;}
.step{border-left:3px solid #3b82f6;padding-left:16px;margin-bottom:24px;}
.step-num{background:#3b82f6;color:white;border-radius:50%;width:28px;height:28px;display:inline-flex;align-items:center;justify-content:center;font-weight:700;font-size:.9rem;margin-right:8px;}
pre{background:#020b14;border:1px solid #1e3a5f;border-radius:8px;padding:16px;overflow-x:auto;font-size:.85rem;color:#7dd3fc;line-height:1.6;}
.badge{padding:3px 10px;border-radius:99px;font-size:.75rem;font-weight:600;}
.badge-free{background:#052e16;color:#4ade80;border:1px solid #166534;}
code{background:#1a2340;padding:1px 6px;border-radius:4px;font-size:.85rem;}
</style>
</head>
<body>
${NAV}
<main class="max-w-4xl mx-auto px-4 py-8 space-y-8">
  <div class="card p-6">
    <h1 class="text-2xl font-bold text-white mb-2">&#128640; Deploy 100% Gratuito</h1>
    <p class="text-gray-400 mb-4">Tudo do zero: GitHub &#8594; Cloudflare Pages + D1 &#8212; sem cartão de crédito.</p>
    <div class="flex flex-wrap gap-2">
      <span class="badge badge-free"><i class="fab fa-github mr-1"></i>GitHub</span>
      <span class="badge badge-free"><i class="fas fa-cloud mr-1"></i>Cloudflare Pages</span>
      <span class="badge badge-free"><i class="fas fa-database mr-1"></i>D1 SQLite (5GB)</span>
      <span class="badge badge-free"><i class="fas fa-bolt mr-1"></i>Workers (100k req/dia)</span>
    </div>
  </div>

  <div class="card p-6">
    <h2 class="text-xl font-bold text-white mb-4"><i class="fas fa-gift text-green-400 mr-2"></i>Limites Gratuitos</h2>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="bg-gray-900 p-4 rounded-lg border border-gray-700">
        <div class="text-green-400 font-bold mb-2">Cloudflare Pages</div>
        <ul class="text-sm text-gray-300 space-y-1">
          <li>&#10003; Hospedagem ilimitada</li>
          <li>&#10003; HTTPS autom&#225;tico</li>
          <li>&#10003; Deploy via GitHub</li>
          <li>&#10003; 500 deploys/m&#234;s</li>
          <li>&#10003; CDN global</li>
        </ul>
      </div>
      <div class="bg-gray-900 p-4 rounded-lg border border-gray-700">
        <div class="text-blue-400 font-bold mb-2">Cloudflare D1</div>
        <ul class="text-sm text-gray-300 space-y-1">
          <li>&#10003; 5 GB armazenamento</li>
          <li>&#10003; 5M leituras/dia</li>
          <li>&#10003; 100K escritas/dia</li>
          <li>&#10003; SQLite completo</li>
          <li>&#10003; Backup autom&#225;tico</li>
        </ul>
      </div>
      <div class="bg-gray-900 p-4 rounded-lg border border-gray-700">
        <div class="text-yellow-400 font-bold mb-2">Workers (Hono)</div>
        <ul class="text-sm text-gray-300 space-y-1">
          <li>&#10003; 100k req/dia</li>
          <li>&#10003; Edge global</li>
          <li>&#10003; Sem cold start</li>
          <li>&#10003; Logs integrados</li>
          <li>&#10003; HTTPS incluso</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="card p-6">
    <h2 class="text-xl font-bold text-white mb-4"><i class="fas fa-laptop-code text-blue-400 mr-2"></i>Parte 1 &#8212; Setup Local</h2>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">1</span><span class="font-semibold">Instalar Node.js 18+</span></div>
      <p class="text-gray-400 text-sm mb-2">Baixe em <a href="https://nodejs.org" class="text-blue-400" target="_blank">nodejs.org</a> (vers&#227;o LTS)</p>
      <pre>node --version   # v18.x ou superior
npm --version    # 9.x ou superior</pre>
    </div>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">2</span><span class="font-semibold">Clonar e instalar</span></div>
      <pre>git clone https://github.com/KayhamCristoffer/SustAmbiTechBI.io.git
cd SustAmbiTechBI.io
npm install</pre>
    </div>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">3</span><span class="font-semibold">Testar localmente</span></div>
      <pre>npm run build
npx wrangler d1 execute sustambitech-production --local --file=./migrations/0001_initial_schema.sql
npx wrangler d1 execute sustambitech-production --local --file=./seed.sql
npx wrangler pages dev dist --d1=sustambitech-production --local --port 3000</pre>
      <p class="text-gray-400 text-sm mt-2">Abra <a href="http://localhost:3000" class="text-blue-400">http://localhost:3000</a></p>
    </div>
  </div>

  <div class="card p-6">
    <h2 class="text-xl font-bold text-white mb-4"><i class="fab fa-cloudflare text-orange-400 mr-2"></i>Parte 2 &#8212; Cloudflare</h2>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">4</span><span class="font-semibold">Criar conta gratuita</span></div>
      <p class="text-gray-400 text-sm">Acesse <a href="https://dash.cloudflare.com/sign-up" class="text-orange-400" target="_blank">dash.cloudflare.com/sign-up</a> &#8212; confirme o email.</p>
    </div>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">5</span><span class="font-semibold">Login via Wrangler</span></div>
      <pre>npx wrangler login
# Abre browser &#8594; autorize &#8594; volte ao terminal</pre>
    </div>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">6</span><span class="font-semibold">Criar banco D1</span></div>
      <pre>npx wrangler d1 create sustambitech-production
# Copie o database_id gerado e cole no wrangler.jsonc</pre>
    </div>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">7</span><span class="font-semibold">Popular banco de produ&#231;&#227;o</span></div>
      <pre>npx wrangler d1 execute sustambitech-production --file=./migrations/0001_initial_schema.sql
npx wrangler d1 execute sustambitech-production --file=./seed.sql</pre>
    </div>
  </div>

  <div class="card p-6">
    <h2 class="text-xl font-bold text-white mb-4"><i class="fas fa-rocket text-green-400 mr-2"></i>Parte 3 &#8212; Deploy</h2>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">8</span><span class="font-semibold">Deploy via Wrangler (linha de comando)</span></div>
      <pre>npm run build
npx wrangler pages deploy dist --project-name sustambitech</pre>
    </div>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">9</span><span class="font-semibold">Ou: Deploy autom&#225;tico via GitHub</span></div>
      <ol class="text-sm text-gray-300 space-y-1 ml-4 list-decimal mt-2">
        <li>Dashboard Cloudflare &#8594; Workers &amp; Pages &#8594; Create</li>
        <li>Connect to Git &#8594; selecione <code>SustAmbiTechBI.io</code></li>
        <li>Build: <code>npm run build</code> | Output: <code>dist</code></li>
        <li>Save and Deploy</li>
      </ol>
    </div>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">10</span><span class="font-semibold">Vincular D1 ao Pages</span></div>
      <ol class="text-sm text-gray-300 space-y-1 ml-4 list-decimal mt-2">
        <li>Pages &#8594; Settings &#8594; Functions &#8594; D1 bindings</li>
        <li>Variable name: <code>DB</code></li>
        <li>Database: <code>sustambitech-production</code></li>
        <li>Save &#8594; Redeploy</li>
      </ol>
    </div>
  </div>

  <div class="card p-6">
    <h2 class="text-xl font-bold text-white mb-4"><i class="fas fa-chart-pie text-yellow-400 mr-2"></i>Parte 4 &#8212; Power BI</h2>
    <div class="step">
      <div class="flex items-center mb-2"><span class="step-num">11</span><span class="font-semibold">Conectar Power BI Desktop</span></div>
      <ol class="text-sm text-gray-300 space-y-1 ml-4 list-decimal mt-2">
        <li>Obter Dados &#8594; Web</li>
        <li>Cole: <code>https://seu-projeto.pages.dev/api/bi/resumo-regional?format=csv</code></li>
        <li>Repita para: <code>/api/bi/conectores-distribuicao</code> e <code>/api/bi/postos-full</code></li>
        <li>Carregue e crie seus dashboards!</li>
      </ol>
    </div>
  </div>
</main>
<footer class="text-center py-4 text-gray-600 text-sm border-t border-gray-800">
  &#9889; SustAmbiTech Eletropostos &#8212; Tutorial por <strong class="text-green-400">Kayham</strong>
</footer>
</body>
</html>`
  return c.html(html)
})

export default app
