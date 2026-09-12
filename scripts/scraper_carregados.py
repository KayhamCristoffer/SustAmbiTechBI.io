#!/usr/bin/env python3
"""
SustAmbiTech BI — Scraper de Estações de Recarga v2.0
======================================================
Coleta dados de estações EV no Brasil com sistema anti-bot completo:
  • Delays aleatórios por operação (configuráveis via CLI)
  • Rotação de User-Agent entre 6 perfis de browser reais
  • Headers realistas (Accept-Language, Referer, Accept-Encoding)
  • Backoff exponencial em erros 429/503
  • Delays extras entre lotes de 50 registros

Fontes (em ordem de prioridade):
  Tier 1 → API Carregados.com.br
  Tier 2 → OpenChargeMap API (gratuita; KEY opcional via OCM_API_KEY)
  Tier 3 → Dataset mock realista (400–500 registros distribuídos por estado)

Saída:
  data/estacoes.json  — Array JSON principal consumido pelo mapa do site
  data/meta.json      — Metadados, estatísticas e hash de integridade
  data/scraper.log    — Log completo de execução (append)

Uso:
  python3 scripts/scraper_carregados.py                   # modo padrão
  python3 scripts/scraper_carregados.py --delay-min 3 --delay-max 12
  python3 scripts/scraper_carregados.py --quiet           # menos logs
  python3 scripts/scraper_carregados.py --mock            # forçar mock offline
  python3 scripts/scraper_carregados.py --max-records 1000
  OCM_API_KEY=sua_chave python3 scripts/scraper_carregados.py
"""

import argparse
import datetime
import hashlib
import json
import os
import random
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# ─── Diretórios ───────────────────────────────────────────────────────────────

SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR    = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR  = os.path.join(ROOT_DIR, 'data')
OUTPUT_FILE = os.path.join(OUTPUT_DIR, 'estacoes.json')
META_FILE   = os.path.join(OUTPUT_DIR, 'meta.json')
LOG_FILE    = os.path.join(OUTPUT_DIR, 'scraper.log')

# ─── User-Agents reais (6 perfis de browsers modernos) ────────────────────────

USER_AGENTS = [
    # Chrome 125 Windows
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
    # Chrome 124 macOS
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    # Firefox 126 Windows
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:126.0) Gecko/20100101 Firefox/126.0',
    # Firefox 125 Linux
    'Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0',
    # Edge 124 Windows
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0',
    # Safari 17 macOS
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15',
]

# ─── Headers base (complementados com UA rotativo em cada request) ─────────────

BASE_HEADERS = {
    'Accept':          'application/json, text/html, */*',
    'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    'Accept-Encoding': 'gzip, deflate, br',
    'Referer':         'https://carregados.com.br/',
    'Origin':          'https://carregados.com.br',
    'DNT':             '1',
    'Connection':      'keep-alive',
}

# ─── Estados brasileiros ───────────────────────────────────────────────────────

ESTADOS = {
    'AC': 'Acre',            'AL': 'Alagoas',          'AP': 'Amapá',
    'AM': 'Amazonas',        'BA': 'Bahia',             'CE': 'Ceará',
    'DF': 'Distrito Federal','ES': 'Espírito Santo',    'GO': 'Goiás',
    'MA': 'Maranhão',        'MT': 'Mato Grosso',       'MS': 'Mato Grosso do Sul',
    'MG': 'Minas Gerais',    'PA': 'Pará',              'PB': 'Paraíba',
    'PR': 'Paraná',          'PE': 'Pernambuco',        'PI': 'Piauí',
    'RJ': 'Rio de Janeiro',  'RN': 'Rio Grande do Norte','RS': 'Rio Grande do Sul',
    'RO': 'Rondônia',        'RR': 'Roraima',           'SC': 'Santa Catarina',
    'SP': 'São Paulo',       'SE': 'Sergipe',            'TO': 'Tocantins',
}

# ─── Configuração global (pode ser sobrescrita por CLI) ────────────────────────

