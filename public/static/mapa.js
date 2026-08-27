// mapa.js — SustAmbiTech Eletropostos
// Tiles: 100% gratuitos, sem API key necessária
// Opções disponíveis: CartoDB Dark, OSM Standard, OSM Humanitarian, Stadia Alidade

// ── Inicializa mapa ──────────────────────────────────────────
var mapObj = L.map('map', {
  zoomControl: true,
  attributionControl: true
}).setView([-23.5505, -46.6333], 11)

// ── Camadas de tiles gratuitas (sem API key) ─────────────────
var tiles = {
  'Escuro (CartoDB)': L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
    subdomains: 'abcd',
    maxZoom: 20
  }),
  'Claro (CartoDB)': L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
    subdomains: 'abcd',
    maxZoom: 20
  }),
  'OpenStreetMap': L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19
  }),
  'Humanitário (OSM)': L.tileLayer('https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, Tiles style by <a href="https://www.hotosm.org">HOT</a>',
    subdomains: 'abc',
    maxZoom: 19
  }),
  'Stadia Alidade Smooth Dark': L.tileLayer('https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png', {
    attribution: '&copy; <a href="https://stadiamaps.com/">Stadia Maps</a> &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    maxZoom: 20
  })
}

// Tile padrão: CartoDB Dark (gratuito, sem key)
tiles['Escuro (CartoDB)'].addTo(mapObj)

// Controle de camadas (seletor de tile no mapa)
L.control.layers(tiles, null, { position: 'topright', collapsed: true }).addTo(mapObj)

// ── Ícones por tipo de ponto ─────────────────────────────────
var icons = {
  'Posto Eletro': L.divIcon({
    html: '<div style="background:#22c55e;border:2px solid #fff;border-radius:50%;width:16px;height:16px;box-shadow:0 0 8px rgba(34,197,94,.8)"></div>',
    iconSize: [16, 16],
    iconAnchor: [8, 8],
    className: ''
  }),
  'Eletroposto': L.divIcon({
    html: '<div style="background:#22c55e;border:2px solid #fff;border-radius:50%;width:16px;height:16px;box-shadow:0 0 8px rgba(34,197,94,.8)"></div>',
    iconSize: [16, 16],
    iconAnchor: [8, 8],
    className: ''
  }),
  'eletrico': L.divIcon({
    html: '<div style="background:#22c55e;border:2px solid #fff;border-radius:50%;width:16px;height:16px;box-shadow:0 0 8px rgba(34,197,94,.8)"></div>',
    iconSize: [16, 16],
    iconAnchor: [8, 8],
    className: ''
  }),
  'hibrido': L.divIcon({
    html: '<div style="background:#f59e0b;border:2px solid #fff;border-radius:50%;width:16px;height:16px;box-shadow:0 0 6px rgba(245,158,11,.8)"></div>',
    iconSize: [16, 16],
    iconAnchor: [8, 8],
    className: ''
  }),
  'comum': L.divIcon({
    html: '<div style="background:#64748b;border:2px solid #fff;border-radius:50%;width:14px;height:14px"></div>',
    iconSize: [14, 14],
    iconAnchor: [7, 7],
    className: ''
  }),
  'Reciclagem': L.divIcon({
    html: '<div style="background:#3b82f6;border:2px solid #fff;border-radius:50%;width:14px;height:14px"></div>',
    iconSize: [14, 14],
    iconAnchor: [7, 7],
    className: ''
  }),
  'default': L.divIcon({
    html: '<div style="background:#a78bfa;border:2px solid #fff;border-radius:50%;width:12px;height:12px"></div>',
    iconSize: [12, 12],
    iconAnchor: [6, 6],
    className: ''
  })
}

var allMarkers = []
var allData = []

// ── Carrega postos da API ────────────────────────────────────
async function loadMap() {
  try {
    var r = await fetch('/api/mapa').then(function(x) { return x.json() })
    allData = r.data || []

    // Popula dropdown de cidades
    var cidades = []
    allData.forEach(function(p) {
      if (p.cidade && !cidades.includes(p.cidade)) cidades.push(p.cidade)
    })
    cidades.sort()
    var sel = document.getElementById('filterCidade')
    if (sel) {
      cidades.forEach(function(c) {
        var opt = document.createElement('option')
        opt.value = c
        opt.textContent = c
        sel.appendChild(opt)
      })
    }

    renderMarkers(allData)

    // Ajusta zoom para encaixar todos os marcadores
    if (allData.length > 0) {
      var pts = allData.filter(function(p) { return p.latitude && p.longitude })
      if (pts.length > 0) {
        var bounds = L.latLngBounds(pts.map(function(p) { return [p.latitude, p.longitude] }))
        mapObj.fitBounds(bounds, { padding: [40, 40] })
      }
    }
  } catch (e) {
    console.error('Erro ao carregar mapa:', e)
    var statsEl = document.getElementById('statsText')
    if (statsEl) statsEl.textContent = 'Erro ao carregar dados'
  }
}

