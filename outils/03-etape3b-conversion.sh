#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 3b : CONVERSION VERS LE SCHÉMA COMMUN
# =============================================================================
#
# Produit trois GeoJSON dans _out/ :
#   cols-fermetures.geojson     (NO — 107 Værutsatt veg + 883 Skredutsatt veg)
#   ferries.geojson             (NO — 770 Ferjesamband + 64 Ferjekai)
#   restrictions-degel.geojson  (FI — kelirikko, filtré sur le PTAC du fourgon)
#
# POINT TECHNIQUE : la NVDB renvoie du WKT en srid 4326 avec les coordonnées
# dans l'ordre latitude puis longitude. GeoJSON impose l'inverse. Le script
# les permute, et contrôle que le résultat tombe bien sur la Scandinavie.
#
# UTILISATION — depuis le dossier contenant _extract/
#   bash 03-etape3b-conversion.sh
# =============================================================================

set -u
IN="_extract"; OUT="_out"; mkdir -p "$OUT"
PTAC=3500   # kg, carte grise du fourgon

# -----------------------------------------------------------------------------
# FINLANDE — nouvelle extraction filtrée.
# 163 225 tronçons au total : impossible et inutile de tout prendre. Seules
# comptent les restrictions dont la limite est inférieure ou égale au PTAC.
# -----------------------------------------------------------------------------
echo "== FI : extraction filtrée (limite <= $PTAC kg) =="
FIWFS="https://avoinapi.vaylapilvi.fi/vaylatiedot/digiroad/wfs"
curl -sS -G "$FIWFS" \
  --data-urlencode "service=WFS" --data-urlencode "version=2.0.0" \
  --data-urlencode "request=GetFeature" \
  --data-urlencode "typeNames=digiroad:dr_kelirikko" \
  --data-urlencode "outputFormat=application/json" \
  --data-urlencode "srsName=EPSG:4326" \
  --data-urlencode "count=20000" \
  --data-urlencode "CQL_FILTER=arvo <= $PTAC" \
  -o "$OUT/fi-kelirikko-filtre.geojson"
head -c 200 "$OUT/fi-kelirikko-filtre.geojson" | grep -qi "exception\|error" \
  && echo "   ATTENTION : le filtre CQL semble refusé, voir le fichier" \
  || echo "   téléchargé : $(du -h "$OUT/fi-kelirikko-filtre.geojson" | cut -f1)"

python3 - "$PTAC" <<'PY'
import json, io, os, sys, re, datetime

PTAC = int(sys.argv[1])
AUJ = datetime.date.today().isoformat()
IN, OUT = '_extract', '_out'
rapport = []

def note(s):
    print(s); rapport.append(s)

# ---------------------------------------------------------------- WKT -> GeoJSON
def nombres(bloc):
    """Un bloc « x y z, x y z » -> liste de couples permutés en lon, lat."""
    pts = []
    for p in bloc.split(','):
        v = p.replace('(', ' ').replace(')', ' ').split()
        if len(v) >= 2:
            try:
                lat, lon = float(v[0]), float(v[1])   # NVDB : lat puis lon
            except ValueError:
                continue
            pts.append([round(lon, 7), round(lat, 7)])
    return pts

def wkt_vers_geojson(wkt):
    if not wkt:
        return None
    w = wkt.strip()
    t = w.split('(')[0].strip().upper().replace(' Z', '').replace(' M', '')
    corps = w[w.find('('):]
    if t == 'POINT':
        p = nombres(corps)
        return {'type': 'Point', 'coordinates': p[0]} if p else None
    if t == 'LINESTRING':
        p = nombres(corps)
        return {'type': 'LineString', 'coordinates': p} if len(p) > 1 else None
    if t in ('MULTILINESTRING', 'POLYGON'):
        blocs = re.findall(r'\(([^()]*)\)', corps)
        lignes = [nombres(b) for b in blocs]
        lignes = [l for l in lignes if len(l) > 1]
        if not lignes:
            return None
        if t == 'POLYGON':
            # on ne garde que le centre du contour extérieur : un quai de bac
            # est un point sur la carte, pas une surface
            ext = lignes[0]
            return {'type': 'Point', 'coordinates':
                    [round(sum(c[0] for c in ext)/len(ext), 7),
                     round(sum(c[1] for c in ext)/len(ext), 7)]}
        return {'type': 'MultiLineString', 'coordinates': lignes}
    return None