CONFIG = {
    'delay_min':   2.0,   # segundos entre requests comuns
    'delay_max':   8.0,
    'delay_api_min': 1.0, # entre chamadas de API paginadas
    'delay_api_max': 4.0,
    'delay_batch':   8.0, # após cada lote de 50 registros
    'delay_batch_jitter': 7.0,
    'backoff_base':  30.0, # após 429/503
    'backoff_jitter': 30.0,
    'max_retries':   3,
    'timeout':       15,
    'quiet':         False,
    'force_mock':    False,
    'max_records':   0,    # 0 = sem limite
}

# ─── Logging ──────────────────────────────────────────────────────────────────

def log(msg: str, level: str = 'INFO') -> None:
    ts   = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{ts}] [{level:5s}] {msg}'
    if not CONFIG['quiet'] or level in ('ERROR', 'WARN'):
        print(line, flush=True)
    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as fh:
            fh.write(line + '\n')
    except OSError:
        pass

# ─── Delays anti-bot ──────────────────────────────────────────────────────────

def sleep_between_requests(label: str = '') -> None:
    """Delay aleatório entre requests comuns (simula leitura humana)."""
    t = random.uniform(CONFIG['delay_min'], CONFIG['delay_max'])
    if not CONFIG['quiet']:
        log(f'Aguardando {t:.1f}s{" — " + label if label else ""}…', 'WAIT')
    time.sleep(t)

def sleep_api_page() -> None:
    """Delay menor entre páginas da mesma API (paginação)."""
    t = random.uniform(CONFIG['delay_api_min'], CONFIG['delay_api_max'])
    time.sleep(t)

def sleep_batch(batch_num: int) -> None:
    """Delay maior entre lotes de 50 registros para não parecer bot."""
    t = CONFIG['delay_batch'] + random.uniform(0, CONFIG['delay_batch_jitter'])
    log(f'Pausa após lote #{batch_num} — aguardando {t:.1f}s…', 'WAIT')
    time.sleep(t)

def sleep_backoff(attempt: int, code: int) -> None:
    """Backoff exponencial após 429/503 (rate limit)."""
    t = CONFIG['backoff_base'] + random.uniform(0, CONFIG['backoff_jitter'])
    t *= (attempt + 1)  # exponencial simples
    log(f'Rate limit HTTP {code} — backoff {t:.0f}s (tentativa {attempt+1})…', 'WARN')
    time.sleep(t)

# ─── HTTP com rotação de User-Agent ───────────────────────────────────────────

def get_headers() -> dict:
    """Retorna headers com User-Agent rotativo."""
    h = dict(BASE_HEADERS)
    h['User-Agent'] = random.choice(USER_AGENTS)
    return h

def make_request(url: str, params: dict = None) -> object:
    """
    GET com retry automático, backoff em 429/503 e rotação de UA.
    Retorna objeto Python ou None em falha definitiva.
    """
    if params:
        url = url + '?' + urllib.parse.urlencode(params)

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode    = ssl.CERT_NONE

    for attempt in range(CONFIG['max_retries']):
        req = urllib.request.Request(url, headers=get_headers())
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=CONFIG['timeout']) as resp:
                raw = resp.read()
                # Tenta detectar gzip (urllib não descomprime automaticamente em todos os casos)
                try:
                    import gzip
                    raw = gzip.decompress(raw)
                except Exception:
                    pass
                return json.loads(raw.decode('utf-8', errors='replace'))
        except urllib.error.HTTPError as e:
            if e.code in (429, 503):
                sleep_backoff(attempt, e.code)
            elif e.code in (401, 403):
                log(f'Acesso negado HTTP {e.code} em {url}', 'WARN')
                return None  # não retenta — sem autorização
            elif e.code == 404:
                log(f'Endpoint não encontrado HTTP 404: {url}', 'WARN')
                return None
            else:
                log(f'HTTP {e.code} em {url} (tentativa {attempt+1}/{CONFIG["max_retries"]})', 'WARN')
                time.sleep(3 * (attempt + 1))
        except Exception as exc:
            log(f'Erro em {url}: {exc} (tentativa {attempt+1}/{CONFIG["max_retries"]})', 'WARN')
            time.sleep(3 * (attempt + 1))

    log(f'Falha definitiva após {CONFIG["max_retries"]} tentativas: {url}', 'ERROR')
    return None

