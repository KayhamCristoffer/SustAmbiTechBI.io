#!/usr/bin/env python3
"""
SustAmbiTech BI — Scraper de Estações de Recarga
Fonte: carregados.com.br (API pública não oficial)
Gera: data/estacoes.json  +  data/meta.json
Uso:  python3 scripts/scraper_carregados.py
"""

import json
import time
import os
import sys
import hashlib
import datetime
import urllib.request
import urllib.error
import urllib.parse
import ssl
import random

# ─── Configuração ─────────────────────────────────────────────────────────────

OUTPUT_DIR   = os.path.join(os.path.dirname(__file__), '..', 'data')
OUTPUT_FILE  = os.path.join(OUTPUT_DIR, 'estacoes.json')
META_FILE    = os.path.join(OUTPUT_DIR, 'meta.json')
LOG_FILE     = os.path.join(OUTPUT_DIR, 'scraper.log')

# Rate limiting — espera entre requisições (segundos)
DELAY_MIN = 1.5
DELAY_MAX = 3.5

# Máximo de registros por estado (0 = sem limite)
MAX_POR_ESTADO = 0

# Headers que imitam browser real
HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/125.0.0.0 Safari/537.36'
    ),
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
    'Referer': 'https://carregados.com.br/',
    'Origin': 'https://carregados.com.br',
}

# Estados brasileiros (sigla → nome)
ESTADOS = {
    'AC': 'Acre', 'AL': 'Alagoas', 'AP': 'Amapá', 'AM': 'Amazonas',
    'BA': 'Bahia', 'CE': 'Ceará', 'DF': 'Distrito Federal',
    'ES': 'Espírito Santo', 'GO': 'Goiás', 'MA': 'Maranhão',
    'MT': 'Mato Grosso', 'MS': 'Mato Grosso do Sul', 'MG': 'Minas Gerais',
    'PA': 'Pará', 'PB': 'Paraíba', 'PR': 'Paraná', 'PE': 'Pernambuco',
    'PI': 'Piauí', 'RJ': 'Rio de Janeiro', 'RN': 'Rio Grande do Norte',
    'RS': 'Rio Grande do Sul', 'RO': 'Rondônia', 'RR': 'Roraima',
    'SC': 'Santa Catarina', 'SP': 'São Paulo', 'SE': 'Sergipe',
    'TO': 'Tocantins',
}

# ─── Utilitários ──────────────────────────────────────────────────────────────

def log(msg, level='INFO'):
    ts = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{ts}] [{level}] {msg}'
    print(line)
    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(line + '\n')
    except Exception:
        pass

def sleep_random():
    t = random.uniform(DELAY_MIN, DELAY_MAX)
    time.sleep(t)

def make_request(url, params=None):
    """GET request com retry e tratamento de erros."""
    if params:
        url = url + '?' + urllib.parse.urlencode(params)
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    req = urllib.request.Request(url, headers=HEADERS)
    
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
                data = resp.read().decode('utf-8')
                return json.loads(data)
        except urllib.error.HTTPError as e:
            log(f'HTTP {e.code} em {url} (tentativa {attempt+1}/3)', 'WARN')
            if e.code in (429, 503):
                time.sleep(10 * (attempt + 1))
            elif e.code == 403:
                log('Acesso bloqueado — using fallback data', 'WARN')
                return None
            else:
                time.sleep(3)
        except Exception as e:
            log(f'Erro em {url}: {e} (tentativa {attempt+1}/3)', 'WARN')
            time.sleep(3)
    
    log(f'Falha definitiva em {url}', 'ERROR')
    return None

# ─── Endpoints da API Carregados ──────────────────────────────────────────────
# A API pública do carregados.com.br é descoberta via inspeção das chamadas XHR

def fetch_estacoes_api(page=1, limit=100, estado=None):
    """
    Tenta a API REST do carregados.com.br
    Endpoint descoberto via Network Inspector do browser
    """
    params = {
        'page': page,
        'limit': limit,
        'ordenar': 'nome',
    }
    if estado:
        params['estado'] = estado
    
    # Endpoint principal descoberto
    endpoints = [
        'https://api.carregados.com.br/v2/estacoes',
        'https://carregados.com.br/api/estacoes',
        'https://carregados.com.br/api/v1/locations',
    ]
    
    for ep in endpoints:
        result = make_request(ep, params)
        if result:
            return result
        sleep_random()
    
    return None

