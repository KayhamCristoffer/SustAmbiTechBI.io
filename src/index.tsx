import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { serveStatic } from 'hono/cloudflare-workers'

type Bindings = {
  DB: D1Database
}

const app = new Hono<{ Bindings: Bindings }>()

// CORS para integração com Power BI
app.use('/*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowHeaders: ['Content-Type', 'Authorization']
}))

// Servir arquivos estáticos
app.use('/static/*', serveStatic({ root: './' }))

// ============================================================
// FUNÇÕES UTILITÁRIAS
// ============================================================

function toCSV(data: any[], columns?: string[]): string {
  if (!data || data.length === 0) return ''
  const keys = columns || Object.keys(data[0])
  const header = keys.join(',')
  const rows = data.map(row =>
    keys.map(k => {
      const v = row[k]
      if (v === null || v === undefined) return ''
      const str = String(v)
      return str.includes(',') || str.includes('"') || str.includes('\n')
        ? `"${str.replace(/"/g, '""')}"` : str
    }).join(',')
  )
  return [header, ...rows].join('\n')
}

// ============================================================
// PÁGINA PRINCIPAL - DASHBOARD
// ============================================================
app.get('/', (c) => {
  return c.html(htmlDashboard())
})

// Mapa Mental
app.get('/mindmap', (c) => {
  return c.html(htmlMindMap())
})

// ============================================================
// APIs REST - DADOS PARA POWER BI
// ============================================================