# ─── TIER 1: API Carregados.com.br ────────────────────────────────────────────

CARREGADOS_ENDPOINTS = [
    'https://api.carregados.com.br/v2/estacoes',
    'https://carregados.com.br/api/estacoes',
    'https://carregados.com.br/api/v1/locations',
    'https://carregados.com.br/api/v1/chargers',
]

def fetch_carregados(page: int = 1, limit: int = 50) -> list:
    """Tenta endpoints da API Carregados com delay entre cada tentativa."""
    params = {'page': page, 'limit': limit, 'ordenar': 'nome'}
    for i, ep in enumerate(CARREGADOS_ENDPOINTS):
        if i > 0:
            sleep_between_requests(f'próximo endpoint Carregados ({i+1}/{len(CARREGADOS_ENDPOINTS)})')
        result = make_request(ep, params)
        if result:
            items = result if isinstance(result, list) else result.get('data', result.get('estacoes', []))
            if items and isinstance(items, list):
                log(f'Carregados API OK: {len(items)} registros (página {page})', 'INFO')
                return items
    return []

def fetch_all_carregados(max_pages: int = 20) -> list:
    """Coleta todas as páginas da API Carregados com delay entre páginas."""
    all_items = []
    for page in range(1, max_pages + 1):
        if page > 1:
            sleep_api_page()
            if page % 5 == 0:
                sleep_batch(page // 5)
        items = fetch_carregados(page=page, limit=50)
        if not items:
            log(f'Carregados: sem mais dados na página {page}', 'INFO')
            break
        all_items.extend(items)
        log(f'Carregados: acumulado {len(all_items)} registros (pág {page})', 'INFO')
        if CONFIG['max_records'] and len(all_items) >= CONFIG['max_records']:
            break
    return all_items

# ─── TIER 2: OpenChargeMap API ────────────────────────────────────────────────

OCM_ENDPOINT = 'https://api.openchargemap.io/v3/poi/'

def fetch_openchargemap() -> list:
    """
    Coleta estações do Brasil via OpenChargeMap.
    Sem chave: máx ~500 registros. Com OCM_API_KEY: sem limite.
    """
    log('Tentando OpenChargeMap API…', 'INFO')
    api_key = os.environ.get('OCM_API_KEY', '')
    params  = {
        'output':      'json',
        'countrycode': 'BR',
        'maxresults':  2000,
        'compact':     'true',
        'verbose':     'false',
    }
    if api_key:
        params['key'] = api_key
        log('OpenChargeMap: usando API key fornecida', 'INFO')
    else:
        log('OpenChargeMap: sem API key — limite público (~500 registros)', 'WARN')

    sleep_between_requests('antes de chamar OpenChargeMap')
    result = make_request(OCM_ENDPOINT, params)
    if result and isinstance(result, list):
        log(f'OpenChargeMap: {len(result)} registros obtidos', 'INFO')
        return result
    return []

def normalize_ocm(item: dict) -> dict:
    """Converte registro OCM para formato SustAmbiTech."""
    addr   = item.get('AddressInfo') or {}
    conns  = item.get('Connections')  or []
    tipos  = []
    pot_kw = 0

    # Mapeamento OCM → nosso label
    ocm_conn_map = {
        'CCS (Type 2)':           'CCS2 (Combo 2)',
        'CCS (Type 1)':           'CCS1 (Combo 1)',
        'CHAdeMO':                'CHAdeMO',
        'Type 2 (Socket Only)':   'Type 2 (IEC 62196)',
        'Type 2 (Tethered)':      'Type 2 (IEC 62196)',
        'Tesla (Roadster)':       'Tesla Supercharger',
        'Tesla (Model S/X)':      'Tesla Supercharger',
        'Tesla Supercharger':     'Tesla Supercharger',
        'Schuko':                 'AC Nível 1 (Tomada)',
        'Type 1 (J1772)':         'AC Nível 2 (Wallbox)',
        'GB/T AC':                'GB/T AC',
        'GB/T DC':                'GB/T DC',
    }
    for c in conns:
        ct  = ((c.get('ConnectionType') or {}).get('Title') or '').strip()
        mapped = ocm_conn_map.get(ct, ct)
        if mapped and mapped not in tipos:
            tipos.append(mapped)
        kw = c.get('PowerKW') or 0
        if kw > pot_kw:
            pot_kw = kw

    status_map = {1: 'Operacional', 2: 'Planejada', 50: 'Em_manutencao', 75: 'Temporariamente_fechada', 100: 'Operacional'}
    status_id  = ((item.get('StatusType') or {}).get('ID') or 0)
    status     = status_map.get(status_id, 'Operacional')

    return {
        'id':              f'ocm_{item.get("ID", "")}',
        'nome':            addr.get('Title') or 'Estação EV',
        'endereco':        addr.get('AddressLine1') or '',
        'cidade':          addr.get('Town') or '',
        'estado':          addr.get('StateOrProvince') or '',
        'cep':             addr.get('Postcode') or '',
        'lat':             addr.get('Latitude'),
        'lng':             addr.get('Longitude'),
        'tipos_conector':  tipos[:4],
        'potencia_kw':     round(pot_kw, 1),
        'status':          status,
        'acesso':          'Público',
        'operadora':       ((item.get('OperatorInfo') or {}).get('Title') or 'Desconhecida'),
        'fonte':           'OpenChargeMap',
        'data_atualizacao': datetime.datetime.now().strftime('%Y-%m-%d'),
    }

# ─── TIER 3: Dataset Mock Realista ────────────────────────────────────────────

def gerar_dados_mockados(total_alvo: int = 500) -> list:
    """
    Dataset mockado com distribuição proporcional aos dados reais ABVE 2024.
    Garante que o site nunca fica sem dados.
    """
    log(f'Gerando dataset mockado ({total_alvo} registros)…', 'INFO')

    operadoras = ['Blink', 'Eletrocar', 'Shell Recharge', 'BeCharge', 'Voe Energia',
                  'EDP', 'Neoenergia', 'Copel', 'Engie', 'Tesla', 'Zletric', 'EVPlug',
                  'ChargePoint', 'ABB', 'Siemens', 'WEG']

    conectores  = ['CCS2 (Combo 2)', 'CHAdeMO', 'Type 2 (IEC 62196)',
                   'AC Nível 2 (Wallbox)', 'Tesla Supercharger', 'AC Nível 1 (Tomada)']
    conn_weights = [0.30, 0.12, 0.28, 0.14, 0.08, 0.08]

    potencias_map = {
        'CCS2 (Combo 2)':      [50, 100, 150, 350],
        'CHAdeMO':             [50, 100],
        'Type 2 (IEC 62196)':  [7.4, 11, 22],
        'AC Nível 2 (Wallbox)':[3.7, 7.4, 11],
        'Tesla Supercharger':  [72, 150, 250, 350],
        'AC Nível 1 (Tomada)': [3.7],
    }

    ruas = ['das Flores', 'Brasil', 'São Paulo', 'das Palmeiras', 'Central', 'dos Ipês',
            'da Liberdade', 'XV de Novembro', 'Sete de Setembro', 'das Acácias',
            'Dom Pedro I', 'Getúlio Vargas', 'das Hortênsias', 'Bela Vista']

    # Cidades e pesos por estado (lat, lng, peso relativo)
    cidades_por_uf = {
        'SP': [('São Paulo',-23.5505,-46.6333,0.55),('Campinas',-22.9056,-47.0608,0.10),
               ('Santo André',-23.6639,-46.5383,0.05),('Ribeirão Preto',-21.1775,-47.8103,0.05),
               ('Santos',-23.9608,-46.3336,0.04),('Sorocaba',-23.5015,-47.4526,0.04),
               ('São Bernardo',-23.6900,-46.5650,0.04),('Guarulhos',-23.4543,-46.5337,0.04)],
        'RJ': [('Rio de Janeiro',-22.9068,-43.1729,0.60),('Niterói',-22.8838,-43.1044,0.15),
               ('Petrópolis',-22.5046,-43.1818,0.08),('Nova Iguaçu',-22.7595,-43.4514,0.06)],
        'MG': [('Belo Horizonte',-19.9167,-43.9345,0.55),('Uberlândia',-18.9186,-48.2772,0.12),
               ('Contagem',-19.9317,-44.0536,0.10),('Juiz de Fora',-21.7617,-43.3503,0.08)],
        'RS': [('Porto Alegre',-30.0346,-51.2177,0.45),('Caxias do Sul',-29.1678,-51.1794,0.12),
               ('Gramado',-29.3787,-50.8731,0.10),('Pelotas',-31.7654,-52.3371,0.08)],
        'PR': [('Curitiba',-25.4290,-49.2671,0.60),('Maringá',-23.4273,-51.9375,0.10),
               ('Londrina',-23.3045,-51.1696,0.08),('Foz do Iguaçu',-25.5478,-54.5882,0.06)],
        'SC': [('Florianópolis',-27.5954,-48.5480,0.50),('Joinville',-26.3044,-48.8487,0.15),
               ('Blumenau',-26.9195,-49.0661,0.12),('Itajaí',-26.9078,-48.6619,0.08)],
        'DF': [('Brasília',-15.7801,-47.9292,0.80),('Taguatinga',-15.8330,-48.0550,0.12)],
        'CE': [('Fortaleza',-3.7172,-38.5433,0.80),('Crato',-7.2318,-39.4100,0.10)],
        'BA': [('Salvador',-12.9714,-38.5014,0.65),('Feira de Santana',-12.2664,-38.9663,0.15)],
        'GO': [('Goiânia',-16.6869,-49.2648,0.75),('Anápolis',-16.3282,-48.9521,0.15)],
        'ES': [('Vitória',-20.3155,-40.3128,0.70),('Vila Velha',-20.3297,-40.2925,0.20)],
        'PE': [('Recife',-8.0476,-34.8770,0.75),('Caruaru',-8.2822,-35.9753,0.12)],
    }

    # Contagem proporcional por estado (dados ABVE 2024)
    contagem = {
        'SP':2641,'MG':1055,'RS':1031,'RJ':980,'PR':820,'SC':710,'DF':350,
        'CE':280,'BA':260,'GO':220,'ES':180,'PE':170,'MT':120,'MS':110,'AM':90,
        'PA':80,'MA':70,'PB':65,'RN':60,'PI':55,'SE':50,'AL':48,'TO':40,
        'RO':35,'AC':28,'AP':25,'RR':20
    }
    total_real = sum(contagem.values())

    estacoes = []
    idx = 1

    for uf, cnt_real in sorted(contagem.items(), key=lambda x: -x[1]):
        n = max(2, round(total_alvo * cnt_real / total_real))
        cidades = cidades_por_uf.get(uf)

        for i in range(n):
            if cidades:
                # seleção por peso acumulado
                r = random.random()
                acum = 0.0
                nome_c, lat_c, lng_c = cidades[-1][0], cidades[-1][1], cidades[-1][2]
                for c in cidades:
                    acum += c[3]
                    if r <= acum:
                        nome_c, lat_c, lng_c = c[0], c[1], c[2]
                        break
            else:
                nome_c = ESTADOS.get(uf, uf)
                lat_c, lng_c = -15.0 + random.uniform(-8, 8), -47.0 + random.uniform(-8, 8)

            lat = round(lat_c + random.uniform(-0.06, 0.06), 6)
            lng = round(lng_c + random.uniform(-0.06, 0.06), 6)

            conn = random.choices(conectores, weights=conn_weights)[0]
            pots = potencias_map.get(conn, [22])
            potencia = random.choice(pots)
            op = random.choice(operadoras)
            status = random.choices(
                ['Operacional', 'Em_manutencao', 'Temporariamente_fechada'],
                weights=[0.85, 0.08, 0.07]
            )[0]
            # chance de múltiplos conectores (30%)
            tipos = [conn]
            if random.random() < 0.30:
                extra = random.choice([c for c in conectores if c != conn])
                tipos.append(extra)

            cep = f'{random.randint(10000,99999):05d}-{random.randint(100,999):03d}'
            rua = random.choice(ruas)
            num = random.randint(100, 9999)

            estacoes.append({
                'id':              f'mock_{uf.lower()}_{idx:04d}',
                'nome':            f'{op} — {nome_c} #{i+1:03d}',
                'endereco':        f'R. {rua}, {num}',
                'bairro':          random.choice(['Centro', 'Jardim América', 'Vila Nova', 'Boa Vista', 'Pinheiros']),
                'cidade':          nome_c,
                'estado':          uf,
                'cep':             cep,
                'lat':             lat,
                'lng':             lng,
                'tipos_conector':  tipos,
                'potencia_kw':     potencia,
                'status':          status,
                'acesso':          random.choices(['Público','Semi-público','Privado'], weights=[0.65,0.20,0.15])[0],
                'operadora':       op,
                'fonte':           'Mock/SustAmbiTech',
                'data_atualizacao': datetime.datetime.now().strftime('%Y-%m-%d'),
            })
            idx += 1

        if idx > total_alvo:
            break

    log(f'Dataset mock: {len(estacoes)} registros gerados', 'INFO')
    return estacoes

# ─── Pipeline principal ───────────────────────────────────────────────────────

def run() -> int:
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Limpar log da execução anterior (mantém últimas 500 linhas)
    try:
        if os.path.exists(LOG_FILE):
            with open(LOG_FILE, 'r', encoding='utf-8') as fh:
                lines = fh.readlines()
            if len(lines) > 500:
                with open(LOG_FILE, 'w', encoding='utf-8') as fh:
                    fh.writelines(lines[-400:])
    except OSError:
        pass

    log('=' * 60)
    log('SustAmbiTech Scraper v2.0 — iniciando coleta')
    log(f'Delay configurado: {CONFIG["delay_min"]:.1f}s–{CONFIG["delay_max"]:.1f}s por request')
    log('=' * 60)

    estacoes: list = []
    fonte: str     = 'mock_sustambitech'

    if not CONFIG['force_mock']:
        # ── Tier 1: API Carregados ────────────────────────────────────────────
        log('⟶ TIER 1: tentando API Carregados.com.br…', 'INFO')
        raw = fetch_all_carregados(max_pages=10)
        if raw:
            estacoes = raw
            fonte    = 'carregados_api'
            log(f'✓ Tier 1 OK: {len(estacoes)} registros da API Carregados', 'INFO')

        # ── Tier 2: OpenChargeMap ─────────────────────────────────────────────
        if not estacoes:
            log('⟶ TIER 2: Carregados indisponível — tentando OpenChargeMap…', 'WARN')
            ocm_raw = fetch_openchargemap()
            if ocm_raw:
                sleep_between_requests('normalização OCM')
                estacoes = [normalize_ocm(x) for x in ocm_raw]
                fonte    = 'openchargemap'
                log(f'✓ Tier 2 OK: {len(estacoes)} registros do OpenChargeMap', 'INFO')

    # ── Tier 3: Mock ───────────────────────────────────────────────────────────
    if not estacoes:
        log('⟶ TIER 3: APIs indisponíveis ou --mock forçado — gerando dataset mockado…', 'WARN')
        max_mock = CONFIG['max_records'] if CONFIG['max_records'] else 500
        estacoes = gerar_dados_mockados(total_alvo=max_mock)
        fonte    = 'mock_sustambitech'

    # ── Deduplicação ──────────────────────────────────────────────────────────
    seen    : set  = set()
    unique  : list = []
    for e in estacoes:
        eid = str(e.get('id', ''))
        if eid and eid not in seen:
            seen.add(eid)
            unique.append(e)
        elif not eid:
            unique.append(e)  # sem ID — mantém
    estacoes = unique

    if CONFIG['max_records']:
        estacoes = estacoes[:CONFIG['max_records']]

    # ── Estatísticas ──────────────────────────────────────────────────────────
    por_estado:    dict = {}
    por_status:    dict = {}
    por_operadora: dict = {}
    por_conector:  dict = {}

    for e in estacoes:
        por_estado[e.get('estado','?')]    = por_estado.get(e.get('estado','?'), 0) + 1
        por_status[e.get('status','?')]    = por_status.get(e.get('status','?'), 0) + 1
        por_operadora[e.get('operadora','?')] = por_operadora.get(e.get('operadora','?'), 0) + 1
        for c in (e.get('tipos_conector') or []):
            por_conector[c] = por_conector.get(c, 0) + 1

    # ── Salvar estacoes.json ──────────────────────────────────────────────────
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as fh:
        json.dump(estacoes, fh, ensure_ascii=False, indent=2)
    log(f'Salvo: {OUTPUT_FILE} ({len(estacoes)} registros, fonte={fonte})', 'INFO')

    # ── Salvar meta.json ──────────────────────────────────────────────────────
    meta = {
        'total':          len(estacoes),
        'fonte':          fonte,
        'atualizado_em':  datetime.datetime.now().isoformat(),
        'por_estado':     dict(sorted(por_estado.items(),    key=lambda x: -x[1])),
        'por_status':     dict(sorted(por_status.items(),    key=lambda x: -x[1])),
        'top_operadoras': dict(list(sorted(por_operadora.items(), key=lambda x: -x[1]))[:15]),
        'por_conector':   dict(sorted(por_conector.items(),  key=lambda x: -x[1])),
        'hash':           hashlib.md5(json.dumps(estacoes, sort_keys=True).encode()).hexdigest(),
        'versao_scraper': '2.0',
    }
    with open(META_FILE, 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    log(f'Salvo: {META_FILE}', 'INFO')

    log('=' * 60)
    log(f'✓ CONCLUÍDO: {len(estacoes)} estações · fonte={fonte}')
    log(f'  Top estados: ' + ', '.join(f'{k}:{v}' for k, v in list(meta["por_estado"].items())[:5]))
    log(f'  Conectores:  ' + ', '.join(f'{k}:{v}' for k, v in list(meta["por_conector"].items())[:4]))
    log('=' * 60)

    return len(estacoes)

# ─── Entrypoint ───────────────────────────────────────────────────────────────

def parse_args() -> None:
    parser = argparse.ArgumentParser(
        description='SustAmbiTech Scraper de Estações EV v2.0',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos:
  python3 scripts/scraper_carregados.py
  python3 scripts/scraper_carregados.py --delay-min 3 --delay-max 12
  python3 scripts/scraper_carregados.py --quiet
  python3 scripts/scraper_carregados.py --mock
  python3 scripts/scraper_carregados.py --max-records 1000
  OCM_API_KEY=abc123 python3 scripts/scraper_carregados.py
        """
    )
    parser.add_argument('--delay-min',   type=float, default=2.0,
                        help='Delay mínimo entre requests em segundos (padrão: 2.0)')
    parser.add_argument('--delay-max',   type=float, default=8.0,
                        help='Delay máximo entre requests em segundos (padrão: 8.0)')
    parser.add_argument('--quiet',       action='store_true',
                        help='Modo silencioso — exibe apenas erros e resumo final')
    parser.add_argument('--mock',        action='store_true',
                        help='Forçar geração de dataset mock (sem chamadas de rede)')
    parser.add_argument('--max-records', type=int, default=0,
                        help='Limite máximo de registros (0 = sem limite)')
    args = parser.parse_args()
    CONFIG['delay_min']   = max(0.5, args.delay_min)
    CONFIG['delay_max']   = max(CONFIG['delay_min'] + 0.5, args.delay_max)
    CONFIG['quiet']       = args.quiet
    CONFIG['force_mock']  = args.mock
    CONFIG['max_records'] = args.max_records

if __name__ == '__main__':
    parse_args()
    count = run()
    sys.exit(0 if count > 0 else 1)
