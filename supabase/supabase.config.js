// ============================================================
// SustAmbiTech BI — Configuração Supabase
// Projeto: sustambitech-bi
// ============================================================
//
// CREDENCIAIS DO PROJETO
// ─────────────────────────────────────────────────────────────
// ⚠️  NUNCA exponha a SERVICE ROLE KEY no frontend!
//     Use apenas a PUBLISHABLE (anon) key no browser.
//     A service key fica SOMENTE em variáveis de ambiente server-side.
//
// Dashboard: https://supabase.com/dashboard/project/qqlggpgsidfhqjgzbwhp
// ─────────────────────────────────────────────────────────────

export const SUPABASE_CONFIG = {
  // ── Identificação do Projeto ───────────────────────────────
  projectName:  'sustambitech-bi',
  projectRef:   'qqlggpgsidfhqjgzbwhp',
  projectUrl:   'https://qqlggpgsidfhqjgzbwhp.supabase.co',

  // ── Chave Pública (segura para uso no frontend) ────────────
  // Usada para: SELECT em tabelas públicas, insert anônimo com RLS
  anonKey: 'sb_publishable_uYst_J1hEV_IctGezpfuRQ_5QsjkHI8',

  // ── Conexão Direta PostgreSQL (somente server-side / scripts) ─
  // Porta 5432 = Direct Connection (transações longas, migrations)
  // Porta 6543 = Transaction Pooler  (serverless / edge functions)
  // Porta 5432 = Session Pooler      (conexões persistentes)
  //
  // ⚠️  Substitua [YOUR-PASSWORD] pela senha definida no Supabase Dashboard
  //     Settings → Database → Database password
  directConnectionString: 'postgresql://postgres:[YOUR-PASSWORD]@db.qqlggpgsidfhqjgzbwhp.supabase.co:5432/postgres',

  // ── REST API (Supabase auto-gerada a partir do schema) ─────
  restUrl:     'https://qqlggpgsidfhqjgzbwhp.supabase.co/rest/v1',
  authUrl:     'https://qqlggpgsidfhqjgzbwhp.supabase.co/auth/v1',
  storageUrl:  'https://qqlggpgsidfhqjgzbwhp.supabase.co/storage/v1',
  realtimeUrl: 'wss://qqlggpgsidfhqjgzbwhp.supabase.co/realtime/v1',

  // ── CLI — Comandos de Setup ────────────────────────────────
  // Execute na ordem abaixo para vincular este repositório:
  //
  //   1. npm install -g supabase
  //   2. supabase login
  //   3. supabase init             (cria pasta supabase/ local — já criada)
  //   4. supabase link --project-ref qqlggpgsidfhqjgzbwhp
  //   5. supabase db push          (aplica migrations em produção)
  //
  // Para desenvolvimento local com Supabase emulado:
  //   supabase start               (Docker necessário)
  //   supabase status              (ver URLs locais)
  //   supabase stop

  // ── Migrations (ordem de execução) ────────────────────────
  migrations: [
    '001_enums_e_extensoes.sql',       // UUID, ENUMs
    '002_tabelas_principais.sql',      // usuarios, enderecos, postos, tomadas, veiculos, avaliacoes, clima
    '003_tabelas_auditoria_backup.sql',// auditoria_log + tabelas _bkp
    '004_funcoes_triggers.sql',        // fn_* + triggers automáticos
    '005_views_powerbi.sql',           // VIEWs para Power BI
    '006_indexes.sql',                 // Índices de performance
  ],

  // ── Seeds ─────────────────────────────────────────────────
  seeds: [
    'seed_referencias.sql',   // ENUMs, tipos de conector, veículos
    'seed_postos.sql',        // 57 postos migrados do Firebase
  ],
}

// ── Uso com @supabase/supabase-js ─────────────────────────
//
//   import { createClient } from '@supabase/supabase-js'
//   import { SUPABASE_CONFIG } from './supabase/supabase.config.js'
//
//   // Frontend (anon key — respeitará Row Level Security)
//   export const supabase = createClient(
//     SUPABASE_CONFIG.projectUrl,
//     SUPABASE_CONFIG.anonKey
//   )
//
//   // Server-side / API (service role — bypass RLS)
//   // ⚠️  NUNCA use no frontend!
//   export const supabaseAdmin = createClient(
//     SUPABASE_CONFIG.projectUrl,
//     process.env.SUPABASE_SERVICE_ROLE_KEY
//   )

export default SUPABASE_CONFIG
