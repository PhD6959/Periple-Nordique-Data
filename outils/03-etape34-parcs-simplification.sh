#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 34 : ZONES PROTÉGÉES — SIMPLIFICATION ET REPLI NORVÉGIEN
# =============================================================================
#
# 1. FINLANDE : 1 091 polygones pour 104 Mo. Les contours sont découpés au
#    mètre près, ce qui n'a aucun intérêt pour situer un parc. On simplifie à
#    100 m de tolérance et on arrondit à quatre décimales — environ 11 m. Une
#    zone protégée reste parfaitement reconnaissable ; le fichier doit fondre.
#
#    ON GARDE LES CONTOURS, pas les centroïdes : c'est tout l'intérêt de cette
#    couche par rapport aux 11 371 centroïdes suédois d'OpenStreetMap. Une zone
#    se lit à ses limites.
#
# 2. NORVÈGE : le service de Miljødirektoratet répond « Could not access any
#    server machines » sur les deux couches qui portent les zones, et fonctionne
#    sur les autres. Panne partielle et persistante, pas une erreur de requête.
#    On tente Geonorge, qui redistribue les données de Naturbase, en éprouvant
#    plusieurs adresses plausibles.
#
# UTILISATION — depuis le dossier contenant _parcs/
#   bash 03-etape34-parcs-simplification.sh
# =============================================================================

set -u
OUT="_parcs"; mkdir -p "$OUT"

# -----------------------------------------------------------------------------
# Repli norvégien : quelles adresses répondent chez Geonorge ?
# -----------------------------------------------------------------------------
echo "== Norvège : recherche d'un service de repli =="
sonder () {
  printf '  %-42s ' "$1"
  local CODE
  CODE=$(curl -sS -m 40 -o "$OUT/g-$1.txt" -w '%{http_code}' "$2" 2>/dev/null || echo '000')
  if [ "$CODE" != "200" ]; then echo "http $CODE"; rm -f "$OUT/g-$1.txt"; return; fi
  python3 - "$OUT/g-$1.txt" <<'PY'
import sys, re, io
s = io.open(sys.argv[1], encoding='utf-8', errors='replace').read()
if 'ServiceException' in s or 'Could not access' in s or 'Application Error' in s:
    print('service indisponible'); raise SystemExit
if s.lstrip().startswith('{'):
    print('JSON, %d octets' % len(s)); raise SystemExit
noms = re.findall(r'<(?:wfs:)?Name>([^<]+)</(?:wfs:)?Name>', s)
if not noms:
    print('pas de couches, %d octets' % len(s)); raise SystemExit
inter = [n for n in noms if re.search(r'vern|park|natur', n, re.I)]
print('%d couche(s), dont %d en rapport : %s' % (len(noms), len(inter), ', '.join(inter[:5])))
PY
}
sonder naturvernomrader "https://wfs.geonorge.no/skwms1/wfs.naturvernomrader?service=WFS&request=GetCapabilities&version=2.0.0"
sonder inspire-ps       "https://wfs.geonorge.no/skwms1/wfs.inspire-ps?service=WFS&request=GetCapabilities&version=2.0.0"
sonder naturbase        "https://kart.miljodirektoratet.no/arcgis/rest/services/naturvernomrade/MapServer?f=json"
sonder vern-3           "https://kart.miljodirektoratet.no/arcgis/rest/services/vern/MapServer/3/query?where=1%3D1&outFields=*&returnGeometry=true&outSR=4326&f=geojson&resultRecordCount=200"

# -----------------------------------------------------------------------------
# Finlande : simplification
# -----------------------------------------------------------------------------
python3 - <<'PY' > "$OUT/RAPPORT34.txt" 2>&1
import json, io, os, math, collections, datetime

IN = '_parcs'; AUJ = datetime.date.today().isoformat()
# Tolérance éprouvée sur un contour bruité de 3 000 sommets, cas le plus
# défavorable : 0,001° conserve 57 % des points, 0,003° en conserve 28 % pour
# un écart maximal de 133 m. Les contours réels suivent le terrain et se
# simplifient mieux. On retient 0,002°, et le rapport dira ce que ça donne.
TOLERANCE = 0.002
PRECISION = 4          # ~11 m, largement suffisant pour une limite de zone
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

