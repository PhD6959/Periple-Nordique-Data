#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 40 : ZONES PROTÉGÉES NORVÉGIENNES — EXTRACTION
# =============================================================================
#
# Le service Naturvernområder de Miljødirektoratet est rétabli. La couche 0,
# naturvern_omrade, annonce 3 512 zones en polygones, avec nom officiel,
# catégorie UICN, forme de protection, autorité gestionnaire, commune, date de
# classement et lien vers la fiche Naturbase.
#
# C'est plus riche que la couche finlandaise, et c'était le dernier pays sans
# aucune zone protégée — alors que c'est celui où la question de l'accès se
# pose le plus : arrêté du Finnmark, règle de l'utmark.
#
# PAGINATION : un service ArcGIS plafonne le nombre d'entités par requête. On
# pagine par resultOffset, et on s'arrête quand une page revient vide ou plus
# courte que demandé. Le script signale si le total obtenu diffère du compte
# annoncé par le service.
#
# SIMPLIFICATION : comme pour la Finlande, la tolérance est PROPORTIONNELLE À
# LA TAILLE — une réserve d'un hectare ne se traite pas comme un parc de
# plusieurs centaines de km². Une tolérance unique effaçait 96 zones sur 1 091
# côté finlandais.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape40-zones-no-extraction.sh
# =============================================================================

set -u
OUT="_parcs"; mkdir -p "$OUT/no"
MDIR="https://kart.miljodirektoratet.no/arcgis/rest/services/vern/MapServer"
PAS=500

echo "== compte annoncé =="
curl -sS -m 45 -G "$MDIR/0/query" --data-urlencode "where=1=1" \
  --data-urlencode "returnCountOnly=true" --data-urlencode "f=json" \
  -o "$OUT/no-compte.json"
