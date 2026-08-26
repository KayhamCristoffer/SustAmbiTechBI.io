// dashboard.js — SustAmbiTech Eletropostos
const API = ''
let allPostos = [], chartsInit = {}

const wmoCode = {0:'Céu limpo',1:'Principalmente limpo',2:'Parcialmente nublado',3:'Nublado',45:'Névoa',51:'Garoa leve',53:'Garoa moderada',61:'Chuva leve',63:'Chuva moderada',65:'Chuva forte',80:'Pancada leve',81:'Pancada moderada',95:'Tempestade'}
const wmoIcon = {0:'☀️',1:'🌤️',2:'⛅',3:'☁️',45:'🌫️',51:'🌦️',53:'🌦️',61:'🌧️',63:'🌧️',65:'⛈️',80:'🌦️',81:'🌧️',95:'⛈️'}
const weekDay = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb']

async function loadData() {
  const [resumo, postos, clima] = await Promise.all([
    fetch('/api/resumo').then(r=>r.json()),
    fetch('/api/postos?limit=200').then(r=>r.json()),
    fetch('/api/clima').then(r=>r.json()).catch(()=>null)
  ])
  renderKPIs(resumo)
  renderPostos(postos.data || [])
  renderCidadesChart(resumo.por_cidade || [])
  renderConectoresChart(resumo.conectores || [])
  renderConectoresList(resumo.conectores || [])
  renderVeiculos()
  if (clima) renderClima(clima)
  const sel = document.getElementById('cityFilter')
  sel.innerHTML = '<option value="">Todas</option>' +
    (resumo.por_cidade||[]).map(function(c){ return '<option>'+c.cidade+'</option>' }).join('')
  window._cidadesData = resumo.por_cidade || []
}

function renderKPIs(d) {
  document.getElementById('kpiTotal').textContent = d.resumo ? d.resumo.ativos : 0
  document.getElementById('kpiCidades').textContent = (d.por_cidade||[]).length
  document.getElementById('kpiConectores').textContent = (d.conectores||[]).length
  const tomadas = (d.conectores||[]).reduce(function(s,c){ return s+(c.total_tomadas||0) },0)
  document.getElementById('kpiTomadas').textContent = tomadas
}

function renderPostos(data) {
  allPostos = data
  const tbody = document.getElementById('postosBody')
  const filtered = data.filter(function(p){ return p.tipo_ponto==='Posto Eletro' })
  const html = filtered.map(function(p){
    const conns = (p.conectores||'').split(',').filter(Boolean)
    const tags = conns.map(function(c){ return '<span class="conector-badge border-blue-700 text-blue-300">'+c+'</span>' }).join(' ')
    const nota = p.media_nota ? '<span class="text-yellow-400">&#9733;'+p.media_nota+'</span>' : '<span class="text-gray-600">—</span>'
    const status = p.ativo ? '<span class="tag tag-green">Ativo</span>' : '<span class="tag tag-red">Inativo</span>'
    return '<tr><td class="font-medium text-white">'+p.nome+'</td><td class="text-gray-400 text-sm">'+p.cidade+'<br><span class="text-xs">'+(p.bairro||'')+'</span></td><td>'+tags+'</td><td>'+nota+'</td><td>'+status+'</td></tr>'
  }).join('')
  tbody.innerHTML = html || '<tr><td colspan="5" class="text-center text-gray-500 py-4">Nenhum resultado</td></tr>'
}

function filterTable() {
  const q = document.getElementById('searchInput').value.toLowerCase()
  const city = document.getElementById('cityFilter').value
  const filtered = allPostos.filter(function(p){
    const match = !q || (p.nome&&p.nome.toLowerCase().includes(q)) || (p.bairro&&p.bairro.toLowerCase().includes(q)) || (p.rua&&p.rua.toLowerCase().includes(q))
    const cityMatch = !city || p.cidade === city
    return match && cityMatch
  })
  renderPostos(filtered)
}

function renderCidadesChart(data) {
  if (chartsInit.cidades) chartsInit.cidades.destroy()
  const ctx = document.getElementById('chartCidades').getContext('2d')
  chartsInit.cidades = new Chart(ctx, {
    type: 'bar',
    data: { labels: data.map(function(d){ return d.cidade }), datasets: [{ label: 'Eletropostos', data: data.map(function(d){ return d.quantidade }), backgroundColor: '#3b82f6' }] },
    options: { responsive:true, plugins:{legend:{display:false}}, scales:{x:{ticks:{color:'#94a3b8'}},y:{ticks:{color:'#94a3b8'},grid:{color:'#1e293b'}}} }
  })
}

function renderConectoresChart(data) {
  if (chartsInit.conn) chartsInit.conn.destroy()
  if (chartsInit.cidade2) chartsInit.cidade2.destroy()
  const colors = ['#3b82f6','#22c55e','#f59e0b','#a855f7','#ef4444','#06b6d4']
  const ctx1 = document.getElementById('chartConectores').getContext('2d')
  chartsInit.conn = new Chart(ctx1, {
    type: 'doughnut',
    data: { labels: data.map(function(d){ return d.codigo }), datasets: [{ data: data.map(function(d){ return d.num_postos }), backgroundColor: colors }] },
    options: { plugins:{legend:{labels:{color:'#e2e8f0'}}} }
  })
  const ctx2 = document.getElementById('chartPostosCidade').getContext('2d')
  chartsInit.cidade2 = new Chart(ctx2, {
    type: 'bar',
    data: {
      labels: data.map(function(d){ return d.codigo }),
      datasets: [
        { label: 'Postos', data: data.map(function(d){ return d.num_postos }), backgroundColor: '#3b82f6' },
        { label: 'Tomadas', data: data.map(function(d){ return d.total_tomadas }), backgroundColor: '#22c55e' }
      ]
    },
    options: { plugins:{legend:{labels:{color:'#e2e8f0'}}}, scales:{x:{ticks:{color:'#94a3b8'}},y:{ticks:{color:'#94a3b8'},grid:{color:'#1e293b'}}} }
  })
}