def anneau(pts):
    """Un contour reste fermé : premier et dernier point identiques, et au
    moins quatre points, faute de quoi ce n'est plus une surface."""
    p = [[round(float(c[0]), PRECISION), round(float(c[1]), PRECISION)] for c in pts]
    s = douglas(p, TOLERANCE)
    if len(s) < 4:
        return None
    if s[0] != s[-1]:
        s.append(s[0])
    return s

c = os.path.join(IN, 'fi-suojelu.geojson')
note('=== Finlande — simplification ===')
if not os.path.exists(c):
    note('  fichier absent'); raise SystemExit
avant = os.path.getsize(c)
d = json.load(io.open(c, encoding='utf-8'))
fs = d.get('features', [])
note('  entités : %d | fichier d\'origine : %d Ko' % (len(fs), avant // 1024))

pts_avant = pts_apres = 0
sorties, perdues = [], 0
for f in fs:
    g = f.get('geometry') or {}
    if g.get('type') != 'MultiPolygon':
        continue
    polys = []
    for poly in g['coordinates']:
        anneaux = []
        for i, ring in enumerate(poly):
            pts_avant += len(ring)
            a = anneau(ring)
            if a:
                anneaux.append(a); pts_apres += len(a)
            elif i == 0:
                anneaux = []; break      # contour extérieur perdu : polygone abandonné
        if anneaux:
            polys.append(anneaux)
    if not polys:
        perdues += 1; continue
    p = f.get('properties', {}) or {}
    nom = p.get('nimi') or p.get('paatnimi') or 'zone protégée'
    sorties.append({'type': 'Feature',
                    'geometry': {'type': 'MultiPolygon', 'coordinates': polys},
                    'properties': {
                        'id': 'syke-%s' % (p.get('lsaluetunnus') or p.get('objectid')),
                        'country': 'fi', 'source': 'SYKE', 'updated': AUJ,
                        'name': nom, 'type': 'zone_protegee',
                        'nom_suedois': p.get('nimiruotsi') or None,
                        'categorie_uicn': p.get('iucnkategoria') or None,
                        'categorie': p.get('iucnluokkanimi') or None,
                        'region': p.get('ely') or None,
                        'lien': p.get('paaturl') or None,
                        'surface_ha': round(p['shape_area'] / 10000.0) if isinstance(p.get('shape_area'), (int, float)) else None}})

for f in sorties:
    f['properties'] = {k: v for k, v in f['properties'].items() if v is not None}

cible = os.path.join(IN, 'zones-protegees-fi.geojson')
json.dump({'type': 'FeatureCollection', 'features': sorties},
          io.open(cible, 'w', encoding='utf-8'), ensure_ascii=False)
apres = os.path.getsize(cible)
note('  points : %d -> %d (%.1f %% conservés)' % (pts_avant, pts_apres, 100.0 * pts_apres / max(1, pts_avant)))
note('  entités conservées : %d | perdues faute de contour : %d' % (len(sorties), perdues))
note('  fichier : %d Ko -> %d Ko  (%.0f %% du volume d\'origine)'
     % (avant // 1024, apres // 1024, 100.0 * apres / avant))
if apres > 12 * 1024 * 1024:
    note('  ENCORE TROP LOURD : desserrer la tolérance ou ne garder que les zones les plus vastes.')

note('')
note('  par catégorie UICN : %s' % dict(collections.Counter(
    f['properties'].get('categorie_uicn') for f in sorties).most_common(8)))
gr = sorted((f['properties'] for f in sorties if f['properties'].get('surface_ha')),
            key=lambda p: -p['surface_ha'])[:8]
note('  les plus vastes :')
for p in gr:
    note('    %-42s %8d ha  %s' % (p['name'][:42], p['surface_ha'], p.get('categorie_uicn') or ''))
note('')
note('  échantillon : %s' % json.dumps(sorties[0]['properties'], ensure_ascii=False)[:300])

io.open(os.path.join(IN, 'RAPPORT34.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT34.txt"
echo "=========================================="
echo "Me transmettre la sortie complète, repli norvégien compris."