TOTAL=$(python3 -c "
import json,io
try:
    print(json.load(io.open('$OUT/no-compte.json',encoding='utf-8')).get('count',0))
except Exception:
    print(0)")
echo "   $TOTAL zones"
[ "$TOTAL" -eq 0 ] && { echo "Service indisponible — réessayer plus tard."; exit 1; }

echo
echo "== extraction par pages de $PAS =="
i=0
while [ "$i" -lt "$TOTAL" ]; do
  FIC="$OUT/no/page-$i.geojson"
  if [ ! -s "$FIC" ]; then
    curl -sS -m 180 -G "$MDIR/0/query" \
      --data-urlencode "where=1=1" \
      --data-urlencode "outFields=naturvernId,navn,offisieltNavn,verneform,verneformAggregert,iucn,forvaltningsmyndighet,kommune,vernedato,faktaark,SHAPE.STArea()" \
      --data-urlencode "returnGeometry=true" \
      --data-urlencode "outSR=4326" \
      --data-urlencode "f=geojson" \
      --data-urlencode "resultOffset=$i" \
      --data-urlencode "resultRecordCount=$PAS" -o "$FIC"
  fi
  N=$(python3 -c "
import json,io
try:
    t=io.open('$FIC',encoding='utf-8',errors='replace').read()
    if t.lstrip().startswith('<'): print(-1); raise SystemExit
    d=json.loads(t)
    print(-1 if 'error' in d else len(d.get('features',[])))
except Exception:
    print(-1)")
  if [ "$N" -eq -1 ]; then
    echo "   offset $i : échec — arrêt"
    rm -f "$FIC"
    break
  fi
  echo "   offset $i : $N entités"
  [ "$N" -eq 0 ] && break
  i=$((i + PAS))
  sleep 2
done

python3 - <<'PY' > "$OUT/RAPPORT40.txt" 2>&1
import json, io, os, glob, math, collections, datetime

IN = '_parcs'; AUJ = datetime.date.today().isoformat()
PRECISION = 4
rapport = []
def note(s):
    print(s); rapport.append(s)

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

def etendue(ring):
    xs = [c[0] for c in ring]; ys = [c[1] for c in ring]
    return max(max(xs) - min(xs), max(ys) - min(ys))

def tolerance_pour(e):
    if e > 0.5:  return 0.003
    if e > 0.1:  return 0.001
    if e > 0.02: return 0.0003
    return 0.0001

def anneau(ring, tol):
    p = [[round(float(c[0]), PRECISION), round(float(c[1]), PRECISION)] for c in ring]
    s = douglas(p, tol)
    if len(s) < 4:
        xs = [c[0] for c in p]; ys = [c[1] for c in p]
        return [[min(xs), min(ys)], [max(xs), min(ys)], [max(xs), max(ys)],
                [min(xs), max(ys)], [min(xs), min(ys)]], True
    if s[0] != s[-1]:
        s.append(s[0])
    return s, False

def aire(ring):
    a = 0.0
    for i in range(len(ring) - 1):
        a += ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1]
    return abs(a) / 2.0

# ------------------------------------------------------------ lecture
brut, vus = [], set()
pages = sorted(glob.glob(os.path.join(IN, 'no', 'page-*.geojson')),
               key=lambda x: int(x.split('-')[-1].split('.')[0]))
for f in pages:
    try:
        d = json.load(io.open(f, encoding='utf-8'))
    except Exception as e:
        note('page illisible : %s' % f); continue
    for x in d.get('features', []):
        p = x.get('properties', {}) or {}
        k = p.get('naturvernId') or p.get('OBJECTID')
        if k in vus:
            continue
        vus.add(k); brut.append(x)

note('=== zones protégées norvégiennes ===')
note('  pages lues : %d | entités uniques : %d' % (len(pages), len(brut)))
try:
    attendu = json.load(io.open(os.path.join(IN, 'no-compte.json'), encoding='utf-8')).get('count')
    if attendu and attendu != len(brut):
        note('  ATTENTION : le service annonçait %d zones, %d obtenues — pagination incomplète'
             % (attendu, len(brut)))
    elif attendu:
        note('  conforme au compte annoncé (%d)' % attendu)
except Exception:
    pass

# ------------------------------------------------------ simplification
feats = []
pts_a = pts_b = 0
approchees = 0
for x in brut:
    g = x.get('geometry') or {}
    t = g.get('type')
    if t == 'Polygon':
        polys = [g['coordinates']]
    elif t == 'MultiPolygon':
        polys = g['coordinates']
    else:
        continue
    ordre = sorted(range(len(polys)), key=lambda i: -aire(polys[i][0]) if polys[i] else 0)
    sortie, principal_approche = [], False
    for rang, i in enumerate(ordre):
        anneaux = []
        for j, ring in enumerate(polys[i]):
            pts_a += len(ring)
            a, env = anneau(ring, tolerance_pour(etendue(ring)))
            pts_b += len(a)
            if env and rang == 0 and j == 0:
                principal_approche = True
            anneaux.append(a)
        if anneaux:
            sortie.append(anneaux)
    if not sortie:
        continue
    if principal_approche:
        approchees += 1
    p = x.get('properties', {}) or {}
    ha = p.get('SHAPE.STArea()')
    pr = {'id': 'mdir-%s' % (p.get('naturvernId') or p.get('OBJECTID')),
          'country': 'no', 'source': 'MDIR', 'updated': AUJ,
          'name': p.get('navn') or p.get('offisieltNavn') or 'zone protégée',
          'type': 'zone_protegee',
          'nom_officiel': p.get('offisieltNavn') or None,
          'categorie': p.get('verneform') or None,
          'categorie_groupee': p.get('verneformAggregert') or None,
          'categorie_uicn': p.get('iucn') or None,
          'gestionnaire': p.get('forvaltningsmyndighet') or None,
          'commune': p.get('kommune') or None,
          'lien': p.get('faktaark') or None,
          'surface_ha': round(ha / 10000.0) if isinstance(ha, (int, float)) else None,
          'contour_approche': True if principal_approche else None}
    feats.append({'type': 'Feature',
                  'geometry': {'type': 'MultiPolygon', 'coordinates': sortie},
                  'properties': {k: v for k, v in pr.items() if v is not None}})

cible = os.path.join(IN, 'zones-protegees-no.geojson')
json.dump({'type': 'FeatureCollection', 'features': feats},
          io.open(cible, 'w', encoding='utf-8'), ensure_ascii=False)

note('')
note('=== simplification ===')
note('  points : %d -> %d (%.1f %% conservés)' % (pts_a, pts_b, 100.0 * pts_b / max(1, pts_a)))
note('  entités : %d | contour principal approché : %d' % (len(feats), approchees))
note('  fichier : %d Ko' % (os.path.getsize(cible) // 1024))
note('  identifiants uniques : %s'
     % ('oui' if len({f['properties']['id'] for f in feats}) == len(feats) else 'NON'))

note('')
note('=== répartition ===')
note('  par forme de protection : %s' % dict(collections.Counter(
    f['properties'].get('categorie_groupee') for f in feats).most_common(8)))
note('  par catégorie UICN : %s' % dict(collections.Counter(
    f['properties'].get('categorie_uicn') for f in feats).most_common(8)))
parcs = [f for f in feats if 'nasjonalpark' in str(f['properties'].get('categorie', '')).lower()]
note('  parcs nationaux : %d' % len(parcs))
gr = sorted((f['properties'] for f in feats if f['properties'].get('surface_ha')),
            key=lambda p: -p['surface_ha'])[:8]
note('  les plus vastes :')
for p in gr:
    note('    %-42s %9d ha  %s' % (p['name'][:42], p['surface_ha'], p.get('categorie') or ''))
note('')
note('  échantillon : %s' % json.dumps(feats[0]['properties'], ensure_ascii=False)[:340])

io.open(os.path.join(IN, 'RAPPORT40.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT40.txt"
echo "=========================================="
echo "À me transmettre : _parcs/RAPPORT40.txt"