def dans_scandinavie(g):
    """Contrôle de plausibilité : lon 4..32, lat 54..72."""
    def coords(x):
        if isinstance(x, list) and x and isinstance(x[0], (int, float)):
            yield x
        elif isinstance(x, list):
            for y in x:
                for c in coords(y):
                    yield c
    for lon, lat in coords(g.get('coordinates', [])):
        if not (2.0 <= lon <= 34.0 and 53.0 <= lat <= 73.0):
            return False
    return True

def lire(nom):
    c = os.path.join(IN, nom)
    if not os.path.exists(c):
        note('  fichier absent : ' + nom); return []
    return json.load(io.open(c, encoding='utf-8'))

def eg(o):
    return {e.get('navn'): e.get('verdi') for e in (o.get('egenskaper') or [])}

def commune(o):
    l = o.get('lokasjon') or {}
    k = l.get('kommuner') or []
    return k[0] if k else None

def route(o):
    l = o.get('lokasjon') or {}
    for v in (l.get('vegsystemreferanser') or []):
        vs = v.get('vegsystem') or {}
        if vs.get('nummer'):
            return str(vs.get('vegkategori', '')) + str(vs.get('nummer'))
    return None

# ---------------------------------------------------------------- 1. COLS
note('=== cols-fermetures ===')
feats, hors_zone = [], 0

for o in lire('no-107-vaerutsatt-veg.json'):
    p = eg(o)
    col = p.get('Fjellovergang') == 'Ja'
    du, au = p.get('Vinterstengt, fra dato'), p.get('Vinterstengt, til dato')
    if not col and not (du or au):
        continue                      # ni col, ni fermeture hivernale datée
    g = wkt_vers_geojson((o.get('geometri') or {}).get('wkt'))
    if not g:
        continue
    if not dans_scandinavie(g):
        hors_zone += 1; continue
    nom = p.get('Navn') or ' - '.join(x for x in (p.get('Sted, fra'), p.get('Sted, til')) if x) or 'sans nom'
    feats.append({'type': 'Feature', 'geometry': g, 'properties': {
        'id': 'no-cols-%s' % o.get('id'), 'country': 'no', 'name': nom,
        'type': 'fjellovergang' if col else 'vinterstengt',
        'source': 'NVDB', 'updated': AUJ,
        'route': route(o), 'kommune': commune(o),
        'ferme_du': du, 'ferme_au': au,
        'nuit_du': p.get('Nattestengt, fra dato'), 'nuit_au': p.get('Nattestengt, til dato'),
        'jours_fermes_an': p.get('Antall stengte døgn'),
        'neige_cm': p.get('Snødybde'), 'pente_pct': p.get('Stigning, offisiell'),
        'de': p.get('Sted, fra'), 'a': p.get('Sted, til'),
        'barriere_de': p.get('Sted lokalt, fra'), 'barriere_a': p.get('Sted lokalt, til'),
        'info': p.get('Tilleggsinformasjon')}})

n107 = len(feats)
note('  107 Værutsatt veg retenus : %d' % n107)

for o in lire('no-883-skredutsatt-veg.json'):
    p = eg(o)
    g = wkt_vers_geojson((o.get('geometri') or {}).get('wkt'))
    if not g:
        continue
    if not dans_scandinavie(g):
        hors_zone += 1; continue
    types = [p.get('Skredtype1'), p.get('Skredtype2'), p.get('Skredtype3')]
    feats.append({'type': 'Feature', 'geometry': g, 'properties': {
        'id': 'no-skred-%s' % o.get('id'), 'country': 'no',
        'name': p.get('Navn') or 'sans nom', 'type': 'skredutsatt',
        'source': 'NVDB', 'updated': AUJ,
        'route': route(o), 'kommune': commune(o),
        'skred_types': ', '.join(x for x in types if x) or None,
        'frequence': p.get('Gjentakelsesintervall'),
        'info': p.get('Tilleggsinformasjon')}})
