// upload.js — SustAmbiTech Importação Excel
let parsedData = []

document.getElementById('dropZone').addEventListener('dragover', function(ev){
  ev.preventDefault(); this.classList.add('drag')
})
document.getElementById('dropZone').addEventListener('dragleave', function(){
  this.classList.remove('drag')
})
document.getElementById('dropZone').addEventListener('drop', function(ev){
  ev.preventDefault(); this.classList.remove('drag')
  const f = ev.dataTransfer.files[0]
  if (f) handleFile(f)
})
document.getElementById('dropZone').addEventListener('click', function(){
  document.getElementById('fileInput').click()
})
document.getElementById('fileInput').addEventListener('change', function(){
  if (this.files[0]) handleFile(this.files[0])
})

function handleFile(file) {
  const reader = new FileReader()
  reader.onload = function(e) {
    const wb = XLSX.read(e.target.result, {type:'array'})
    const ws = wb.Sheets[wb.SheetNames[0]]
    const data = XLSX.utils.sheet_to_json(ws, {defval:''})
    parsedData = data
    showPreview(data)
  }
  reader.readAsArrayBuffer(file)
}

function showPreview(data) {
  if (!data.length) return
  const cols = Object.keys(data[0])
  document.getElementById('rowCount').textContent = data.length
  document.getElementById('previewHead').innerHTML = '<tr>' + cols.map(function(c){ return '<th>'+c+'</th>' }).join('') + '</tr>'
  document.getElementById('previewBody').innerHTML = data.slice(0,5).map(function(r){
    return '<tr>' + cols.map(function(c){ return '<td class="text-gray-300">'+r[c]+'</td>' }).join('') + '</tr>'
  }).join('')
  document.getElementById('preview').style.display = 'block'
}

async function importar() {
  if (!parsedData.length) return
  const btn = document.getElementById('btnImportar')
  btn.disabled = true; btn.textContent = 'Importando...'
  const res = await fetch('/api/upload/postos', {
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body: JSON.stringify({ registros: parsedData, arquivo: 'upload.xlsx' })
  }).then(function(r){ return r.json() })
  const el = document.getElementById('resultado')
  el.style.display = 'block'
  if (res.success) {
    el.innerHTML = '<div class="text-green-400 font-bold">&#10003; Importação concluída!</div>' +
      '<div class="text-sm mt-1">&#10004; '+res.importados+' registros importados | &#10006; '+res.erros+' erros</div>' +
      (res.detalhes&&res.detalhes.length ? '<div class="text-red-400 text-xs mt-2">'+res.detalhes.join('<br>')+'</div>' : '')
  } else {
    el.innerHTML = '<div class="text-red-400">&#10006; Erro: '+(res.error||'desconhecido')+'</div>'
  }
  btn.disabled = false
  btn.innerHTML = '<i class="fas fa-cloud-upload-alt mr-1"></i>Importar'
  loadLog()
}

function baixarTemplate() {
  const ws = XLSX.utils.json_to_sheet([{
    nome:'Eletroposto Exemplo', cidade:'São Paulo', latitude:-23.55, longitude:-46.63,
    rua:'Av. Paulista', numero:'1000', bairro:'Bela Vista', estado:'SP', cep:'01310-100',
    tipo_ponto:'Posto Eletro', acesso:'público', horario_funcionamento:'24h', observacoes:'Exemplo'
  }])
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Postos')
  XLSX.writeFile(wb, 'template_eletropostos.xlsx')
}

async function loadLog() {
  try {
    const r = await fetch('/api/log').then(function(x){ return x.json() })
    const el = document.getElementById('logList')
    if (!r.data||!r.data.length) { el.textContent = 'Nenhuma importação registrada.'; return }
    el.innerHTML = '<table><thead><tr><th>Arquivo</th><th>Tipo</th><th>Importados</th><th>Erros</th><th>Data</th></tr></thead><tbody>' +
      r.data.map(function(l){
        return '<tr><td>'+(l.arquivo_nome||'—')+'</td><td>'+l.tipo+'</td><td class="text-green-400">'+l.registros_importados+'</td><td class="text-red-400">'+l.registros_erros+'</td><td class="text-gray-500">'+((l.importado_em||'').slice(0,16)||'—')+'</td></tr>'
      }).join('') + '</tbody></table>'
  } catch(e) { console.error(e) }
}
loadLog()
