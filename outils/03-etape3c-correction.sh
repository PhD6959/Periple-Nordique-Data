#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 3c : CORRECTION DU JEU FINLANDAIS + ALLÈGEMENT DES TROIS COUCHES
# =============================================================================
#
# DEUX PROBLÈMES CONSTATÉS À L'ÉTAPE 3b
#
# 1. Le filtre CQL n'a pas été appliqué par le serveur finlandais : il a
#    renvoyé les 20 000 premières entités toutes limites confondues, dont
#    seules 1187 étaient sous 3 500 kg. Le champ « arvo » est de type texte,
#    et une comparaison numérique dessus est soit ignorée, soit fausse —
#    '12000' est inférieur à '4000' dans l'ordre alphabétique. On pagine donc
#    la totalité des 163 225 tronçons et on filtre localement.
#
# 2. La couche des cols pèse 15 Mo : lourde à charger dans un navigateur.
#    On ramène la précision à 5 décimales, soit environ un mètre, on retire
#    l'altitude et on simplifie les tracés. Aucune information utile perdue.
#
# UTILISATION — depuis le dossier contenant _out/
#   bash 03-etape3c-correction.sh
# =============================================================================

set -u
OUT="_out"; mkdir -p "$OUT/pages"
PTAC=3500
TOLERANCE=0.0001   # ~10 m : en deçà, un col reste un col

FIWFS="https://avoinapi.vaylapilvi.fi/vaylatiedot/digiroad/wfs"
PAS=20000

echo "== FI : pagination complète de kelirikko =="
i=0
while [ $i -lt 180000 ]; do
  F="$OUT/pages/kelirikko-$i.geojson"
  if [ ! -s "$F" ]; then
    curl -sS -G "$FIWFS" \
      --data-urlencode "service=WFS" --data-urlencode "version=2.0.0" \
      --data-urlencode "request=GetFeature" \
      --data-urlencode "typeNames=digiroad:dr_kelirikko" \
      --data-urlencode "outputFormat=application/json" \
      --data-urlencode "srsName=EPSG:4326" \
      --data-urlencode "count=$PAS" \
      --data-urlencode "startIndex=$i" \
      -o "$F"
  fi
  N=$(python3 -c "
import json,io,sys
try:
    d=json.load(io.open('$F',encoding='utf-8')); print(len(d.get('features',[])))
except Exception: print(0)")
  echo "   startIndex=$i -> $N entités"
  [ "$N" -lt "$PAS" ] && break
  i=$((i+PAS))
done

python3 - "$PTAC" "$TOLERANCE" <<'PY'
import json, io, os, sys, glob, math

PTAC = int(sys.argv[1]); TOL = float(sys.argv[2])
OUT = '_out'; rapport = []
def note(s):
    print(s); rapport.append(s)

# ------------------------------------------------------------ simplification
def perp(p, a, b):
    (x, y), (x1, y1), (x2, y2) = p[:2], a[:2], b[:2]
    dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0:
        return math.hypot(x - x1, y - y1)
    t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - (x1 + t * dx), y - (y1 + t * dy))

def douglas(pts, tol):
    if len(pts) < 3:
        return pts
    dmax, idx = 0.0, 0
    for i in range(1, len(pts) - 1):
        d = perp(pts[i], pts[0], pts[-1])
        if d > dmax:
            dmax, idx = d, i
    if dmax > tol:
        return douglas(pts[:idx + 1], tol)[:-1] + douglas(pts[idx:], tol)
    return [pts[0], pts[-1]]

def alleger(g, tol=TOL, prec=5):
    """Retire l'altitude, simplifie, arrondit."""
    if not g:
        return None
    t = g.get('type')
    def pt(c):
        return [round(float(c[0]), prec), round(float(c[1]), prec)]
    if t == 'Point':
        return {'type': 'Point', 'coordinates': pt(g['coordinates'])}
    if t == 'LineString':
        pts = [pt(c) for c in g['coordinates']]
        s = douglas(pts, tol) if len(pts) > 2 else pts
        return {'type': 'LineString', 'coordinates': s} if len(s) > 1 else None
    if t == 'MultiLineString':
        lignes = []
        for l in g['coordinates']:
            pts = [pt(c) for c in l]
            s = douglas(pts, tol) if len(pts) > 2 else pts
            if len(s) > 1:
                lignes.append(s)
        return {'type': 'MultiLineString', 'coordinates': lignes} if lignes else None
    return g

def compter(g):
    if not g:
        return 0
    c = g['coordinates']
    if g['type'] == 'Point':
        return 1
    if g['type'] == 'LineString':
        return len(c)
    return sum(len(l) for l in c)