note('  883 Skredutsatt veg retenus : %d' % (len(feats) - n107))
note('  écartés hors emprise scandinave : %d' % hors_zone)
json.dump({'type': 'FeatureCollection', 'features': feats},
          io.open(os.path.join(OUT, 'cols-fermetures.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
note('  -> %d entités' % len(feats))

# ---------------------------------------------------------------- 2. FERRIES
note('')
note('=== ferries ===')
feats, hors_zone = [], 0
for o in lire('no-770-ferjesamband.json'):
    p = eg(o)
    g = wkt_vers_geojson((o.get('geometri') or {}).get('wkt'))
    if not g or not dans_scandinavie(g):
        hors_zone += (0 if not g else 1); continue
    feats.append({'type': 'Feature', 'geometry': g, 'properties': {
        'id': 'no-ferry-%s' % o.get('id'), 'country': 'no',
        'name': p.get('Navn') or 'sans nom', 'type': 'liaison',
        'source': 'NVDB', 'updated': AUJ,
        'route': route(o),
        'exploitation': p.get('Driftsstatus'), 'categorie': p.get('Sambandstype'),
        'autopass': p.get('AutoPASS for ferje'),
        'saison_du': p.get('Drift fra dato'), 'saison_au': p.get('Drift til dato'),
        'lien': p.get('Referanse til ekstern info')}})
nl = len(feats)
note('  770 liaisons : %d' % nl)

for o in lire('no-64-ferjekai.json'):
    p = eg(o)
    g = wkt_vers_geojson((o.get('geometri') or {}).get('wkt'))
    if not g or not dans_scandinavie(g):
        hors_zone += (0 if not g else 1); continue
    feats.append({'type': 'Feature', 'geometry': g, 'properties': {
        'id': 'no-quai-%s' % o.get('id'), 'country': 'no',
        'name': p.get('Navn') or 'sans nom', 'type': 'quai',
        'source': 'NVDB', 'updated': AUJ,
        'kommune': commune(o),
        'exploitation': p.get('Driftsstatus'),
        'nb_rampes': p.get('Antall ferjelemmer'),
        'salle_attente': p.get('Venterom'),
        'proprietaire': p.get('Eier')}})
note('  64 quais : %d' % (len(feats) - nl))
note('  écartés hors emprise : %d' % hors_zone)
json.dump({'type': 'FeatureCollection', 'features': feats},
          io.open(os.path.join(OUT, 'ferries.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
note('  -> %d entités' % len(feats))

# ---------------------------------------------------------------- 3. DÉGEL FI
note('')
note('=== restrictions-degel (FI) ===')
src = os.path.join(OUT, 'fi-kelirikko-filtre.geojson')
try:
    d = json.load(io.open(src, encoding='utf-8'))
    fs = d.get('features', [])
    note('  entités renvoyées par le filtre CQL : %d' % len(fs))
    out = []
    for f in fs:
        p = f.get('properties', {}) or {}
        try:
            limite = int(float(p.get('arvo')))
        except (TypeError, ValueError):
            continue
        if limite > PTAC:
            continue
        out.append({'type': 'Feature', 'geometry': f.get('geometry'), 'properties': {
            'id': 'fi-degel-%s' % p.get('id'), 'country': 'fi',
            'name': 'kelirikko %s kg' % limite, 'type': 'restriction_degel',
            'source': 'VAYLA', 'updated': AUJ,
            'limite_kg': limite, 'periode_du': p.get('kestoalku1'), 'periode_au': p.get('kestolopp1'),
            'recurrent': p.get('toistuva') in (1, '1'), 'kunta': p.get('kuntakoodi')}})
    json.dump({'type': 'FeatureCollection', 'features': out},
              io.open(os.path.join(OUT, 'restrictions-degel.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
    note('  -> %d entités retenues (limite <= %d kg)' % (len(out), PTAC))
except Exception as e:
    note('  échec : ' + str(e)[:150])

# ---------------------------------------------------------------- rapport
note('')
note('=== échantillons ===')
for nom in ('cols-fermetures.geojson', 'ferries.geojson', 'restrictions-degel.geojson'):
    c = os.path.join(OUT, nom)
    if not os.path.exists(c):
        continue
    d = json.load(io.open(c, encoding='utf-8'))
    fs = d['features']
    note('-- %s : %d entités, %d Ko' % (nom, len(fs), os.path.getsize(c) // 1024))
    for f in fs[:2]:
        g = dict(f['geometry']); c0 = g.get('coordinates')
        g['coordinates'] = str(c0)[:110] + '…'
        note('   ' + json.dumps({'properties': f['properties'], 'geometry': g}, ensure_ascii=False)[:700])

io.open(os.path.join(OUT, 'RAPPORT.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT.txt"
echo "=========================================="
ls -la "$OUT"
echo
echo "À me transmettre : le contenu de $OUT/RAPPORT.txt"