function renderConectoresList(data) {
  const el = document.getElementById('conectoresList')
  el.innerHTML = data.map(function(c){
    const cor = c.corrente==='DC' ? 'text-red-400' : 'text-blue-400'
    const bg  = c.corrente==='DC' ? 'border-red-700' : 'border-blue-700'
    return '<div class="card p-3 flex items-center justify-between '+bg+' border mb-2">' +
      '<div><div class="font-bold text-white">'+c.codigo+' — '+c.nome+'</div>' +
      '<div class="text-xs text-gray-400">'+c.nivel+' | '+c.potencia_max_kw+'kW max | '+(c.descricao||'')+'</div></div>' +
      '<div class="text-right"><div class="font-bold '+cor+'">'+c.num_postos+' postos</div>' +
      '<div class="text-xs text-gray-400">'+(c.total_tomadas||0)+' tomadas</div></div></div>'
  }).join('')
}

async function renderVeiculos() {
  const r = await fetch('/api/veiculos').then(function(x){ return x.json() })
  const el = document.getElementById('veiculosList')
  el.innerHTML = r.data.map(function(v){
    const conns = (v.conectores_compativeis||'').split(',').filter(Boolean)
    const tags = conns.map(function(c){ return '<span class="tag tag-blue mr-1">'+c+'</span>' }).join('')
    return '<div class="card p-3 mb-2">' +
      '<div class="flex items-start justify-between">' +
      '<div><span class="font-bold text-white">'+v.categoria+'</span>' +
      '<span class="text-gray-400 ml-2">— '+v.nome+'</span>' +
      '<div class="text-xs text-gray-500 mt-1">'+v.exemplo_modelos+'</div>' +
      '<div class="text-xs text-gray-400 mt-1">'+v.descricao+'</div></div>' +
      '<div class="text-right text-xs text-green-400">'+tags+'</div></div></div>'
  }).join('')
}

function renderClima(d) {
  const atual = d.atual && d.atual.current
  if (atual) {
    document.getElementById('tempAtual').textContent = Math.round(atual.temperature_2m) + '°C'
    document.getElementById('condicaoAtual').textContent = (wmoIcon[atual.weather_code]||'🌡️') + ' ' + (wmoCode[atual.weather_code]||'')
    const daily = d.atual && d.atual.daily
    if (daily) {
      document.getElementById('tempMax').textContent = Math.round(daily.temperature_2m_max[0]) + '°C'
      document.getElementById('tempMin').textContent = Math.round(daily.temperature_2m_min[0]) + '°C'
      const semana = document.getElementById('previsaoSemana')
      semana.innerHTML = daily.time.slice(0,7).map(function(date,i){
        const d2 = new Date(date)
        const icon = wmoIcon[daily.weathercode ? daily.weathercode[i] : 0] || '🌡️'
        return '<div class="clima-day flex-shrink-0"><div class="text-xs text-gray-400">'+weekDay[d2.getDay()]+'</div>' +
          '<div class="text-lg">'+icon+'</div>' +
          '<div class="text-sm font-bold">'+Math.round(daily.temperature_2m_max[i])+'°</div>' +
          '<div class="text-xs text-blue-400">'+Math.round(daily.temperature_2m_min[i])+'°</div></div>'
      }).join('')
    }
  }
  if (d.historico && d.historico.length) {
    const hist = d.historico.slice(0,12).reverse()
    if (chartsInit.clima) chartsInit.clima.destroy()
    const ctx = document.getElementById('chartClima').getContext('2d')
    chartsInit.clima = new Chart(ctx, {
      type: 'line',
      data: {
        labels: hist.map(function(h){ return h.data.slice(5) }),
        datasets: [
          { label: 'Máx', data: hist.map(function(h){ return h.temperatura_max }), borderColor:'#ef4444', tension:.4, fill:false, borderWidth:2, pointRadius:2 },
          { label: 'Mín', data: hist.map(function(h){ return h.temperatura_min }), borderColor:'#3b82f6', tension:.4, fill:false, borderWidth:2, pointRadius:2 }
        ]
      },
      options: { plugins:{legend:{labels:{color:'#e2e8f0',font:{size:10}}}}, scales:{x:{ticks:{color:'#64748b',font:{size:9}}},y:{ticks:{color:'#64748b',font:{size:9}},grid:{color:'#1e293b'}}} }
    })
  }
}

function showTab(tab) {
  document.querySelectorAll('[id^="tab-"]').forEach(function(el){ el.style.display='none' })
  document.getElementById('tab-'+tab).style.display='block'
  document.querySelectorAll('.tab-btn').forEach(function(b){ b.classList.remove('active') })
  event.target.classList.add('active')
}

loadData()