def fetch_via_open_data():
    """
    Tenta fontes abertas alternativas de EV chargers no Brasil:
    - OpenChargeMap API (gratuita, sem key para leitura básica)
    - ANEEL dados abertos
    """
    log('Tentando OpenChargeMap API como fonte alternativa...', 'INFO')
    
    # OpenChargeMap — API aberta para EV chargers
    url = 'https://api.openchargemap.io/v3/poi/'
    params = {
        'output': 'json',
        'countrycode': 'BR',
        'maxresults': 2000,
        'compact': 'true',
        'verbose': 'false',
        'levelid': '2',  # Level 2 = DC fast chargers
    }
    
    result = make_request(url, params)
    if result and isinstance(result, list):
        log(f'OpenChargeMap: {len(result)} registros obtidos', 'INFO')
        return result
    
    return []

def normalize_ocm(item):
    """Normaliza um registro OpenChargeMap para nosso formato padrão."""
    addr = item.get('AddressInfo', {})
    conns = item.get('Connections', []) or []
    
    # Determina tipo de conector predominante
    tipos = []
    for c in conns:
        ct = (c.get('ConnectionType') or {}).get('Title', '')
        if ct:
            tipos.append(ct)
    
    potencia = 0
    for c in conns:
        p = c.get('PowerKW') or 0
        if p > potencia:
            potencia = p
    
    # Status
    status_map = {1: 'Operacional', 2: 'Planejada', 50: 'Em_manutencao', 75: 'Temporariamente_fechada'}
    status_id = (item.get('StatusType') or {}).get('ID', 0)
    status = status_map.get(status_id, 'Desconhecido')
    
    return {
        'id': f'ocm_{item.get("ID", "")}',
        'nome': addr.get('Title', 'Estação sem nome'),
        'endereco': addr.get('AddressLine1', ''),
        'cidade': addr.get('Town', ''),
        'estado': addr.get('StateOrProvince', ''),
        'cep': addr.get('Postcode', ''),
        'lat': addr.get('Latitude'),
        'lng': addr.get('Longitude'),
        'tipos_conector': tipos[:3],
        'potencia_kw': potencia,
        'status': status,
        'acesso': 'Público',
        'operadora': (item.get('OperatorInfo') or {}).get('Title', 'Desconhecido'),
        'fonte': 'OpenChargeMap',
        'data_atualizacao': datetime.datetime.now().strftime('%Y-%m-%d'),
    }

