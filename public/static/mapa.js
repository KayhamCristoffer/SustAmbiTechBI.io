// mapa.js — SustAmbiTech Eletropostos
const mapObj = L.map('map').setView([-23.5505, -46.6333], 11)
L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
  attribution: '© OpenStreetMap © CartoDB', maxZoom: 19
}).addTo(mapObj)

const icons = {
  'Posto Eletro': L.divIcon({ html: '<div style="background:#22c55e;border:2px solid #fff;border-radius:50%;width:16px;height:16px;box-shadow:0 0 8px #22c55e"></div>', iconSize:[16,16], className:'' }),
  'Reciclagem': L.divIcon({ html: '<div style="background:#3b82f6;border:2px solid #fff;border-radius:50%;width:14px;height:14px"></div>', iconSize:[14,14], className:'' }),
  'default': L.divIcon({ html: '<div style="background:#f59e0b;border:2px solid #fff;border-radius:50%;width:12px;height:12px"></div>', iconSize:[12,12], className:'' })
}

let allMarkers = [], allData = []

async function loadMap() {
  const r = await fetch('/api/mapa').then(function(x){ return x.json() })
  allData = r.data
  const cidades = []
  allData.forEach(function(p){ if (!cidades.includes(p.cidade)) cidades.push(p.cidade) })
  cidades.sort()
  const sel = document.getElementById('filterCidade')
  cidades.forEach(function(c){ sel.innerHTML += '<option>'+c+'</option>' })
  renderMarkers(allData)
}

function renderMarkers(data) {
  allMarkers.forEach(function(m){ mapObj.removeLayer(m) })
  allMarkers = []
  data.forEach(function(p){
    if (!p.latitude || !p.longitude) return
    const icon = icons[p.tipo_ponto] || icons['default']
    const conns = (p.conectores||'').split(',').filter(Boolean)
    const connHtml = conns.map(function(c){ return '<span style="background:#1e3a5f;padding:2px 6px;border-radius:4px;font-size:.75rem;margin:1px;display:inline-block">'+c+'</span>' }).join(' ')
    const nota = p.media_nota ? '&#9733; ' + p.media_nota : '—'
    const popup = '<div style="min-width:200px">' +
      '<div style="font-weight:700;font-size:1rem;margin-bottom:4px">'+p.nome+'</div>' +
      '<div style="color:#94a3b8;font-size:.8rem">'+(p.rua||'')+', '+(p.numero||'')+' — '+(p.bairro||'')+'</div>' +
      '<div style="color:#94a3b8;font-size:.8rem">'+p.cidade+'/'+p.estado+'</div>' +
      '<div style="margin:6px 0">'+connHtml+'</div>' +
      '<div style="font-size:.8rem;color:#94a3b8">Acesso: '+(p.acesso||'—')+' | '+(p.horario_funcionamento||'—')+'</div>' +
      '<div style="font-size:.8rem;color:#fbbf24;margin-top:4px">'+nota+'</div>' +
      (p.observacoes ? '<div style="font-size:.75rem;color:#64748b;margin-top:4px">'+p.observacoes+'</div>' : '') +
      '</div>'
    const m = L.marker([p.latitude, p.longitude], {icon: icon}).addTo(mapObj).bindPopup(popup)
    allMarkers.push(m)
  })
  document.getElementById('statsText').textContent = data.length + ' postos visíveis'
}

function applyFilters() {
  const tipo = document.getElementById('filterTipo').value
  const cidade = document.getElementById('filterCidade').value
  const conn = document.getElementById('filterConector').value
  const filtered = allData.filter(function(p){
    if (tipo && p.tipo_ponto !== tipo) return false
    if (cidade && p.cidade !== cidade) return false
    if (conn && !(p.conectores||'').includes(conn)) return false
    return true
  })
  renderMarkers(filtered)
}

loadMap()