// ── Renderiza marcadores no mapa ─────────────────────────────
function renderMarkers(data) {
  // Remove marcadores anteriores
  allMarkers.forEach(function(m) { mapObj.removeLayer(m) })
  allMarkers = []

  data.forEach(function(p) {
    if (!p.latitude || !p.longitude) return

    // Seleciona ícone pelo tipo (compatível com D1 e Supabase)
    var tipoKey = p.tipo_ponto || p.tipo || 'default'
    var icon = icons[tipoKey] || icons['default']

    // Monta conectores
    var conns = (p.conectores || '').split(',').filter(Boolean)
    var connHtml = conns.length > 0
      ? conns.map(function(c) {
          return '<span style="background:#1e3a5f;padding:2px 6px;border-radius:4px;font-size:.72rem;margin:1px;display:inline-block;color:#7dd3fc">' + c.trim() + '</span>'
        }).join(' ')
      : '<span style="color:#475569;font-size:.75rem">Sem conector cadastrado</span>'

    // Avaliação
    var notaHtml = p.media_nota
      ? '<span style="color:#fbbf24">&#9733; ' + p.media_nota + '</span> <span style="color:#475569">(' + (p.total_avaliacoes || 0) + ' aval.)</span>'
      : '<span style="color:#475569">Sem avaliações</span>'

    // Popup HTML
    var popup = '<div style="min-width:220px;max-width:280px;font-family:system-ui,sans-serif;">' +
      '<div style="font-weight:700;font-size:.95rem;color:#f1f5f9;margin-bottom:4px;line-height:1.3">' + (p.nome || 'Posto') + '</div>' +
      '<div style="font-size:.78rem;color:#94a3b8;margin-bottom:2px">' +
        (p.rua ? p.rua + (p.numero ? ', ' + p.numero : '') : '') +
        (p.bairro ? ' — ' + p.bairro : '') +
      '</div>' +
      '<div style="font-size:.78rem;color:#94a3b8;margin-bottom:8px">' + (p.cidade || '') + '/' + (p.estado || 'SP') + '</div>' +
      '<div style="margin-bottom:6px">' + connHtml + '</div>' +
      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:4px;font-size:.75rem;margin-bottom:6px">' +
        '<div style="color:#94a3b8">Acesso: <span style="color:#cbd5e1">' + (p.acesso || '—') + '</span></div>' +
        '<div style="color:#94a3b8">Horário: <span style="color:#cbd5e1">' + (p.horario_funcionamento || '—') + '</span></div>' +
      '</div>' +
      '<div style="font-size:.78rem;margin-bottom:4px">' + notaHtml + '</div>' +
      (p.observacoes ? '<div style="font-size:.72rem;color:#64748b;border-top:1px solid #1e2d4a;padding-top:6px;margin-top:4px">' + p.observacoes + '</div>' : '') +
      '</div>'

    var marker = L.marker([p.latitude, p.longitude], { icon: icon })
      .addTo(mapObj)
      .bindPopup(popup, { maxWidth: 300 })

    allMarkers.push(marker)
  })

  // Atualiza contador
  var statsEl = document.getElementById('statsText')
  if (statsEl) statsEl.textContent = data.length + ' posto' + (data.length !== 1 ? 's' : '') + ' vis\u00edvel' + (data.length !== 1 ? 'is' : '')
}

// ── Aplica filtros ───────────────────────────────────────────
function applyFilters() {
  var tipoEl = document.getElementById('filterTipo')
  var cidadeEl = document.getElementById('filterCidade')
  var connEl = document.getElementById('filterConector')

  var tipo   = tipoEl   ? tipoEl.value   : ''
  var cidade = cidadeEl ? cidadeEl.value : ''
  var conn   = connEl   ? connEl.value   : ''

  var filtered = allData.filter(function(p) {
    // Compatível com campo tipo_ponto (D1) e tipo (Supabase)
    var tipoP = (p.tipo_ponto || p.tipo || '').toLowerCase()
    if (tipo) {
      if (tipo === 'eletrico' && tipoP !== 'eletrico' && tipoP !== 'posto eletro') return false
      if (tipo !== 'eletrico' && tipoP !== tipo.toLowerCase()) return false
    }
    if (cidade && p.cidade !== cidade) return false
    if (conn && !(p.conectores || '').includes(conn)) return false
    return true
  })

  renderMarkers(filtered)
}

// ── Inicia ───────────────────────────────────────────────────
loadMap()