def gerar_dados_mockados():
    """
    Gera dataset mockado realista baseado em dados conhecidos do Brasil.
    Usado como fallback quando scraping falha ou para desenvolvimento.
    """
    log('Gerando dataset mockado como fallback...', 'INFO')
    
    import random
    
    operadoras = ['Blink', 'Eletrocar', 'Tupi', 'Shell Recharge', 'BeCharge', 
                  'Voe Energia', 'Copel', 'Engie', 'EDP', 'Neoenergia', 'Privada']
    
    conectores = ['CCS2 (Combo 2)', 'CHAdeMO', 'Type 2', 'GB/T', 'Tesla', 'Wallbox AC']
    
    # Cidades com maior concentração de EVSEs no Brasil (dados ABVE 2024)
    cidades_sp = [
        ('São Paulo', (-23.5505, -46.6333), 0.35),
        ('Campinas', (-22.9056, -47.0608), 0.08),
        ('Santo André', (-23.6639, -46.5383), 0.04),
        ('Ribeirão Preto', (-21.1775, -47.8103), 0.04),
        ('Santos', (-23.9608, -46.3336), 0.03),
        ('Sorocaba', (-23.5015, -47.4526), 0.03),
    ]
    
    cidades_rj = [
        ('Rio de Janeiro', (-22.9068, -43.1729), 0.60),
        ('Niterói', (-22.8838, -43.1044), 0.15),
        ('Petrópolis', (-22.5046, -43.1818), 0.07),
    ]
    
    cidades_mg = [
        ('Belo Horizonte', (-19.9167, -43.9345), 0.55),
        ('Uberlândia', (-18.9186, -48.2772), 0.12),
        ('Contagem', (-19.9317, -44.0536), 0.08),
    ]
    
    cidades_rs = [
        ('Porto Alegre', (-30.0346, -51.2177), 0.45),
        ('Caxias do Sul', (-29.1678, -51.1794), 0.10),
        ('Gramado', (-29.3787, -50.8731), 0.08),
    ]
    
    cidades_pr = [
        ('Curitiba', (-25.4290, -49.2671), 0.60),
        ('Maringá', (-23.4273, -51.9375), 0.10),
        ('Londrina', (-23.3045, -51.1696), 0.08),
    ]
    
    cidades_sc = [
        ('Florianópolis', (-27.5954, -48.5480), 0.50),
        ('Joinville', (-26.3044, -48.8487), 0.15),
        ('Blumenau', (-26.9195, -49.0661), 0.10),
    ]
    
    estado_cidades = {
        'SP': cidades_sp, 'RJ': cidades_rj, 'MG': cidades_mg,
        'RS': cidades_rs, 'PR': cidades_pr, 'SC': cidades_sc,
    }
    
    # Número aproximado de estações por estado (fonte: Carregados 2024)
    contagem_estados = {
        'SP': 2641, 'MG': 1055, 'RS': 1031, 'RJ': 980, 'PR': 820,
        'SC': 710, 'DF': 350, 'CE': 280, 'BA': 260, 'GO': 220,
        'ES': 180, 'PE': 170, 'MT': 120, 'MS': 110, 'AM': 90,
        'PA': 80, 'MA': 70, 'PB': 65, 'RN': 60, 'PI': 55,
        'SE': 50, 'AL': 48, 'TO': 40, 'RO': 35, 'AC': 28,
        'AP': 25, 'RR': 20,
    }
    
    total_alvo = 500  # Total de registros mockados para não sobrecarregar
    estacoes = []
    idx = 1
    
    for uf, total_uf in sorted(contagem_estados.items(), key=lambda x: -x[1]):
        # Proporcional ao total real mas limitado
        n = max(2, int(total_alvo * total_uf / 11783))
        cidades_uf = estado_cidades.get(uf, [])
        
        for i in range(n):
            # Seleciona cidade por peso
            if cidades_uf:
                r = random.random()
                acum = 0
                cidade_nome, (lat_c, lng_c), _ = cidades_uf[-1]
                for nome, coords, peso in cidades_uf:
                    acum += peso
                    if r <= acum:
                        cidade_nome, (lat_c, lng_c) = nome, coords
                        break
            else:
                # Coordenadas aproximadas do centroide do estado
                cidade_nome = ESTADOS.get(uf, uf)
                lat_c, lng_c = -15.0 - random.uniform(-5, 5), -47.0 - random.uniform(-5, 5)
            
            # Jitter de posição
            lat = lat_c + random.uniform(-0.08, 0.08)
            lng = lng_c + random.uniform(-0.08, 0.08)
            
            conector = random.choices(
                conectores,
                weights=[0.30, 0.15, 0.25, 0.10, 0.10, 0.10]
            )[0]
            
            potencias = {'CCS2 (Combo 2)': [50, 150, 350], 'CHAdeMO': [50, 100],
                         'Type 2': [7.4, 11, 22], 'GB/T': [50, 120],
                         'Tesla': [72, 150, 250], 'Wallbox AC': [7.4, 11]}
            potencia = random.choice(potencias.get(conector, [22]))
            
            op = random.choice(operadoras)
            status = random.choices(
                ['Operacional', 'Em_manutencao', 'Temporariamente_fechada'],
                weights=[0.85, 0.08, 0.07]
            )[0]
            
            estacoes.append({
                'id': f'mock_{uf.lower()}_{idx:04d}',
                'nome': f'{op} — {cidade_nome} #{i+1:03d}',
                'endereco': f'Rua {random.choice(["das Flores","Brasil","São Paulo","das Palmeiras","Central"])} {random.randint(100,9999)}',
                'cidade': cidade_nome,
                'estado': uf,
                'cep': f'{random.randint(10000,99999):05d}-{random.randint(100,999):03d}',
                'lat': round(lat, 6),
                'lng': round(lng, 6),
                'tipos_conector': [conector],
                'potencia_kw': potencia,
                'status': status,
                'acesso': random.choices(['Público', 'Semi-público', 'Privado'], weights=[0.65, 0.20, 0.15])[0],
                'operadora': op,
                'fonte': 'Mock/SustAmbiTech',
                'data_atualizacao': datetime.datetime.now().strftime('%Y-%m-%d'),
            })
            idx += 1
        
        if idx > total_alvo:
            break
    
    log(f'Dataset mockado gerado: {len(estacoes)} registros', 'INFO')
    return estacoes

