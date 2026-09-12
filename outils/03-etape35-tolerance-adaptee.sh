#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 35 : TOLÉRANCE ADAPTÉE ET COUCHE NORVÉGIENNE
# =============================================================================
#
# 1. FINLANDE — 96 entités sur 1 091 ont été perdues : une tolérance unique de
#    90 m efface les petites zones, qui n'ont plus quatre points une fois
#    simplifiées. La tolérance devient PROPORTIONNELLE À LA TAILLE de la zone,
#    estimée par l'étendue de son contour : une réserve de 90 ha ne se traite
#    pas comme un parc de 285 000 ha.
#      étendue > 0,5°   (grand parc)      tolérance 0,003°  ~270 m
#      étendue > 0,1°                     tolérance 0,001°  ~90 m
#      étendue > 0,02°                    tolérance 0,0003° ~27 m
#      au-delà          (petite réserve)  tolérance 0,0001° ~9 m
#    Aucune zone ne doit plus disparaître ; le rapport le vérifie.
#
# 2. NORVÈGE — la couche 3 « naturvern_grense » répond, là où les couches 0 et 1
#    sont en panne durable. On l'examine : nombre d'entités, type de géométrie,
#    champs. Si ce sont des lignes de limite exploitables, on les prend.
#
# UTILISATION — depuis le dossier contenant _parcs/
#   bash 03-etape35-tolerance-adaptee.sh
# =============================================================================

set -u
OUT="_parcs"; mkdir -p "$OUT"
MDIR="https://kart.miljodirektoratet.no/arcgis/rest/services/vern/MapServer"

# -----------------------------------------------------------------------------
# Norvège : combien d'entités, et de quelle nature ?
# -----------------------------------------------------------------------------
echo "== Norvège : couche 3, naturvern_grense =="
curl -sS -m 60 -G "$MDIR/3/query" \
  --data-urlencode "where=1=1" --data-urlencode "returnCountOnly=true" \
  --data-urlencode "f=json" -o "$OUT/no3-compte.json"
python3 -c "
import json,io
try:
    d=json.load(io.open('$OUT/no3-compte.json',encoding='utf-8'))
    print('   entités au total : %s' % d.get('count', d))
except Exception as e:
    print('   comptage illisible : %s' % str(e)[:80])"

python3 -c "
import json,io,collections
try:
    d=json.load(io.open('$OUT/g-vern-3.txt',encoding='utf-8'))
except Exception as e:
    print('   échantillon illisible'); raise SystemExit
f=d.get('features',[])
print('   échantillon : %d entité(s)' % len(f))
if f:
    print('   géométries : %s' % dict(collections.Counter(x.get('geometry',{}).get('type') for x in f)))
    p=f[0].get('properties',{})
    print('   champs : %s' % ', '.join(sorted(p))[:220])
    for k in sorted(p)[:10]:
        print('     %-26s %s' % (k, str(p[k])[:60]))
    c=f[0].get('geometry',{}).get('coordinates')
    def prof(x):
        n=0
        while isinstance(x,list): x=x[0]; n+=1
        return n
    print('   profondeur des coordonnées : %d' % prof(c))"

# -----------------------------------------------------------------------------
# Finlande : simplification proportionnelle
# -----------------------------------------------------------------------------
python3 - <<'PY' > "$OUT/RAPPORT35.txt" 2>&1
import json, io, os, math, collections, datetime

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
    """Une réserve de 90 ha ne se traite pas comme un parc de 285 000 ha."""
    if e > 0.5:   return 0.003
    if e > 0.1:   return 0.001
    if e > 0.02:  return 0.0003
    return 0.0001

def anneau(ring, tol):
    p = [[round(float(c[0]), PRECISION), round(float(c[1]), PRECISION)] for c in ring]
    s = douglas(p, tol)
    if len(s) < 4:
        # plutôt que de perdre la zone, on garde son enveloppe rectangulaire
        xs = [c[0] for c in p]; ys = [c[1] for c in p]
        s = [[min(xs), min(ys)], [max(xs), min(ys)], [max(xs), max(ys)],
             [min(xs), max(ys)], [min(xs), min(ys)]]
        return s, True
    if s[0] != s[-1]:
        s.append(s[0])
    return s, False

c = os.path.join(IN, 'fi-suojelu.geojson')
d = json.load(io.open(c, encoding='utf-8'))
fs = d.get('features', [])
avant = os.path.getsize(c)
note('=== Finlande — simplification proportionnelle ===')
note('  entités d\'origine : %d | %d Ko' % (len(fs), avant // 1024))

pts_a = pts_b = 0
sorties, enveloppes, perdues = [], 0, 0
tols = collections.Counter()
for f in fs:
    g = f.get('geometry') or {}
    if g.get('type') != 'MultiPolygon':
        continue
    polys = []
    for poly in g['coordinates']:
        anneaux = []
        for i, ring in enumerate(poly):
            pts_a += len(ring)
            tol = tolerance_pour(etendue(ring))
            tols['%.4f' % tol] += 1
            a, env = anneau(ring, tol)
            if env:
                enveloppes += 1
            anneaux.append(a); pts_b += len(a)
        if anneaux:
            polys.append(anneaux)
    if not polys:
        perdues += 1; continue
    p = f.get('properties', {}) or {}
    pr = {'id': 'syke-%s' % (p.get('lsaluetunnus') or p.get('objectid')),
          'country': 'fi', 'source': 'SYKE', 'updated': AUJ,
          'name': p.get('nimi') or p.get('paatnimi') or 'zone protégée',
          'type': 'zone_protegee',
          'nom_suedois': p.get('nimiruotsi') or None,
          'categorie_uicn': p.get('iucnkategoria') or None,
          'categorie': p.get('iucnluokkanimi') or None,
          'region': p.get('ely') or None,
          'lien': p.get('paaturl') or None,
          'surface_ha': round(p['shape_area'] / 10000.0) if isinstance(p.get('shape_area'), (int, float)) else None}
    sorties.append({'type': 'Feature',
                    'geometry': {'type': 'MultiPolygon', 'coordinates': polys},
                    'properties': {k: v for k, v in pr.items() if v is not None}})

cible = os.path.join(IN, 'zones-protegees-fi.geojson')
json.dump({'type': 'FeatureCollection', 'features': sorties},
          io.open(cible, 'w', encoding='utf-8'), ensure_ascii=False)
apres = os.path.getsize(cible)
note('  points : %d -> %d (%.1f %% conservés)' % (pts_a, pts_b, 100.0 * pts_b / max(1, pts_a)))
note('  entités conservées : %d | perdues : %d | contours remplacés par leur enveloppe : %d'
     % (len(sorties), perdues, enveloppes))
note('  tolérances appliquées : %s' % dict(tols))
note('  fichier : %d Ko -> %d Ko (%.1f %%)' % (avant // 1024, apres // 1024, 100.0 * apres / avant))

note('')
note('  parcs nationaux (kansallispuisto) : %d'
     % sum(1 for f in sorties if 'kansallispuisto' in f['properties']['name'].lower()))
note('  par catégorie UICN : %s' % dict(collections.Counter(
    f['properties'].get('categorie_uicn') for f in sorties).most_common(8)))
pet = sorted((f['properties'] for f in sorties if f['properties'].get('surface_ha')),
             key=lambda p: p['surface_ha'])[:5]
note('  les plus petites conservées :')
for p in pet:
    note('    %-44s %6d ha' % (p['name'][:44], p['surface_ha']))

io.open(os.path.join(IN, 'RAPPORT35.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT35.txt"
echo "=========================================="
echo "Me transmettre la sortie complète."