// --- RESUMO GERAL (KPIs) ---
app.get('/api/kpis', async (c) => {
  try {
    const db = c.env.DB
    const [
      usuarios,
      denuncias,
      reciclagem,
      educacao,
      ecopontos,
      alertas
    ] = await Promise.all([
      db.prepare('SELECT COUNT(*) as total, SUM(pontos_sustentabilidade) as total_pontos FROM dim_usuarios WHERE ativo=1').first(),
      db.prepare("SELECT COUNT(*) as total, SUM(CASE WHEN status='resolvido' THEN 1 ELSE 0 END) as resolvidas FROM fato_denuncias").first(),
      db.prepare('SELECT COUNT(*) as coletas, ROUND(SUM(quantidade_kg),2) as total_kg, ROUND(SUM(co2_evitado_kg),2) as co2_evitado FROM fato_reciclagem').first(),
      db.prepare('SELECT COUNT(*) as total, SUM(CASE WHEN concluido=1 THEN 1 ELSE 0 END) as concluidas, SUM(pontuacao) as total_pontos FROM fato_educacao_ambiental').first(),
      db.prepare('SELECT COUNT(*) as total, SUM(CASE WHEN ativo=1 THEN 1 ELSE 0 END) as ativos FROM fato_ecopontos').first(),
      db.prepare("SELECT COUNT(*) as total, SUM(CASE WHEN severidade='critico' THEN 1 ELSE 0 END) as criticos FROM tb_alertas WHERE ativo=1").first()
    ])
    return c.json({ usuarios, denuncias, reciclagem, educacao, ecopontos, alertas })
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- QUALIDADE DO AR ---
app.get('/api/qualidade-ar', async (c) => {
  try {
    const limit = Number(c.req.query('limit') || 100)
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT q.*, r.nome as regiao_nome, r.estado, r.regiao_brasil
      FROM fato_qualidade_ar q
      LEFT JOIN dim_regioes r ON q.regiao_id = r.id
      ORDER BY q.data_medicao DESC LIMIT ?
    `).bind(limit).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="qualidade_ar.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- QUALIDADE DA ÁGUA ---
app.get('/api/qualidade-agua', async (c) => {
  try {
    const limit = Number(c.req.query('limit') || 100)
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT q.*, r.nome as regiao_nome, r.estado, r.regiao_brasil
      FROM fato_qualidade_agua q
      LEFT JOIN dim_regioes r ON q.regiao_id = r.id
      ORDER BY q.data_medicao DESC LIMIT ?
    `).bind(limit).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="qualidade_agua.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- CONSUMO DE ENERGIA ---
app.get('/api/energia', async (c) => {
  try {
    const limit = Number(c.req.query('limit') || 200)
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT e.*, r.nome as regiao_nome, r.estado, r.regiao_brasil,
             f.nome as fonte_nome, f.tipo as fonte_tipo, f.renovavel
      FROM fato_consumo_energia e
      LEFT JOIN dim_regioes r ON e.regiao_id = r.id
      LEFT JOIN dim_fontes_energia f ON e.fonte_energia_id = f.id
      ORDER BY e.data_referencia DESC LIMIT ?
    `).bind(limit).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="energia.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// Resumo por fonte de energia
app.get('/api/energia/por-fonte', async (c) => {
  try {
    const data = await c.env.DB.prepare(`
      SELECT f.nome as fonte, f.tipo, f.renovavel,
             ROUND(SUM(e.consumo_kwh),0) as total_kwh,
             ROUND(SUM(e.emissao_co2_kg),0) as total_co2_kg,
             ROUND(SUM(e.custo_real),2) as total_custo,
             COUNT(*) as registros
      FROM fato_consumo_energia e
      LEFT JOIN dim_fontes_energia f ON e.fonte_energia_id = f.id
      GROUP BY f.id, f.nome, f.tipo, f.renovavel
      ORDER BY total_kwh DESC
    `).all()
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// Evolução mensal de consumo
app.get('/api/energia/evolucao', async (c) => {
  try {
    const data = await c.env.DB.prepare(`
      SELECT strftime('%Y-%m', data_referencia) as mes,
             ROUND(SUM(consumo_kwh),0) as total_kwh,
             ROUND(SUM(emissao_co2_kg),0) as total_co2_kg,
             ROUND(SUM(custo_real),2) as total_custo
      FROM fato_consumo_energia
      GROUP BY mes ORDER BY mes ASC
    `).all()
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- RECICLAGEM ---
app.get('/api/reciclagem', async (c) => {
  try {
    const limit = Number(c.req.query('limit') || 200)
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT rc.*, r.nome as regiao_nome, r.estado, r.regiao_brasil,
             t.nome as tipo_residuo, t.classificacao, t.cor_padrao_separacao,
             u.nome as usuario_nome, u.tipo_usuario
      FROM fato_reciclagem rc
      LEFT JOIN dim_regioes r ON rc.regiao_id = r.id
      LEFT JOIN dim_tipos_residuos t ON rc.tipo_residuo_id = t.id
      LEFT JOIN dim_usuarios u ON rc.usuario_id = u.id
      ORDER BY rc.data_coleta DESC LIMIT ?
    `).bind(limit).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="reciclagem.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// Reciclagem por tipo de resíduo
app.get('/api/reciclagem/por-tipo', async (c) => {
  try {
    const data = await c.env.DB.prepare(`
      SELECT t.nome as tipo, t.classificacao, t.cor_padrao_separacao,
             ROUND(SUM(rc.quantidade_kg),2) as total_kg,
             ROUND(SUM(rc.co2_evitado_kg),2) as co2_evitado,
             ROUND(SUM(rc.valor_arrecadado),2) as valor_total,
             COUNT(*) as coletas
      FROM fato_reciclagem rc
      LEFT JOIN dim_tipos_residuos t ON rc.tipo_residuo_id = t.id
      GROUP BY t.id, t.nome, t.classificacao, t.cor_padrao_separacao
      ORDER BY total_kg DESC
    `).all()
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- VEÍCULOS ELÉTRICOS ---
app.get('/api/veiculos-eletricos', async (c) => {
  try {
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT v.*, r.nome as regiao_nome, r.estado, r.regiao_brasil
      FROM fato_veiculos_eletricos v
      LEFT JOIN dim_regioes r ON v.regiao_id = r.id
      ORDER BY v.data_referencia DESC, v.regiao_id ASC
    `).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="veiculos_eletricos.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// Evolução da frota
app.get('/api/veiculos-eletricos/evolucao', async (c) => {
  try {
    const data = await c.env.DB.prepare(`
      SELECT strftime('%Y', data_referencia) as ano,
             SUM(total_veiculos_eletricos) as total_eletricos,
             SUM(total_hibridos) as total_hibridos,
             SUM(novos_emplacamentos_eletricos) as novos_emplacamentos,
             SUM(eletropostos_ativos) as total_eletropostos,
             ROUND(SUM(co2_evitado_kg)/1000,2) as co2_evitado_ton
      FROM fato_veiculos_eletricos
      GROUP BY ano ORDER BY ano ASC
    `).all()
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- INDICADORES CLIMÁTICOS ---
app.get('/api/clima', async (c) => {
  try {
    const limit = Number(c.req.query('limit') || 200)
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT c.*, r.nome as regiao_nome, r.estado, r.regiao_brasil
      FROM fato_indicadores_climaticos c
      LEFT JOIN dim_regioes r ON c.regiao_id = r.id
      ORDER BY c.data_referencia DESC LIMIT ?
    `).bind(limit).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="clima.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- COBERTURA VEGETAL ---
app.get('/api/cobertura-vegetal', async (c) => {
  try {
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT cv.*, r.nome as regiao_nome, r.estado, r.regiao_brasil
      FROM fato_cobertura_vegetal cv
      LEFT JOIN dim_regioes r ON cv.regiao_id = r.id
      ORDER BY cv.data_referencia DESC, cv.regiao_id ASC
    `).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="cobertura_vegetal.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- EDUCAÇÃO AMBIENTAL ---
app.get('/api/educacao', async (c) => {
  try {
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT e.*, u.nome as usuario_nome, u.tipo_usuario,
             r.nome as regiao_nome, r.estado,
             cat.nome as categoria_nome
      FROM fato_educacao_ambiental e
      LEFT JOIN dim_usuarios u ON e.usuario_id = u.id
      LEFT JOIN dim_regioes r ON e.regiao_id = r.id
      LEFT JOIN dim_categorias cat ON e.categoria_id = cat.id
      ORDER BY e.data_atividade DESC LIMIT 500
    `).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="educacao_ambiental.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- DENÚNCIAS ---
app.get('/api/denuncias', async (c) => {
  try {
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT d.*, r.nome as regiao_nome, r.estado, r.regiao_brasil,
             u.nome as usuario_nome, u.tipo_usuario
      FROM fato_denuncias d
      LEFT JOIN dim_regioes r ON d.regiao_id = r.id
      LEFT JOIN dim_usuarios u ON d.usuario_id = u.id
      ORDER BY d.data_denuncia DESC LIMIT 500
    `).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="denuncias.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- ECOPONTOS ---
app.get('/api/ecopontos', async (c) => {
  try {
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT e.*, r.regiao_brasil
      FROM fato_ecopontos e
      LEFT JOIN dim_regioes r ON e.regiao_id = r.id
      ORDER BY e.avaliacao_media DESC
    `).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="ecopontos.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- KPIs E METAS ---
app.get('/api/metas', async (c) => {
  try {
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT m.*, cat.nome as categoria_nome, cat.cor_hex, cat.ods_relacionado
      FROM tb_kpis_metas m
      LEFT JOIN dim_categorias cat ON m.categoria_id = cat.id
      ORDER BY m.ano_referencia DESC, m.percentual_atingimento DESC
    `).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="kpis_metas.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- ALERTAS ---
app.get('/api/alertas', async (c) => {
  try {
    const data = await c.env.DB.prepare(`
      SELECT a.*, r.nome as regiao_nome, r.estado
      FROM tb_alertas a
      LEFT JOIN dim_regioes r ON a.regiao_id = r.id
      WHERE a.ativo = 1
      ORDER BY CASE a.severidade 
        WHEN 'emergencia' THEN 1 
        WHEN 'critico' THEN 2 
        WHEN 'aviso' THEN 3 
        ELSE 4 END, a.data_alerta DESC
    `).all()
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- REGIÕES ---
app.get('/api/regioes', async (c) => {
  try {
    const data = await c.env.DB.prepare('SELECT * FROM dim_regioes ORDER BY nome ASC').all()
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// --- ANÁLISES AGGREGADAS PARA BI ---
app.get('/api/bi/resumo-regional', async (c) => {
  try {
    const format = c.req.query('format') || 'json'
    const data = await c.env.DB.prepare(`
      SELECT r.nome as regiao, r.estado, r.regiao_brasil,
        (SELECT COUNT(*) FROM dim_usuarios u WHERE u.regiao_id = r.id) as total_usuarios,
        (SELECT ROUND(AVG(q.indice_qualidade_ar),1) FROM fato_qualidade_ar q WHERE q.regiao_id = r.id) as iqa_medio,
        (SELECT ROUND(AVG(qa.indice_qualidade_agua),1) FROM fato_qualidade_agua qa WHERE qa.regiao_id = r.id) as iqa_agua_medio,
        (SELECT SUM(rc.quantidade_kg) FROM fato_reciclagem rc WHERE rc.regiao_id = r.id) as total_reciclado_kg,
        (SELECT COUNT(*) FROM fato_denuncias d WHERE d.regiao_id = r.id) as total_denuncias,
        (SELECT SUM(e.consumo_kwh) FROM fato_consumo_energia e WHERE e.regiao_id = r.id) as consumo_energia_kwh
      FROM dim_regioes r
      ORDER BY r.nome ASC
    `).all()
    if (format === 'csv') {
      c.header('Content-Type', 'text/csv')
      c.header('Content-Disposition', 'attachment; filename="resumo_regional.csv"')
      return c.text(toCSV(data.results))
    }
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// Análise temporal
app.get('/api/bi/tendencias', async (c) => {
  try {
    const data = await c.env.DB.prepare(`
      SELECT 
        strftime('%Y-%m', data_coleta) as mes,
        ROUND(SUM(quantidade_kg),2) as reciclagem_kg,
        ROUND(SUM(co2_evitado_kg),2) as co2_evitado_kg,
        COUNT(*) as num_coletas
      FROM fato_reciclagem
      GROUP BY mes
      ORDER BY mes ASC
    `).all()
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// Análise de emissões por fonte
app.get('/api/bi/emissoes-co2', async (c) => {
  try {
    const data = await c.env.DB.prepare(`
      SELECT 
        strftime('%Y-%m', e.data_referencia) as mes,
        r.regiao_brasil,
        f.tipo as tipo_fonte,
        ROUND(SUM(e.emissao_co2_kg)/1000,2) as co2_toneladas,
        ROUND(SUM(e.consumo_kwh)/1000,2) as consumo_mwh,
        SUM(CASE WHEN f.renovavel=1 THEN e.consumo_kwh ELSE 0 END) as kwh_renovavel,
        SUM(CASE WHEN f.renovavel=0 THEN e.consumo_kwh ELSE 0 END) as kwh_nao_renovavel
      FROM fato_consumo_energia e
      LEFT JOIN dim_fontes_energia f ON e.fonte_energia_id = f.id
      LEFT JOIN dim_regioes r ON e.regiao_id = r.id
      GROUP BY mes, r.regiao_brasil, f.tipo
      ORDER BY mes ASC
    `).all()
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// Ranking de denúncias
app.get('/api/bi/ranking-denuncias', async (c) => {
  try {
    const data = await c.env.DB.prepare(`
      SELECT r.nome as regiao, r.estado, r.regiao_brasil,
        COUNT(*) as total_denuncias,
        SUM(CASE WHEN d.status='resolvido' THEN 1 ELSE 0 END) as resolvidas,
        SUM(CASE WHEN d.status='pendente' THEN 1 ELSE 0 END) as pendentes,
        SUM(CASE WHEN d.impacto_estimado='critico' THEN 1 ELSE 0 END) as criticas,
        ROUND(100.0 * SUM(CASE WHEN d.status='resolvido' THEN 1 ELSE 0 END) / COUNT(*), 1) as taxa_resolucao
      FROM fato_denuncias d
      LEFT JOIN dim_regioes r ON d.regiao_id = r.id
      GROUP BY r.id, r.nome, r.estado, r.regiao_brasil
      ORDER BY total_denuncias DESC
    `).all()
    return c.json(data.results)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

// Schema das tabelas (documentação para Power BI)
app.get('/api/schema', async (c) => {
  return c.json({
    version: '1.0.0',
    descricao: 'SustAmbiTech - Schema do banco de dados para integração com Power BI',
    tabelas: {
      dimensoes: ['dim_regioes', 'dim_categorias', 'dim_usuarios', 'dim_tipos_residuos', 'dim_fontes_energia', 'dim_especies'],
      fatos: ['fato_qualidade_ar', 'fato_qualidade_agua', 'fato_consumo_energia', 'fato_reciclagem', 'fato_veiculos_eletricos', 'fato_indicadores_climaticos', 'fato_cobertura_vegetal', 'fato_educacao_ambiental', 'fato_denuncias', 'fato_consumo_consciente', 'fato_politicas_ambientais', 'fato_ecopontos'],
      suporte: ['tb_kpis_metas', 'tb_alertas', 'tb_logs_atividade']
    },
    endpoints_powerbi: {
      kpis: '/api/kpis',
      qualidade_ar: '/api/qualidade-ar?format=csv',
      qualidade_agua: '/api/qualidade-agua?format=csv',
      energia: '/api/energia?format=csv',
      energia_por_fonte: '/api/energia/por-fonte',
      reciclagem: '/api/reciclagem?format=csv',
      reciclagem_por_tipo: '/api/reciclagem/por-tipo',
      veiculos_eletricos: '/api/veiculos-eletricos?format=csv',
      evolucao_frota: '/api/veiculos-eletricos/evolucao',
      clima: '/api/clima?format=csv',
      cobertura_vegetal: '/api/cobertura-vegetal?format=csv',
      educacao: '/api/educacao?format=csv',
      denuncias: '/api/denuncias?format=csv',
      ecopontos: '/api/ecopontos?format=csv',
      metas: '/api/metas?format=csv',
      alertas: '/api/alertas',
      resumo_regional: '/api/bi/resumo-regional?format=csv',
      tendencias: '/api/bi/tendencias',
      emissoes_co2: '/api/bi/emissoes-co2',
      ranking_denuncias: '/api/bi/ranking-denuncias'
    }
  })
})

// ============================================================
// HTML: DASHBOARD PRINCIPAL
// ============================================================
function htmlDashboard(): string {
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SustAmbiTech BI - Dashboard Ambiental</title>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<link href="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.4.0/css/all.min.css" rel="stylesheet">
<style>
  :root {
    --green-dark: #1a3d1a;
    --green-mid: #2d6a2d;
    --green-light: #4CAF50;
    --green-pale: #8BC34A;
    --bg: #0f2010;
    --card: #162516;
    --border: #2a5c2a;
    --text: #e8f5e9;
    --text-muted: #a5d6a7;
  }
  body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', sans-serif; }
  .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 1.5rem; }
  .kpi-card { background: linear-gradient(135deg, var(--green-mid), var(--green-dark)); border: 1px solid var(--green-light); border-radius: 12px; padding: 1.25rem; }
  .nav-btn { color: var(--text-muted); padding: 0.5rem 1rem; border-radius: 8px; cursor: pointer; transition: all 0.2s; text-decoration: none; display: inline-block; }
  .nav-btn:hover, .nav-btn.active { background: var(--green-mid); color: white; }
  .chart-container { position: relative; height: 280px; }
  .badge { display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 0.75rem; font-weight: 600; }
  .badge-green { background: #1b5e20; color: #a5d6a7; }
  .badge-yellow { background: #f57f17; color: #fff9c4; }
  .badge-red { background: #b71c1c; color: #ffcdd2; }
  .badge-blue { background: #0d47a1; color: #bbdefb; }
  .tab { cursor: pointer; padding: 0.5rem 1.25rem; border-radius: 8px; font-weight: 600; color: var(--text-muted); }
  .tab.active { background: var(--green-light); color: white; }
  .tab-content { display: none; }
  .tab-content.active { display: block; }
  table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
  th { background: var(--green-dark); color: var(--green-pale); padding: 0.75rem; text-align: left; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; }
  td { padding: 0.6rem 0.75rem; border-bottom: 1px solid var(--border); color: var(--text); }
  tr:hover td { background: #1f3d1f; }
  .progress-bar { background: #1a3d1a; border-radius: 99px; height: 8px; overflow: hidden; }
  .progress-fill { height: 100%; border-radius: 99px; background: linear-gradient(90deg, var(--green-pale), var(--green-light)); }
  .api-tag { background: #0d2d0d; border: 1px solid #2a5c2a; border-radius: 6px; padding: 4px 10px; font-family: monospace; font-size: 0.8rem; color: #81c784; display: inline-block; margin: 2px; }
  ::-webkit-scrollbar { width: 6px; height: 6px; }
  ::-webkit-scrollbar-track { background: var(--bg); }
  ::-webkit-scrollbar-thumb { background: var(--green-mid); border-radius: 3px; }
  .alert-critico { border-left: 4px solid #f44336; }
  .alert-aviso { border-left: 4px solid #ff9800; }
  .alert-info { border-left: 4px solid #2196F3; }
</style>
</head>
<body>

<!-- NAVBAR -->
<nav style="background: #0d1f0d; border-bottom: 1px solid #2a5c2a;" class="sticky top-0 z-50">
  <div class="max-w-screen-xl mx-auto px-4 py-3 flex items-center justify-between">
    <div class="flex items-center gap-3">
      <div class="w-9 h-9 rounded-lg flex items-center justify-center" style="background: linear-gradient(135deg, #4CAF50, #2d6a2d)">
        <i class="fas fa-leaf text-white text-sm"></i>
      </div>
      <div>
        <h1 class="font-bold text-base" style="color: #8BC34A">SustAmbiTech BI</h1>
        <p class="text-xs" style="color: #66bb6a">Plataforma de Inteligência Ambiental</p>
      </div>
    </div>
    <div class="flex items-center gap-2">
      <a href="/" class="nav-btn active text-sm"><i class="fas fa-chart-line mr-1"></i>Dashboard</a>
      <a href="/mindmap" class="nav-btn text-sm"><i class="fas fa-project-diagram mr-1"></i>Mapa Mental</a>
      <a href="/api/schema" target="_blank" class="nav-btn text-sm"><i class="fas fa-code mr-1"></i>API Docs</a>
    </div>
  </div>
</nav>

<!-- MAIN -->
<main class="max-w-screen-xl mx-auto px-4 py-6">

  <!-- HEADER -->
  <div class="flex items-center justify-between mb-6">
    <div>
      <h2 class="text-2xl font-bold" style="color: #a5d6a7">Painel de Indicadores Ambientais</h2>
      <p class="text-sm mt-1" style="color: #66bb6a">Dados integrados e prontos para exportação ao Power BI</p>
    </div>
    <div class="flex gap-2">
      <span id="last-update" class="text-xs" style="color: #66bb6a; padding: 0.4rem 0.8rem; background: #0d2d0d; border-radius: 6px; border: 1px solid #2a5c2a">
        <i class="fas fa-sync-alt mr-1"></i>Carregando...
      </span>
    </div>
  </div>

  <!-- ALERTAS -->
  <div id="alertas-container" class="mb-6 space-y-2"></div>

  <!-- KPIs -->
  <div id="kpis-grid" class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-6"></div>

  <!-- TABS -->
  <div class="flex flex-wrap gap-2 mb-6">
    <button class="tab active" onclick="showTab('visao-geral')"><i class="fas fa-globe mr-1"></i>Visão Geral</button>
    <button class="tab" onclick="showTab('energia')"><i class="fas fa-bolt mr-1"></i>Energia</button>
    <button class="tab" onclick="showTab('reciclagem')"><i class="fas fa-recycle mr-1"></i>Reciclagem</button>
    <button class="tab" onclick="showTab('veiculos')"><i class="fas fa-car mr-1"></i>Mobilidade</button>
    <button class="tab" onclick="showTab('qualidade')"><i class="fas fa-wind mr-1"></i>Qualidade</button>
    <button class="tab" onclick="showTab('metas')"><i class="fas fa-target mr-1"></i>Metas & KPIs</button>
    <button class="tab" onclick="showTab('powerbi')"><i class="fas fa-plug mr-1"></i>Power BI</button>
  </div>

  <!-- TAB: VISÃO GERAL -->
  <div id="tab-visao-geral" class="tab-content active">
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-chart-bar mr-2"></i>Reciclagem por Tipo (kg)</h3>
        <div class="chart-container"><canvas id="chartResiduos"></canvas></div>
      </div>
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-chart-pie mr-2"></i>Frota Veículos (2024)</h3>
        <div class="chart-container"><canvas id="chartFrota"></canvas></div>
      </div>
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-chart-line mr-2"></i>Evolução da Frota Elétrica (SP)</h3>
        <div class="chart-container"><canvas id="chartEvolucaoFrota"></canvas></div>
      </div>
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-bell mr-2"></i>Denúncias por Região</h3>
        <div class="chart-container"><canvas id="chartDenuncias"></canvas></div>
      </div>
    </div>
  </div>

  <!-- TAB: ENERGIA -->
  <div id="tab-energia" class="tab-content">
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-bolt mr-2"></i>Consumo por Fonte de Energia</h3>
        <div class="chart-container"><canvas id="chartEnergiaPorFonte"></canvas></div>
      </div>
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-chart-line mr-2"></i>Evolução Mensal de Consumo</h3>
        <div class="chart-container"><canvas id="chartEnergiaEvolucao"></canvas></div>
      </div>
      <div class="card lg:col-span-2">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-table mr-2"></i>Detalhamento por Fonte</h3>
        <div style="overflow-x: auto;"><table id="tabela-energia"></table></div>
      </div>
    </div>
  </div>

  <!-- TAB: RECICLAGEM -->
  <div id="tab-reciclagem" class="tab-content">
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-chart-bar mr-2"></i>Volume por Tipo de Resíduo (kg)</h3>
        <div class="chart-container"><canvas id="chartReciclagemTipo"></canvas></div>
      </div>
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-leaf mr-2"></i>CO₂ Evitado por Tipo (kg)</h3>
        <div class="chart-container"><canvas id="chartCO2Evitado"></canvas></div>
      </div>
      <div class="card lg:col-span-2">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-table mr-2"></i>Detalhamento por Resíduo</h3>
        <div style="overflow-x: auto;"><table id="tabela-reciclagem"></table></div>
      </div>
    </div>
  </div>

  <!-- TAB: VEÍCULOS -->
  <div id="tab-veiculos" class="tab-content">
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-car-side mr-2"></i>Crescimento da Frota (2020-2024)</h3>
        <div class="chart-container"><canvas id="chartVeiculosAnual"></canvas></div>
      </div>
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-charging-station mr-2"></i>Expansão de Eletropostos</h3>
        <div class="chart-container"><canvas id="chartEletropostos"></canvas></div>
      </div>
      <div class="card lg:col-span-2">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-table mr-2"></i>Dados por Região</h3>
        <div style="overflow-x: auto;"><table id="tabela-veiculos"></table></div>
      </div>
    </div>
  </div>

  <!-- TAB: QUALIDADE -->
  <div id="tab-qualidade" class="tab-content">
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-wind mr-2"></i>IQA - Índice de Qualidade do Ar</h3>
        <div class="chart-container"><canvas id="chartIQA"></canvas></div>
      </div>
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-tint mr-2"></i>IQA - Qualidade da Água</h3>
        <div class="chart-container"><canvas id="chartIQAAgua"></canvas></div>
      </div>
    </div>
  </div>

  <!-- TAB: METAS -->
  <div id="tab-metas" class="tab-content">
    <div class="card">
      <h3 class="font-semibold mb-6" style="color: #a5d6a7"><i class="fas fa-bullseye mr-2"></i>KPIs e Metas Estratégicas 2025</h3>
      <div id="metas-container" class="space-y-4"></div>
    </div>
  </div>

  <!-- TAB: POWER BI -->
  <div id="tab-powerbi" class="tab-content">
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-plug mr-2"></i>Integração com Power BI</h3>
        <p class="text-sm mb-4" style="color: #81c784">
          Use os endpoints abaixo diretamente no Power BI via <strong>Web Connector</strong> (Obter Dados → Web).
          Os endpoints com <code>?format=csv</code> retornam CSV para importação direta.
        </p>
        <div class="space-y-3" id="powerbi-endpoints"></div>
      </div>
      <div class="card">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-database mr-2"></i>Modelo Estrela - Tabelas</h3>
        <div class="space-y-3">
          <div>
            <p class="text-xs font-bold mb-2" style="color: #81c784">📊 TABELAS FATO</p>
            <div class="flex flex-wrap gap-1">
              ${['fato_qualidade_ar','fato_qualidade_agua','fato_consumo_energia','fato_reciclagem','fato_veiculos_eletricos','fato_indicadores_climaticos','fato_cobertura_vegetal','fato_educacao_ambiental','fato_denuncias','fato_ecopontos'].map(t => `<span class="api-tag">${t}</span>`).join('')}
            </div>
          </div>
          <div>
            <p class="text-xs font-bold mb-2 mt-3" style="color: #81c784">🗂️ TABELAS DIMENSÃO</p>
            <div class="flex flex-wrap gap-1">
              ${['dim_regioes','dim_categorias','dim_usuarios','dim_tipos_residuos','dim_fontes_energia'].map(t => `<span class="api-tag">${t}</span>`).join('')}
            </div>
          </div>
          <div>
            <p class="text-xs font-bold mb-2 mt-3" style="color: #81c784">⚙️ TABELAS DE SUPORTE</p>
            <div class="flex flex-wrap gap-1">
              ${['tb_kpis_metas','tb_alertas'].map(t => `<span class="api-tag">${t}</span>`).join('')}
            </div>
          </div>
        </div>
      </div>
      <div class="card lg:col-span-2">
        <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-info-circle mr-2"></i>Banco de Dados Gratuito (Cloudflare D1)</h3>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="p-4 rounded-lg" style="background: #0d2d0d; border: 1px solid #2a5c2a">
            <h4 class="font-bold mb-2" style="color: #a5d6a7">☁️ Cloudflare D1 (Gratuito)</h4>
            <ul class="text-sm space-y-1" style="color: #81c784">
              <li>✅ 5 GB de armazenamento grátis</li>
              <li>✅ 5 milhões de leituras/dia</li>
              <li>✅ 100.000 escritas/dia</li>
              <li>✅ SQLite compatível</li>
              <li>✅ API REST automática</li>
              <li>✅ Sem servidor para gerenciar</li>
            </ul>
          </div>
          <div class="p-4 rounded-lg" style="background: #0d2d0d; border: 1px solid #2a5c2a">
            <h4 class="font-bold mb-2" style="color: #a5d6a7">📊 Power BI - Métodos de Conexão</h4>
            <ul class="text-sm space-y-1" style="color: #81c784">
              <li>🔗 Web Connector (JSON/CSV)</li>
              <li>🔗 Power Query (HTTP)</li>
              <li>🔄 Atualização automática</li>
              <li>📋 Modelo de dados estrela</li>
              <li>🗃️ 19 endpoints disponíveis</li>
              <li>📥 Export CSV/JSON direto</li>
            </ul>
          </div>
          <div class="p-4 rounded-lg" style="background: #0d2d0d; border: 1px solid #2a5c2a">
            <h4 class="font-bold mb-2" style="color: #a5d6a7">📈 Relatórios Sugeridos no Power BI</h4>
            <ul class="text-sm space-y-1" style="color: #81c784">
              <li>🌿 Painel de Sustentabilidade</li>
              <li>🌡️ Análise Climática Regional</li>
              <li>♻️ Dashboard de Reciclagem</li>
              <li>⚡ Eficiência Energética</li>
              <li>🚗 Mobilidade Verde</li>
              <li>🏆 Ranking de KPIs por ODS</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </div>

</main>

<!-- FOOTER -->
<footer style="background: #0d1f0d; border-top: 1px solid #2a5c2a; margin-top: 3rem; padding: 1.5rem;">
  <div class="max-w-screen-xl mx-auto px-4 text-center text-sm" style="color: #66bb6a">
    <p>🌱 SustAmbiTech BI &copy; 2025 | Desenvolvido para análise ambiental com Power BI</p>
    <p class="mt-1">Banco de dados: Cloudflare D1 (gratuito) | Framework: Hono + TypeScript | Deploy: Cloudflare Pages</p>
  </div>
</footer>

<script>
const BASE = window.location.origin;

// Tabs
function showTab(name) {
  document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.tab').forEach(el => el.classList.remove('active'));
  document.getElementById('tab-' + name).classList.add('active');
  event.target.classList.add('active');
  // Lazy load charts
  loadTabData(name);
}

// Chart defaults
Chart.defaults.color = '#a5d6a7';
Chart.defaults.borderColor = '#2a5c2a';

const GREEN_PALETTE = ['#4CAF50','#8BC34A','#2196F3','#FF9800','#9C27B0','#00BCD4','#FF5722','#607D8B','#795548','#F44336'];

function makeChart(id, config) {
  const ctx = document.getElementById(id);
  if (!ctx) return;
  const existing = Chart.getChart(ctx);
  if (existing) existing.destroy();
  return new Chart(ctx, config);
}

// ===================== LOAD DATA =====================

async function loadKPIs() {
  try {
    const r = await fetch(BASE + '/api/kpis');
    const d = await r.json();
    const grid = document.getElementById('kpis-grid');
    const kpis = [
      { label: 'Usuários', value: d.usuarios?.total || 0, sub: d.usuarios?.total_pontos?.toLocaleString('pt-BR') + ' pts', icon: 'fa-users', color: '#4CAF50' },
      { label: 'Coletas Reciclagem', value: d.reciclagem?.coletas || 0, sub: (d.reciclagem?.total_kg || 0).toLocaleString('pt-BR') + ' kg', icon: 'fa-recycle', color: '#8BC34A' },
      { label: 'CO₂ Evitado', value: ((d.reciclagem?.co2_evitado || 0)/1000).toFixed(1) + 't', sub: 'em reciclagem', icon: 'fa-leaf', color: '#00BCD4' },
      { label: 'Ativid. Educação', value: d.educacao?.total || 0, sub: d.educacao?.concluidas + ' concluídas', icon: 'fa-graduation-cap', color: '#FF9800' },
      { label: 'Ecopontos', value: d.ecopontos?.ativos || 0, sub: 'ativos', icon: 'fa-map-marker-alt', color: '#9C27B0' },
      { label: 'Denúncias', value: d.denuncias?.total || 0, sub: d.denuncias?.resolvidas + ' resolvidas', icon: 'fa-flag', color: '#FF5722' },
    ];
    grid.innerHTML = kpis.map(k => \`
      <div class="kpi-card text-center">
        <div style="width:40px;height:40px;border-radius:50%;background:\${k.color}22;display:flex;align-items:center;justify-content:center;margin:0 auto 0.5rem">
          <i class="fas \${k.icon}" style="color:\${k.color};font-size:1rem"></i>
        </div>
        <p class="text-2xl font-bold" style="color:\${k.color}">\${k.value}</p>
        <p class="text-xs font-semibold mt-1" style="color:#a5d6a7">\${k.label}</p>
        <p class="text-xs mt-0.5" style="color:#66bb6a">\${k.sub}</p>
      </div>
    \`).join('');
    document.getElementById('last-update').innerHTML = '<i class="fas fa-check-circle mr-1" style="color:#4CAF50"></i>Atualizado agora';
  } catch(e) { console.error('KPIs error:', e); }
}

async function loadAlertas() {
  try {
    const r = await fetch(BASE + '/api/alertas');
    const data = await r.json();
    const container = document.getElementById('alertas-container');
    const alertas = (data || []).slice(0,3);
    container.innerHTML = alertas.map(a => {
      const cls = a.severidade === 'critico' ? 'alert-critico' : a.severidade === 'aviso' ? 'alert-aviso' : 'alert-info';
      const color = a.severidade === 'critico' ? '#f44336' : a.severidade === 'aviso' ? '#ff9800' : '#2196F3';
      const icon = a.severidade === 'critico' ? 'exclamation-triangle' : a.severidade === 'aviso' ? 'exclamation-circle' : 'info-circle';
      return \`<div class="card \${cls} flex items-start gap-3 py-3" style="background:#0d2d0d">
        <i class="fas fa-\${icon} mt-0.5" style="color:\${color}"></i>
        <div class="flex-1">
          <p class="font-semibold text-sm" style="color:\${color}">\${a.titulo}</p>
          <p class="text-xs mt-0.5" style="color:#81c784">\${a.descricao || ''} \${a.regiao_nome ? '| '+a.regiao_nome : ''}</p>
        </div>
        <span class="badge \${a.severidade==='critico'?'badge-red':a.severidade==='aviso'?'badge-yellow':'badge-blue'}">\${a.severidade}</span>
      </div>\`;
    }).join('');
  } catch(e) {}
}

async function loadVisaoGeral() {
  try {
    const [residuos, frota, evolucao, denuncias] = await Promise.all([
      fetch(BASE + '/api/reciclagem/por-tipo').then(r => r.json()),
      fetch(BASE + '/api/veiculos-eletricos').then(r => r.json()),
      fetch(BASE + '/api/veiculos-eletricos/evolucao').then(r => r.json()),
      fetch(BASE + '/api/bi/ranking-denuncias').then(r => r.json()),
    ]);
    // Gráfico reciclagem
    makeChart('chartResiduos', {
      type: 'bar',
      data: {
        labels: residuos.map(r => r.tipo),
        datasets: [{
          label: 'kg',
          data: residuos.map(r => r.total_kg),
          backgroundColor: GREEN_PALETTE,
          borderRadius: 6
        }]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
    });
    // Gráfico frota (último ano disponível - SP)
    const sp2024 = (frota || []).find(f => f.data_referencia === '2024-12-31' && f.estado === 'SP');
    if (sp2024) {
      makeChart('chartFrota', {
        type: 'doughnut',
        data: {
          labels: ['Elétricos', 'Híbridos', 'Combustão'],
          datasets: [{ data: [sp2024.total_veiculos_eletricos, sp2024.total_hibridos, sp2024.total_combustao], backgroundColor: ['#4CAF50','#FF9800','#607D8B'], borderWidth: 0 }]
        },
        options: { responsive: true, maintainAspectRatio: false, cutout: '65%', plugins: { legend: { position: 'bottom' } } }
      });
    }
    // Evolução frota
    makeChart('chartEvolucaoFrota', {
      type: 'line',
      data: {
        labels: evolucao.map(e => e.ano),
        datasets: [
          { label: 'Elétricos', data: evolucao.map(e => e.total_eletricos), borderColor: '#4CAF50', backgroundColor: '#4CAF5033', fill: true, tension: 0.4 },
          { label: 'Eletropostos', data: evolucao.map(e => e.total_eletropostos), borderColor: '#FF9800', backgroundColor: '#FF980033', fill: false, tension: 0.4, yAxisID: 'y1' }
        ]
      },
      options: { responsive: true, maintainAspectRatio: false, scales: { y1: { type: 'linear', position: 'right', grid: { drawOnChartArea: false } } } }
    });
    // Denúncias
    makeChart('chartDenuncias', {
      type: 'bar',
      data: {
        labels: denuncias.map(d => d.estado || d.regiao),
        datasets: [
          { label: 'Total', data: denuncias.map(d => d.total_denuncias), backgroundColor: '#FF5722aa' },
          { label: 'Resolvidas', data: denuncias.map(d => d.resolvidas), backgroundColor: '#4CAF50aa' }
        ]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }
    });
  } catch(e) { console.error('Visão geral:', e); }
}

async function loadEnergia() {
  try {
    const [porFonte, evolucao] = await Promise.all([
      fetch(BASE + '/api/energia/por-fonte').then(r => r.json()),
      fetch(BASE + '/api/energia/evolucao').then(r => r.json()),
    ]);
    makeChart('chartEnergiaPorFonte', {
      type: 'bar',
      data: {
        labels: porFonte.map(f => f.fonte || 'N/D'),
        datasets: [
          { label: 'kWh', data: porFonte.map(f => f.total_kwh), backgroundColor: porFonte.map(f => f.renovavel ? '#4CAF50' : '#607D8B'), borderRadius: 6 }
        ]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
    });
    makeChart('chartEnergiaEvolucao', {
      type: 'line',
      data: {
        labels: evolucao.map(e => e.mes),
        datasets: [
          { label: 'Consumo (kWh)', data: evolucao.map(e => e.total_kwh), borderColor: '#FF9800', fill: true, backgroundColor: '#FF980022', tension: 0.4 },
          { label: 'CO₂ (kg)', data: evolucao.map(e => e.total_co2_kg), borderColor: '#f44336', fill: false, tension: 0.4, yAxisID: 'y1' }
        ]
      },
      options: { responsive: true, maintainAspectRatio: false, scales: { y1: { type: 'linear', position: 'right', grid: { drawOnChartArea: false } } } }
    });
    const t = document.getElementById('tabela-energia');
    t.innerHTML = \`<thead><tr><th>Fonte</th><th>Tipo</th><th>Renovável</th><th>Total kWh</th><th>CO₂ (kg)</th><th>Custo R$</th></tr></thead><tbody>\${
      porFonte.map(f => \`<tr><td>\${f.fonte||'N/D'}</td><td>\${f.tipo||'N/D'}</td><td>\${f.renovavel?'✅':'❌'}</td><td>\${(f.total_kwh||0).toLocaleString('pt-BR')}</td><td>\${(f.total_co2_kg||0).toLocaleString('pt-BR')}</td><td>R$ \${(f.total_custo||0).toLocaleString('pt-BR')}</td></tr>\`).join('')
    }</tbody>\`;
  } catch(e) { console.error('Energia:', e); }
}

async function loadReciclagem() {
  try {
    const data = await fetch(BASE + '/api/reciclagem/por-tipo').then(r => r.json());
    makeChart('chartReciclagemTipo', {
      type: 'bar', data: { labels: data.map(d => d.tipo), datasets: [{ label: 'kg', data: data.map(d => d.total_kg), backgroundColor: GREEN_PALETTE, borderRadius: 6 }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
    });
    makeChart('chartCO2Evitado', {
      type: 'bar', data: { labels: data.map(d => d.tipo), datasets: [{ label: 'CO₂ evitado (kg)', data: data.map(d => d.co2_evitado), backgroundColor: '#4CAF5088', borderRadius: 6 }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
    });
    const t = document.getElementById('tabela-reciclagem');
    t.innerHTML = \`<thead><tr><th>Tipo</th><th>Classificação</th><th>Total (kg)</th><th>CO₂ Evitado (kg)</th><th>Valor (R$)</th><th>Coletas</th></tr></thead><tbody>\${
      data.map(d => \`<tr><td>\${d.tipo||'N/D'}</td><td><span class="badge badge-green">\${d.classificacao||'N/D'}</span></td><td>\${(d.total_kg||0).toLocaleString('pt-BR')}</td><td>\${(d.co2_evitado||0).toLocaleString('pt-BR')}</td><td>R$ \${(d.valor_total||0).toLocaleString('pt-BR')}</td><td>\${d.coletas}</td></tr>\`).join('')
    }</tbody>\`;
  } catch(e) { console.error('Reciclagem:', e); }
}

async function loadVeiculos() {
  try {
    const [evolucao, todos] = await Promise.all([
      fetch(BASE + '/api/veiculos-eletricos/evolucao').then(r => r.json()),
      fetch(BASE + '/api/veiculos-eletricos').then(r => r.json()),
    ]);
    makeChart('chartVeiculosAnual', {
      type: 'bar', data: {
        labels: evolucao.map(e => e.ano),
        datasets: [
          { label: 'Elétricos', data: evolucao.map(e => e.total_eletricos), backgroundColor: '#4CAF50', borderRadius: 4 },
          { label: 'Novos Emplacamentos', data: evolucao.map(e => e.novos_emplacamentos), backgroundColor: '#8BC34A', borderRadius: 4 }
        ]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }
    });
    makeChart('chartEletropostos', {
      type: 'line', data: {
        labels: evolucao.map(e => e.ano),
        datasets: [{ label: 'Eletropostos Ativos', data: evolucao.map(e => e.total_eletropostos), borderColor: '#FF9800', backgroundColor: '#FF980033', fill: true, tension: 0.4 }]
      },
      options: { responsive: true, maintainAspectRatio: false }
    });
    const recentes = (todos || []).filter(v => v.data_referencia === '2024-12-31');
    const t = document.getElementById('tabela-veiculos');
    t.innerHTML = \`<thead><tr><th>Região</th><th>Estado</th><th>Elétricos</th><th>Híbridos</th><th>Eletropostos</th><th>CO₂ Evitado (t)</th><th>Modelo +Vendido</th></tr></thead><tbody>\${
      recentes.map(v => \`<tr><td>\${v.regiao_nome||'N/D'}</td><td>\${v.estado||'N/D'}</td><td>\${(v.total_veiculos_eletricos||0).toLocaleString('pt-BR')}</td><td>\${(v.total_hibridos||0).toLocaleString('pt-BR')}</td><td>\${(v.eletropostos_ativos||0).toLocaleString('pt-BR')}</td><td>\${((v.co2_evitado_kg||0)/1000).toLocaleString('pt-BR')}</td><td>\${v.modelo_mais_vendido||'N/D'}</td></tr>\`).join('')
    }</tbody>\`;
  } catch(e) { console.error('Veículos:', e); }
}

async function loadQualidade() {
  try {
    const [ar, agua] = await Promise.all([
      fetch(BASE + '/api/qualidade-ar').then(r => r.json()),
      fetch(BASE + '/api/qualidade-agua').then(r => r.json()),
    ]);
    const arByRegiao = {};
    ar.forEach(a => { if (!arByRegiao[a.regiao_nome]) arByRegiao[a.regiao_nome] = []; arByRegiao[a.regiao_nome].push(a.indice_qualidade_ar); });
    const arLabels = Object.keys(arByRegiao);
    const arValues = arLabels.map(r => { const vals = arByRegiao[r]; return Math.round(vals.reduce((a,b)=>a+b,0)/vals.length); });
    makeChart('chartIQA', {
      type: 'bar', data: { labels: arLabels, datasets: [{ label: 'IQA Médio', data: arValues, backgroundColor: arValues.map(v => v < 50 ? '#4CAF50' : v < 100 ? '#FF9800' : '#f44336'), borderRadius: 6 }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
    });
    const aguaByRegiao = {};
    agua.forEach(a => { if (!aguaByRegiao[a.regiao_nome]) aguaByRegiao[a.regiao_nome] = []; aguaByRegiao[a.regiao_nome].push(a.indice_qualidade_agua); });
    const aguaLabels = Object.keys(aguaByRegiao);
    const aguaValues = aguaLabels.map(r => { const vals = aguaByRegiao[r]; return Math.round(vals.reduce((a,b)=>a+b,0)/vals.length); });
    makeChart('chartIQAAgua', {
      type: 'bar', data: { labels: aguaLabels, datasets: [{ label: 'IQA Água', data: aguaValues, backgroundColor: aguaValues.map(v => v >= 80 ? '#4CAF50' : v >= 50 ? '#FF9800' : '#f44336'), borderRadius: 6 }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
    });
  } catch(e) { console.error('Qualidade:', e); }
}

async function loadMetas() {
  try {
    const data = await fetch(BASE + '/api/metas').then(r => r.json());
    const container = document.getElementById('metas-container');
    container.innerHTML = (data || []).map(m => {
      const pct = Math.min(100, m.percentual_atingimento || 0);
      const cor = pct >= 80 ? '#4CAF50' : pct >= 50 ? '#FF9800' : '#f44336';
      const badge = m.status_meta === 'atingida' ? 'badge-green' : m.status_meta === 'em_andamento' ? 'badge-blue' : 'badge-red';
      return \`<div style="border:1px solid #2a5c2a;border-radius:8px;padding:1rem;background:#0d2d0d">
        <div class="flex items-center justify-between mb-2">
          <div>
            <p class="font-semibold text-sm" style="color:#a5d6a7">\${m.nome_kpi}</p>
            <p class="text-xs mt-0.5" style="color:#66bb6a">\${m.descricao || ''} | ODS: \${m.ods_relacionado || 'N/D'}</p>
          </div>
          <div class="text-right">
            <p class="font-bold text-lg" style="color:\${cor}">\${pct.toFixed(1)}%</p>
            <span class="badge \${badge}">\${m.status_meta}</span>
          </div>
        </div>
        <div class="progress-bar"><div class="progress-fill" style="width:\${pct}%;background:linear-gradient(90deg,\${cor}88,\${cor})"></div></div>
        <div class="flex justify-between text-xs mt-1" style="color:#66bb6a">
          <span>Atual: \${(m.valor_atual||0).toLocaleString('pt-BR')} \${m.unidade_medida}</span>
          <span>Meta: \${(m.valor_meta||0).toLocaleString('pt-BR')} \${m.unidade_medida}</span>
        </div>
      </div>\`;
    }).join('');
  } catch(e) { console.error('Metas:', e); }
}

async function loadPowerBI() {
  const endpoints = [
    { label: 'KPIs Gerais', url: '/api/kpis', desc: 'JSON - indicadores sumarizados' },
    { label: 'Qualidade do Ar (CSV)', url: '/api/qualidade-ar?format=csv', desc: 'CSV - dados PM2.5, PM10, CO2, IQA' },
    { label: 'Qualidade da Água (CSV)', url: '/api/qualidade-agua?format=csv', desc: 'CSV - pH, turbidez, oxigênio, IQA' },
    { label: 'Energia por Fonte', url: '/api/energia/por-fonte', desc: 'JSON - consumo e emissões agrupados' },
    { label: 'Energia - Evolução (CSV)', url: '/api/energia?format=csv', desc: 'CSV - série temporal de consumo' },
    { label: 'Reciclagem por Tipo', url: '/api/reciclagem/por-tipo', desc: 'JSON - volume e CO2 evitado' },
    { label: 'Reciclagem (CSV)', url: '/api/reciclagem?format=csv', desc: 'CSV - todas as coletas detalhadas' },
    { label: 'Frota Elétrica - Evolução', url: '/api/veiculos-eletricos/evolucao', desc: 'JSON - crescimento anual da frota' },
    { label: 'Veículos Elétricos (CSV)', url: '/api/veiculos-eletricos?format=csv', desc: 'CSV - dados por região e ano' },
    { label: 'Clima (CSV)', url: '/api/clima?format=csv', desc: 'CSV - temperatura, chuvas, anomalias' },
    { label: 'Cobertura Vegetal (CSV)', url: '/api/cobertura-vegetal?format=csv', desc: 'CSV - desmatamento e reflorestamento' },
    { label: 'Denúncias (CSV)', url: '/api/denuncias?format=csv', desc: 'CSV - tipos, status e impacto' },
    { label: 'Ecopontos (CSV)', url: '/api/ecopontos?format=csv', desc: 'CSV - localização e capacidade' },
    { label: 'KPIs e Metas (CSV)', url: '/api/metas?format=csv', desc: 'CSV - percentual de atingimento' },
    { label: 'Resumo Regional', url: '/api/bi/resumo-regional?format=csv', desc: 'CSV - visão consolidada por cidade' },
    { label: 'Tendências Reciclagem', url: '/api/bi/tendencias', desc: 'JSON - série mensal de reciclagem' },
    { label: 'Emissões CO₂', url: '/api/bi/emissoes-co2', desc: 'JSON - CO2 por fonte e região' },
    { label: 'Ranking Denúncias', url: '/api/bi/ranking-denuncias', desc: 'JSON - taxa de resolução por região' },
    { label: 'Educação Ambiental (CSV)', url: '/api/educacao?format=csv', desc: 'CSV - atividades e pontuações' },
  ];
  document.getElementById('powerbi-endpoints').innerHTML = endpoints.map(e => \`
    <div style="border:1px solid #2a5c2a;border-radius:8px;padding:0.75rem;background:#0d2d0d;display:flex;align-items:center;justify-content:space-between;gap:0.5rem">
      <div>
        <p class="text-sm font-semibold" style="color:#a5d6a7">\${e.label}</p>
        <p class="text-xs mt-0.5" style="color:#66bb6a">\${e.desc}</p>
        <span class="api-tag mt-1">\${BASE}\${e.url}</span>
      </div>
      <div class="flex gap-2 shrink-0">
        <a href="\${e.url}" target="_blank" class="text-xs px-3 py-1 rounded font-semibold" style="background:#1b5e20;color:#a5d6a7;text-decoration:none">Ver</a>
        <button onclick="navigator.clipboard.writeText('\${BASE}\${e.url}')" class="text-xs px-3 py-1 rounded font-semibold" style="background:#0d47a1;color:#bbdefb"><i class="fas fa-copy"></i></button>
      </div>
    </div>
  \`).join('');
}

let tabLoaded = { 'visao-geral': false, energia: false, reciclagem: false, veiculos: false, qualidade: false, metas: false, powerbi: false };

async function loadTabData(name) {
  if (tabLoaded[name]) return;
  tabLoaded[name] = true;
  if (name === 'visao-geral') await loadVisaoGeral();
  else if (name === 'energia') await loadEnergia();
  else if (name === 'reciclagem') await loadReciclagem();
  else if (name === 'veiculos') await loadVeiculos();
  else if (name === 'qualidade') await loadQualidade();
  else if (name === 'metas') await loadMetas();
  else if (name === 'powerbi') await loadPowerBI();
}

// Init
document.addEventListener('DOMContentLoaded', () => {
  loadKPIs();
  loadAlertas();
  loadVisaoGeral();
});
</script>
</body>
</html>`
}

// ============================================================
// HTML: MAPA MENTAL
// ============================================================
function htmlMindMap(): string {
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SustAmbiTech - Mapa Mental & Análise</title>
<script src="https://cdn.tailwindcss.com"></script>
<link href="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.4.0/css/all.min.css" rel="stylesheet">
<style>
  :root { --bg: #0f2010; --card: #162516; --border: #2a5c2a; --text: #e8f5e9; --green: #4CAF50; --pale: #8BC34A; --muted: #a5d6a7; }
  body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', sans-serif; margin: 0; }
  .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 1.5rem; }
  svg text { font-family: 'Segoe UI', sans-serif; }
  .mindmap-node { cursor: pointer; transition: all 0.2s; }
  .mindmap-node:hover circle { filter: brightness(1.3); }
  .node-center circle { fill: #2d6a2d; stroke: #4CAF50; stroke-width: 3; }
  .tip-card { background: #0d2d0d; border: 1px solid #2a5c2a; border-radius: 8px; padding: 1rem; margin-top: 0.5rem; }
</style>
</head>
<body>

<nav style="background: #0d1f0d; border-bottom: 1px solid #2a5c2a;" class="sticky top-0 z-50">
  <div class="max-w-screen-xl mx-auto px-4 py-3 flex items-center justify-between">
    <div class="flex items-center gap-3">
      <div class="w-9 h-9 rounded-lg flex items-center justify-center" style="background: linear-gradient(135deg, #4CAF50, #2d6a2d)">
        <i class="fas fa-leaf text-white text-sm"></i>
      </div>
      <div>
        <h1 class="font-bold text-base" style="color: #8BC34A">SustAmbiTech BI</h1>
        <p class="text-xs" style="color: #66bb6a">Mapa Mental & Sugestões de Melhoria</p>
      </div>
    </div>
    <div class="flex items-center gap-2">
      <a href="/" style="color:#a5d6a7;padding:0.5rem 1rem;background:#1a3d1a;border-radius:8px;text-decoration:none;font-size:0.875rem"><i class="fas fa-arrow-left mr-1"></i>Dashboard</a>
    </div>
  </div>
</nav>

<main class="max-w-screen-xl mx-auto px-4 py-6">

  <div class="text-center mb-8">
    <h2 class="text-3xl font-bold mb-2" style="color: #a5d6a7">Mapa Mental - SustAmbiTech</h2>
    <p style="color: #66bb6a">Análise completa do projeto com módulos, dados para BI e sugestões de melhoria</p>
  </div>

  <!-- MAPA MENTAL SVG -->
  <div class="card mb-8 overflow-x-auto">
    <h3 class="font-semibold mb-4" style="color: #a5d6a7"><i class="fas fa-project-diagram mr-2"></i>Mapa Mental Interativo</h3>
    <svg id="mindmap" viewBox="0 0 1200 800" width="100%" style="min-width:800px; min-height:500px">
      <!-- Linhas de conexão -->
      <!-- Centro para nós principais -->
      <g id="lines" stroke="#2a5c2a" stroke-width="2" fill="none">
        <line x1="600" y1="400" x2="200" y2="150"/>
        <line x1="600" y1="400" x2="500" y2="100"/>
        <line x1="600" y1="400" x2="800" y2="100"/>
        <line x1="600" y1="400" x2="1000" y2="150"/>
        <line x1="600" y1="400" x2="1050" y2="400"/>
        <line x1="600" y1="400" x2="1000" y2="650"/>
        <line x1="600" y1="400" x2="800" y2="700"/>
        <line x1="600" y1="400" x2="500" y2="700"/>
        <line x1="600" y1="400" x2="200" y2="650"/>
        <line x1="600" y1="400" x2="150" y2="400"/>
        <!-- Sub-nós -->
        <line x1="200" y1="150" x2="100" y2="80" stroke="#1a5c1a" stroke-width="1.5"/>
        <line x1="200" y1="150" x2="180" y2="50" stroke="#1a5c1a" stroke-width="1.5"/>
        <line x1="500" y1="100" x2="430" y2="35" stroke="#1a5c1a" stroke-width="1.5"/>
        <line x1="500" y1="100" x2="540" y2="30" stroke="#1a5c1a" stroke-width="1.5"/>
        <line x1="800" y1="100" x2="720" y2="40" stroke="#1a5c1a" stroke-width="1.5"/>
        <line x1="800" y1="100" x2="870" y2="35" stroke="#1a5c1a" stroke-width="1.5"/>
        <line x1="1050" y1="400" x2="1130" y2="330" stroke="#1a5c1a" stroke-width="1.5"/>
        <line x1="1050" y1="400" x2="1140" y2="460" stroke="#1a5c1a" stroke-width="1.5"/>
      </g>

      <!-- NÓ CENTRAL -->
      <g class="mindmap-node node-center" transform="translate(600,400)">
        <circle r="65" fill="#1a5c1a" stroke="#4CAF50" stroke-width="3"/>
        <text text-anchor="middle" dy="-8" fill="#8BC34A" font-size="13" font-weight="bold">🌱</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="11" font-weight="bold">SUSTAMBITECH</text>
        <text text-anchor="middle" dy="22" fill="#66bb6a" font-size="9">BI & ANÁLISE</text>
      </g>

      <!-- NÓ 1: MONITORAMENTO AMBIENTAL -->
      <g class="mindmap-node" transform="translate(200,150)" onclick="showInfo('monitoramento')">
        <circle r="48" fill="#0d3d0d" stroke="#4CAF50" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#4CAF50" font-size="16">🌬️</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Monitoramento</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Ambiental</text>
      </g>
      <!-- Sub-nós monitoramento -->
      <g transform="translate(100,80)"><circle r="25" fill="#0a2d0a" stroke="#2a5c2a" stroke-width="1.5"/><text text-anchor="middle" dy="-3" fill="#81c784" font-size="9">Qualidade</text><text text-anchor="middle" dy="8" fill="#66bb6a" font-size="8">do Ar</text></g>
      <g transform="translate(180,50)"><circle r="25" fill="#0a2d0a" stroke="#2a5c2a" stroke-width="1.5"/><text text-anchor="middle" dy="-3" fill="#81c784" font-size="9">Qualidade</text><text text-anchor="middle" dy="8" fill="#66bb6a" font-size="8">da Água</text></g>

      <!-- NÓ 2: ENERGIA -->
      <g class="mindmap-node" transform="translate(500,100)" onclick="showInfo('energia')">
        <circle r="48" fill="#1a3d00" stroke="#8BC34A" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#8BC34A" font-size="16">⚡</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Energia</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Renovável</text>
      </g>
      <g transform="translate(430,35)"><circle r="25" fill="#0a2d0a" stroke="#2a5c2a" stroke-width="1.5"/><text text-anchor="middle" dy="-3" fill="#81c784" font-size="9">Solar /</text><text text-anchor="middle" dy="8" fill="#66bb6a" font-size="8">Eólica</text></g>
      <g transform="translate(540,30)"><circle r="25" fill="#0a2d0a" stroke="#2a5c2a" stroke-width="1.5"/><text text-anchor="middle" dy="-3" fill="#81c784" font-size="9">Consumo</text><text text-anchor="middle" dy="8" fill="#66bb6a" font-size="8">Eficiente</text></g>

      <!-- NÓ 3: RECICLAGEM -->
      <g class="mindmap-node" transform="translate(800,100)" onclick="showInfo('reciclagem')">
        <circle r="48" fill="#0d3d1a" stroke="#00BCD4" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#00BCD4" font-size="16">♻️</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Reciclagem</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Inteligente</text>
      </g>
      <g transform="translate(720,40)"><circle r="25" fill="#0a2d0a" stroke="#2a5c2a" stroke-width="1.5"/><text text-anchor="middle" dy="-3" fill="#81c784" font-size="9">Resíduos</text><text text-anchor="middle" dy="8" fill="#66bb6a" font-size="8">Sólidos</text></g>
      <g transform="translate(870,35)"><circle r="25" fill="#0a2d0a" stroke="#2a5c2a" stroke-width="1.5"/><text text-anchor="middle" dy="-3" fill="#81c784" font-size="9">Ecopontos</text><text text-anchor="middle" dy="8" fill="#66bb6a" font-size="8">Mapa</text></g>

      <!-- NÓ 4: MOBILIDADE -->
      <g class="mindmap-node" transform="translate(1000,150)" onclick="showInfo('mobilidade')">
        <circle r="48" fill="#0d2d3d" stroke="#FF9800" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#FF9800" font-size="16">🚗</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Mobilidade</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Sustentável</text>
      </g>

      <!-- NÓ 5: BI / DADOS -->
      <g class="mindmap-node" transform="translate(1050,400)" onclick="showInfo('bi')">
        <circle r="48" fill="#3d0d3d" stroke="#9C27B0" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#9C27B0" font-size="16">📊</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Power BI</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Dados & APIs</text>
      </g>
      <g transform="translate(1130,330)"><circle r="25" fill="#0a2d0a" stroke="#2a5c2a" stroke-width="1.5"/><text text-anchor="middle" dy="-3" fill="#81c784" font-size="9">REST</text><text text-anchor="middle" dy="8" fill="#66bb6a" font-size="8">APIs</text></g>
      <g transform="translate(1140,460)"><circle r="25" fill="#0a2d0a" stroke="#2a5c2a" stroke-width="1.5"/><text text-anchor="middle" dy="-3" fill="#81c784" font-size="9">CSV</text><text text-anchor="middle" dy="8" fill="#66bb6a" font-size="8">Export</text></g>

      <!-- NÓ 6: DENÚNCIAS -->
      <g class="mindmap-node" transform="translate(1000,650)" onclick="showInfo('denuncias')">
        <circle r="48" fill="#3d0d0d" stroke="#F44336" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#F44336" font-size="16">🚨</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Denúncias</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Ambientais</text>
      </g>

      <!-- NÓ 7: CLIMA -->
      <g class="mindmap-node" transform="translate(800,700)" onclick="showInfo('clima')">
        <circle r="48" fill="#1a1a3d" stroke="#2196F3" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#2196F3" font-size="16">🌡️</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Clima</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Indicadores</text>
      </g>

      <!-- NÓ 8: BIODIVERSIDADE -->
      <g class="mindmap-node" transform="translate(500,700)" onclick="showInfo('biodiversidade')">
        <circle r="48" fill="#0d3d1a" stroke="#388E3C" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#388E3C" font-size="16">🌿</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Biodiversidade</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Cobertura Veg.</text>
      </g>

      <!-- NÓ 9: POLÍTICAS -->
      <g class="mindmap-node" transform="translate(200,650)" onclick="showInfo('politicas')">
        <circle r="48" fill="#2d2d0d" stroke="#FF5722" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#FF5722" font-size="16">⚖️</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Políticas</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Legislação</text>
      </g>

      <!-- NÓ 10: EDUCAÇÃO -->
      <g class="mindmap-node" transform="translate(150,400)" onclick="showInfo('educacao')">
        <circle r="48" fill="#3d2d0d" stroke="#607D8B" stroke-width="2"/>
        <text text-anchor="middle" dy="-6" fill="#607D8B" font-size="16">📚</text>
        <text text-anchor="middle" dy="8" fill="#a5d6a7" font-size="10" font-weight="bold">Educação</text>
        <text text-anchor="middle" dy="20" fill="#66bb6a" font-size="9">Ambiental</text>
      </g>
    </svg>
    <p class="text-xs text-center mt-2" style="color:#66bb6a">Clique nos nós para ver detalhes de cada módulo</p>
  </div>

  <!-- INFO BOX -->
  <div id="info-box" class="card mb-8" style="display:none">
    <div id="info-content"></div>
  </div>

  <!-- SUGESTÕES DE MELHORIA -->
  <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
    
    <div class="card">
      <h3 class="font-bold text-lg mb-4" style="color: #8BC34A"><i class="fas fa-lightbulb mr-2"></i>Sugestões de Melhoria</h3>
      <div class="space-y-3">
        ${[
          { icon: '🤖', title: 'IA para Detecção de Desmatamento', desc: 'Integrar modelo de ML com imagens de satélite (Sentinel/Landsat) para detecção automática de desmatamento em tempo real via API Planet Labs ou MapBiomas.' },
          { icon: '📱', title: 'App Móvel com Gamificação', desc: 'Desenvolver PWA com sistema de conquistas, ranking de usuários sustentáveis e notificações push para alertas ambientais próximos.' },
          { icon: '🔗', title: 'Blockchain para Rastreabilidade', desc: 'Usar blockchain para certificar créditos de carbono e rastrear cadeia de reciclagem, dando transparência ao destino dos resíduos.' },
          { icon: '🌐', title: 'Open Data API Pública', desc: 'Publicar todos os dados como Open Data governamental, permitindo integração com prefeituras, universidades e ONGs.' },
          { icon: '🔮', title: 'Dashboard Preditivo', desc: 'Usar modelos de séries temporais (Prophet/ARIMA) para prever qualidade do ar, temperaturas extremas e tendências de desmatamento.' },
          { icon: '💰', title: 'Marketplace de Créditos Verdes', desc: 'Criar marketplace onde empresas possam comprar/vender créditos de carbono gerados por ações de usuários e cooperativas.' },
        ].map(s => `<div class="tip-card flex gap-3">
          <span class="text-2xl">${s.icon}</span>
          <div><p class="font-semibold text-sm" style="color:#a5d6a7">${s.title}</p><p class="text-xs mt-1" style="color:#66bb6a">${s.desc}</p></div>
        </div>`).join('')}
      </div>
    </div>

    <div class="card">
      <h3 class="font-bold text-lg mb-4" style="color: #8BC34A"><i class="fas fa-database mr-2"></i>Dados Extras para Power BI</h3>
      <div class="space-y-3">
        ${[
          { icon: '🛰️', title: 'Dados de Satélite (INPE/NASA)', desc: 'PRODES/DETER (desmatamento), MODIS (temperatura superfície), Sentinel (cobertura vegetal NDVI).' },
          { icon: '🌊', title: 'Hidrologia e Recursos Hídricos', desc: 'Nível de reservatórios (ANA), vazão de rios, qualidade de corpos hídricos por microbacia.' },
          { icon: '🏭', title: 'Inventário de Emissões GEE', desc: 'Emissões por setor (energia, agro, indústria, resíduos) em toneladas de CO2e para análise de descarbonização.' },
          { icon: '📍', title: 'Dados Socioeconômicos', desc: 'IDH municipal, renda per capita, grau de instrução para correlacionar com indicadores ambientais.' },
          { icon: '🌱', title: 'Mercado de Carbono Voluntário', desc: 'Preços históricos de créditos de carbono (VCMI, Gold Standard), projetos registrados e verificados.' },
          { icon: '🦁', title: 'Lista de Espécies Ameaçadas', desc: 'IUCN Red List, IBAMA listas, dados de avistamentos e status de conservação para análise de biodiversidade.' },
        ].map(s => `<div class="tip-card flex gap-3">
          <span class="text-2xl">${s.icon}</span>
          <div><p class="font-semibold text-sm" style="color:#a5d6a7">${s.title}</p><p class="text-xs mt-1" style="color:#66bb6a">${s.desc}</p></div>
        </div>`).join('')}
      </div>
    </div>
  </div>

  <!-- TABELA DE FONTES DE DADOS PARA BI -->
  <div class="card mb-8">
    <h3 class="font-bold text-lg mb-4" style="color: #8BC34A"><i class="fas fa-link mr-2"></i>Fontes de Dados Reais para Enriquecer o BI</h3>
    <div style="overflow-x:auto">
      <table style="width:100%;border-collapse:collapse;font-size:0.875rem">
        <thead>
          <tr>
            ${['Fonte','Dados Disponíveis','Frequência','Formato','Link','Gratuito'].map(h => `<th style="background:#0d2d0d;color:#8BC34A;padding:0.75rem;text-align:left;font-size:0.8rem;text-transform:uppercase">${h}</th>`).join('')}
          </tr>
        </thead>
        <tbody>
          ${[
            ['INPE - PRODES', 'Desmatamento anual Amazônia', 'Anual', 'CSV/SHP', 'terrabrasilis.dpi.inpe.br', '✅'],
            ['INPE - DETER', 'Alertas de desmatamento', 'Diário', 'API/CSV', 'terrabrasilis.dpi.inpe.br', '✅'],
            ['IBGE', 'Dados socioeconômicos municipais', 'Anual', 'API/CSV', 'ibge.gov.br/api', '✅'],
            ['ANA - HidroWeb', 'Hidrologia e qualidade da água', 'Diário', 'API/CSV', 'snirh.gov.br', '✅'],
            ['ANEEL', 'Geração de energia por fonte', 'Mensal', 'CSV', 'aneel.gov.br', '✅'],
            ['CETESB / SEMAs', 'Qualidade do ar por estado', 'Horário', 'API', 'cetesb.sp.gov.br', '✅'],
            ['DENATRAN/SENATRAN', 'Frota de veículos por município', 'Mensal', 'CSV', 'gov.br/infraestrutura', '✅'],
            ['Observatório do Clima', 'Emissões de GEE no Brasil', 'Anual', 'CSV', 'observatoriodoclima.eco.br', '✅'],
            ['MapBiomas', 'Cobertura e uso da terra', 'Anual', 'API/GEE', 'mapbiomas.org', '✅'],
            ['IUCN Red List', 'Status de espécies ameaçadas', 'Semestral', 'API', 'iucnredlist.org', '✅ (API)'],
          ].map(r => `<tr>${r.map((c,i) => `<td style="padding:0.6rem 0.75rem;border-bottom:1px solid #2a5c2a;color:${i===5?'#4CAF50':'#e8f5e9'}">${i===4?`<a href="https://${c}" target="_blank" style="color:#64b5f6;text-decoration:none">${c}</a>`:c}</td>`).join('')}</tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- MODELO ESTRELA VISUAL -->
  <div class="card">
    <h3 class="font-bold text-lg mb-4" style="color: #8BC34A"><i class="fas fa-star mr-2"></i>Modelo Estrela para Power BI</h3>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div style="background:#0d2d0d;border:1px solid #1b5e20;border-radius:8px;padding:1rem">
        <p class="font-bold text-sm mb-3" style="color:#4CAF50">🗂️ DIMENSÕES (5 tabelas)</p>
        ${['dim_regioes - Localidades geográficas','dim_categorias - Áreas temáticas','dim_usuarios - Perfis de usuários','dim_tipos_residuos - Classificação','dim_fontes_energia - Tipos de energia'].map(t => `<p class="text-xs mb-1" style="color:#81c784">▸ ${t}</p>`).join('')}
      </div>
      <div style="background:#0d2d0d;border:2px solid #4CAF50;border-radius:8px;padding:1rem">
        <p class="font-bold text-sm mb-3" style="color:#8BC34A">📊 TABELAS FATO (12 tabelas)</p>
        ${['fato_qualidade_ar','fato_qualidade_agua','fato_consumo_energia','fato_reciclagem','fato_veiculos_eletricos','fato_indicadores_climaticos','fato_cobertura_vegetal','fato_educacao_ambiental','fato_denuncias','fato_consumo_consciente','fato_politicas_ambientais','fato_ecopontos'].map(t => `<p class="text-xs mb-1" style="color:#66bb6a">▸ ${t}</p>`).join('')}
      </div>
      <div style="background:#0d2d0d;border:1px solid #1b5e20;border-radius:8px;padding:1rem">
        <p class="font-bold text-sm mb-3" style="color:#4CAF50">⚙️ SUPORTE (3 tabelas)</p>
        ${['tb_kpis_metas - Metas e ODS','tb_alertas - Notificações','tb_logs_atividade - Auditoria'].map(t => `<p class="text-xs mb-1" style="color:#81c784">▸ ${t}</p>`).join('')}
        <hr style="border-color:#2a5c2a;margin:1rem 0">
        <p class="font-bold text-sm mb-2" style="color:#4CAF50">🔗 CHAVES DE LIGAÇÃO</p>
        ${['regiao_id → dim_regioes','usuario_id → dim_usuarios','fonte_energia_id → dim_fontes_energia','tipo_residuo_id → dim_tipos_residuos','categoria_id → dim_categorias'].map(t => `<p class="text-xs mb-1" style="color:#66bb6a">▸ ${t}</p>`).join('')}
      </div>
    </div>
  </div>

</main>

<script>
const infoData = {
  monitoramento: {
    title: '🌬️ Monitoramento Ambiental',
    color: '#4CAF50',
    desc: 'Módulo core de coleta de dados ambientais em tempo real. Utiliza sensores virtuais e APIs de serviços meteorológicos.',
    dados_bi: ['PM2.5, PM10, CO2, O3, NO2, SO2', 'Índice de Qualidade do Ar (IQA 0-500)', 'pH, turbidez, oxigênio dissolvido', 'Índice de Qualidade da Água (IQA 0-100)', 'Temperaturas, umidade, vento'],
    tabelas: ['fato_qualidade_ar', 'fato_qualidade_agua'],
    metricas: ['Média diária/mensal de IQA por cidade', 'Mapa de calor de poluição', 'Correlação clima/qualidade do ar', 'Alertas por threshold']
  },
  energia: {
    title: '⚡ Energia Renovável',
    color: '#8BC34A',
    desc: 'Controle inteligente do consumo de energia por fonte, setor e região. Mede o percentual de energia limpa e o CO2 evitado.',
    dados_bi: ['kWh consumido por fonte', 'Custo em reais', 'Emissão de CO2 por kWh', 'Setor (residencial, industrial)', 'Percentual de energia renovável'],
    tabelas: ['fato_consumo_energia', 'dim_fontes_energia'],
    metricas: ['% de energia renovável por região', 'Evolução mensal do consumo', 'CO2 evitado por adoção de solar/eólica', 'Custo médio por kWh por fonte']
  },
  reciclagem: {
    title: '♻️ Reciclagem Inteligente',
    color: '#00BCD4',
    desc: 'Sistema de gestão de resíduos com rastreamento de ecopontos, tipos de resíduos coletados e impacto ambiental.',
    dados_bi: ['Quantidade em kg por tipo de resíduo', 'CO2 evitado por reciclagem', 'Valor arrecadado por cooperativas', 'Mapa de ecopontos', 'Taxa de desvio de aterro'],
    tabelas: ['fato_reciclagem', 'fato_ecopontos', 'dim_tipos_residuos'],
    metricas: ['Taxa de reciclagem municipal (%)', 'Ranking de tipos de resíduo', 'CO2 evitado acumulado', 'Receita gerada por cooperativas']
  },
  mobilidade: {
    title: '🚗 Mobilidade Sustentável',
    color: '#FF9800',
    desc: 'Acompanhamento da eletrificação da frota, expansão de eletropostos e impacto ambiental da mobilidade elétrica.',
    dados_bi: ['Total de veículos elétricos/híbridos', 'Novos emplacamentos mensais', 'Eletropostos ativos', 'CO2 evitado em km rodados', 'Economia de combustível em litros'],
    tabelas: ['fato_veiculos_eletricos'],
    metricas: ['% de frota elétrica por cidade', 'Crescimento YoY da frota', 'CO2 evitado por região', 'Projeção de expansão até 2030']
  },
  bi: {
    title: '📊 Power BI & Dados',
    color: '#9C27B0',
    desc: 'Infraestrutura de dados para análise no Power BI. 19 endpoints REST com suporte a JSON e CSV para importação direta.',
    dados_bi: ['19 endpoints REST disponíveis', 'Exportação CSV/JSON', 'Modelo estrela com 20 tabelas', 'Dados históricos e tempo real', 'APIs de agregação para KPIs'],
    tabelas: ['Todas (20 tabelas)'],
    metricas: ['Score de Sustentabilidade Municipal', 'Ranking por ODS da ONU', 'Índice composto ambiental', 'Análise preditiva de tendências']
  },
  denuncias: {
    title: '🚨 Denúncias Ambientais',
    color: '#F44336',
    desc: 'Canal de denúncias com geolocalização, categorização e acompanhamento de status de resolução.',
    dados_bi: ['Tipo de denúncia (desmatamento, poluição)', 'Status (pendente, resolvido)', 'Impacto estimado (baixo a crítico)', 'Órgão responsável', 'Coordenadas GPS'],
    tabelas: ['fato_denuncias'],
    metricas: ['Taxa de resolução por órgão', 'Mapa de hotspots ambientais', 'Tempo médio de resolução', 'Ranking de impacto por tipo']
  },
  clima: {
    title: '🌡️ Indicadores Climáticos',
    color: '#2196F3',
    desc: 'Série histórica de dados climáticos para análise de mudanças climáticas e eventos extremos.',
    dados_bi: ['Temperatura média/máx/mín', 'Precipitação mensal', 'Eventos extremos', 'Nível de reservatórios', 'Anomalia térmica vs histórico'],
    tabelas: ['fato_indicadores_climaticos'],
    metricas: ['Anomalia climática por região', 'Tendência de temperatura (°C/década)', 'Meses com eventos extremos', 'Correlação chuva x qualidade ar']
  },
  biodiversidade: {
    title: '🌿 Biodiversidade & Cobertura Vegetal',
    color: '#388E3C',
    desc: 'Monitoramento de desmatamento, reflorestamento e estoque de carbono em diferentes biomas.',
    dados_bi: ['Área de vegetação nativa (ha)', 'Taxa de desmatamento anual', 'Área reflorestada', 'Carbono estocado (ton)', 'NDVI (índice de vegetação)'],
    tabelas: ['fato_cobertura_vegetal', 'dim_especies'],
    metricas: ['Taxa de desmatamento por bioma', 'Evolução do reflorestamento', 'Carbono sequestrado por ação', 'Alerta de perda acima da meta']
  },
  politicas: {
    title: '⚖️ Políticas & Legislação',
    color: '#FF5722',
    desc: 'Base de dados de leis, decretos e políticas ambientais com acompanhamento de vigência e impacto.',
    dados_bi: ['Tipo (lei, decreto, resolução)', 'Esfera (federal, estadual, municipal)', 'Status (vigente, revogada)', 'Impacto ambiental', 'ODS relacionado'],
    tabelas: ['fato_politicas_ambientais'],
    metricas: ['Cobertura legislativa por tema', 'Conformidade com ODS ONU', 'Análise de lacunas regulatórias', 'Timeline de políticas aprovadas']
  },
  educacao: {
    title: '📚 Educação Ambiental',
    color: '#607D8B',
    desc: 'Plataforma de engajamento com quizzes, workshops, vídeos e sistema de pontuação e certificação.',
    dados_bi: ['Tipo de atividade', 'Pontuação e engajamento', 'Taxa de conclusão', 'Certificados emitidos', 'Pontos de sustentabilidade por usuário'],
    tabelas: ['fato_educacao_ambiental', 'dim_usuarios'],
    metricas: ['NPS de engajamento ambiental', 'Horas de educação por região', 'Correlação educação x ações práticas', 'Ranking de usuários por engajamento']
  },
};

function showInfo(key) {
  const box = document.getElementById('info-box');
  const content = document.getElementById('info-content');
  const d = infoData[key];
  if (!d) return;
  content.innerHTML = \`
    <div class="flex items-start justify-between mb-4">
      <h3 class="text-xl font-bold" style="color:\${d.color}">\${d.title}</h3>
      <button onclick="document.getElementById('info-box').style.display='none'" style="color:#66bb6a;font-size:1.5rem;background:none;border:none;cursor:pointer">✕</button>
    </div>
    <p class="text-sm mb-4" style="color:#a5d6a7">\${d.desc}</p>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div>
        <p class="text-xs font-bold mb-2" style="color:\${d.color}">📈 DADOS PARA POWER BI</p>
        \${d.dados_bi.map(d => \`<p class="text-xs mb-1" style="color:#81c784">▸ \${d}</p>\`).join('')}
      </div>
      <div>
        <p class="text-xs font-bold mb-2" style="color:\${d.color}">🗄️ TABELAS DO BANCO</p>
        \${d.tabelas.map(t => \`<p class="text-xs mb-1" style="color:#66bb6a;font-family:monospace;background:#0d2d0d;padding:2px 6px;border-radius:4px;display:inline-block;margin:1px">\${t}</p>\`).join('')}
      </div>
      <div>
        <p class="text-xs font-bold mb-2" style="color:\${d.color}">🎯 MÉTRICAS RECOMENDADAS</p>
        \${d.metricas.map(m => \`<p class="text-xs mb-1" style="color:#81c784">▸ \${m}</p>\`).join('')}
      </div>
    </div>
  \`;
  box.style.display = 'block';
  box.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}
</script>
</body>
</html>`
}

export default app