# ─── Pipeline principal ───────────────────────────────────────────────────────

def run():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    log('=== SustAmbiTech Scraper iniciado ===')
    
    estacoes = []
    fonte = 'mock'
    
    # 1. Tenta API oficial do Carregados
    log('Tentando API Carregados.com.br...', 'INFO')
    result = fetch_estacoes_api(page=1, limit=50)
    if result and isinstance(result, (list, dict)):
        items = result if isinstance(result, list) else result.get('data', result.get('estacoes', []))
        if items:
            estacoes = items
            fonte = 'carregados_api'
            log(f'API Carregados: {len(estacoes)} registros', 'INFO')
    
    # 2. Tenta OpenChargeMap se Carregados falhou
    if not estacoes:
        log('Carregados indisponível, tentando OpenChargeMap...', 'WARN')
        sleep_random()
        ocm_data = fetch_via_open_data()
        if ocm_data:
            estacoes = [normalize_ocm(x) for x in ocm_data]
            fonte = 'openchargemap'
            log(f'OpenChargeMap: {len(estacoes)} registros normalizados', 'INFO')
    
    # 3. Fallback: dataset mockado
    if not estacoes:
        log('Fontes externas indisponíveis — usando dataset mockado', 'WARN')
        estacoes = gerar_dados_mockados()
        fonte = 'mock_sustambitech'
    
    # Deduplicação por ID
    seen = set()
    unique = []
    for e in estacoes:
        eid = str(e.get('id', ''))
        if eid and eid not in seen:
            seen.add(eid)
            unique.append(e)
    estacoes = unique
    
    # Estatísticas
    por_estado = {}
    por_status = {}
    por_operadora = {}
    
    for e in estacoes:
        uf = e.get('estado', 'N/A')
        st = e.get('status', 'N/A')
        op = e.get('operadora', 'N/A')
        por_estado[uf] = por_estado.get(uf, 0) + 1
        por_status[st] = por_status.get(st, 0) + 1
        por_operadora[op] = por_operadora.get(op, 0) + 1
    
    # Salvar JSON principal
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(estacoes, f, ensure_ascii=False, indent=2)
    log(f'Salvo: {OUTPUT_FILE} ({len(estacoes)} registros)')
    
    # Salvar metadados
    meta = {
        'total': len(estacoes),
        'fonte': fonte,
        'atualizado_em': datetime.datetime.now().isoformat(),
        'por_estado': dict(sorted(por_estado.items(), key=lambda x: -x[1])),
        'por_status': por_status,
        'top_operadoras': dict(sorted(por_operadora.items(), key=lambda x: -x[1])[:10]),
        'hash': hashlib.md5(json.dumps(estacoes, sort_keys=True).encode()).hexdigest(),
    }
    with open(META_FILE, 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    log(f'Salvo: {META_FILE}')
    log(f'=== Concluído: {len(estacoes)} estações · fonte={fonte} ===')
    
    return len(estacoes)

if __name__ == '__main__':
    count = run()
    sys.exit(0 if count > 0 else 1)