# ------------------------------------------------------------ 1. FI recomposé
note('=== restrictions-degel (FI) — recomposition ===')
vus, retenus, total = set(), [], 0
for f in sorted(glob.glob(os.path.join(OUT, 'pages', 'kelirikko-*.geojson'))):
    try:
        d = json.load(io.open(f, encoding='utf-8'))
    except Exception as e:
        note('  page illisible %s : %s' % (os.path.basename(f), str(e)[:60])); continue
    for ft in d.get('features', []):
        total += 1
        p = ft.get('properties', {}) or {}
        pid = p.get('id')
        if pid in vus:
            continue
        vus.add(pid)
        try:
            limite = int(float(p.get('arvo')))
        except (TypeError, ValueError):
            continue
        if limite > PTAC:
            continue
        g = alleger(ft.get('geometry'))
        if not g:
            continue
        retenus.append({'type': 'Feature', 'geometry': g, 'properties': {
            'id': 'fi-degel-%s' % pid, 'country': 'fi',
            'name': 'kelirikko %s kg' % limite, 'type': 'restriction_degel',
            'source': 'VAYLA', 'updated': '2026-09-10',
            'limite_kg': limite,
            'periode_du': p.get('kestoalku1') or None,
            'periode_au': p.get('kestolopp1') or None,
            'recurrent': p.get('toistuva') in (1, '1'),
            'kunta': p.get('kuntakoodi')}})
note('  entités parcourues : %d (uniques : %d)' % (total, len(vus)))
note('  retenues sous %d kg : %d' % (PTAC, len(retenus)))
if total < 163225:
    note('  ATTENTION : %d entités seulement sur les 163 225 annoncées — pagination incomplète.' % total)
json.dump({'type': 'FeatureCollection', 'features': retenus},
          io.open(os.path.join(OUT, 'restrictions-degel.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
note('  -> restrictions-degel.geojson : %d Ko' % (os.path.getsize(os.path.join(OUT, 'restrictions-degel.geojson')) // 1024))

# ------------------------------------------------------------ 2. allègement NO
note('')
note('=== allègement des couches norvégiennes ===')
for nom in ('cols-fermetures.geojson', 'ferries.geojson'):
    c = os.path.join(OUT, nom)
    if not os.path.exists(c):
        note('  absent : ' + nom); continue
    avant_o = os.path.getsize(c)
    d = json.load(io.open(c, encoding='utf-8'))
    av = sum(compter(f.get('geometry')) for f in d['features'])
    gardees = []
    for f in d['features']:
        g = alleger(f.get('geometry'))
        if g:
            f['geometry'] = g
            gardees.append(f)
    ap = sum(compter(f.get('geometry')) for f in gardees)
    json.dump({'type': 'FeatureCollection', 'features': gardees},
              io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)
    note('  %-26s %d -> %d entités | %d -> %d points | %d Ko -> %d Ko'
         % (nom, len(d['features']), len(gardees), av, ap, avant_o // 1024, os.path.getsize(c) // 1024))

# ------------------------------------------------------------ 3. contrôles
note('')
note('=== contrôles ===')
for nom in ('cols-fermetures.geojson', 'ferries.geojson', 'restrictions-degel.geojson'):
    c = os.path.join(OUT, nom)
    if not os.path.exists(c):
        continue
    d = json.load(io.open(c, encoding='utf-8'))
    fs = d['features']
    hors, sans_nom, types = 0, 0, {}
    for f in fs:
        p = f['properties']
        types[p.get('type')] = types.get(p.get('type'), 0) + 1
        if not p.get('name') or p.get('name') == 'sans nom':
            sans_nom += 1
        g = f['geometry']; cc = g['coordinates']
        while isinstance(cc[0], list):
            cc = cc[0]
        if not (2 <= cc[0] <= 34 and 53 <= cc[1] <= 73):
            hors += 1
    note('  %-26s %5d entités | types %s | sans nom %d | hors emprise %d'
         % (nom, len(fs), types, sans_nom, hors))

note('')
note('=== échantillon après allègement ===')
d = json.load(io.open(os.path.join(OUT, 'cols-fermetures.geojson'), encoding='utf-8'))
for f in d['features'][:1]:
    g = dict(f['geometry']); g['coordinates'] = str(g['coordinates'])[:90] + '…'
    note('  ' + json.dumps({'properties': f['properties'], 'geometry': g}, ensure_ascii=False)[:620])

io.open(os.path.join(OUT, 'RAPPORT-3c.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT-3c.txt"
echo "=========================================="
echo "À me transmettre : $OUT/RAPPORT-3c.txt"
