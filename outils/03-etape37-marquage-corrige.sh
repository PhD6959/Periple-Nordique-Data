#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 37 : MARQUAGE CORRIGÉ DES CONTOURS APPROCHÉS
# =============================================================================
#
# CE QUE LE CONTRÔLE DE L'ÉTAPE 36 A RÉVÉLÉ
#   Les entités marquées « contour approché » n'étaient pas les plus petites :
#   surface médiane de 1 318 ha contre 84 ha pour les autres, et Lemmenjoki,
#   285 791 ha, en faisait partie.
#
#   La cause : une grande zone est un MultiPolygon fait de dizaines d'îlots. Le
#   contour principal se simplifie très bien ; ce sont les petits satellites —
#   un îlot, une parcelle isolée — qui tombent sous quatre points. Marquer
#   l'entité entière dès qu'UN anneau est approché disait donc le faux dans les
#   deux sens.
#
# CORRECTION
#   « contour_approche » ne vaut vrai que si le CONTOUR PRINCIPAL — premier
#   anneau du premier polygone, celui qui porte l'essentiel de la surface — est
#   approché. Une seconde propriété, « anneaux_approches », donne le décompte
#   pour qui veut le détail : « 3 sur 47 » se lit tout autrement que « 1 sur 1 ».
#
# UTILISATION — depuis le dossier contenant _parcs/
#   bash 03-etape37-marquage-corrige.sh
# =============================================================================

set -u
python3 - <<'PY'
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
    """Aire signée, pour repérer le polygone principal d'un MultiPolygon."""
    a = 0.0
    for i in range(len(ring) - 1):
        a += ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1]
    return abs(a) / 2.0

d = json.load(io.open(os.path.join(IN, 'fi-suojelu.geojson'), encoding='utf-8'))
fs = d.get('features', [])
sorties = []
for f in fs:
    g = f.get('geometry') or {}
    if g.get('type') != 'MultiPolygon':
        continue
    # le polygone principal est le plus étendu, pas forcément le premier
    ordre = sorted(range(len(g['coordinates'])),
                   key=lambda i: -aire(g['coordinates'][i][0]) if g['coordinates'][i] else 0)
    polys, approches, total, principal_approche = [], 0, 0, False
    for rang, i in enumerate(ordre):
        poly = g['coordinates'][i]
        anneaux = []
        for j, ring in enumerate(poly):
            total += 1
            a, env = anneau(ring, tolerance_pour(etendue(ring)))
            if env:
                approches += 1
                if rang == 0 and j == 0:
                    principal_approche = True
            anneaux.append(a)
        if anneaux:
            polys.append(anneaux)
    if not polys:
        continue
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
          'surface_ha': round(p['shape_area'] / 10000.0) if isinstance(p.get('shape_area'), (int, float)) else None,
          'contour_approche': True if principal_approche else None,
          'anneaux_approches': ('%d sur %d' % (approches, total)) if approches else None}
    sorties.append({'type': 'Feature',
                    'geometry': {'type': 'MultiPolygon', 'coordinates': polys},
                    'properties': {k: v for k, v in pr.items() if v is not None}})

cible = os.path.join(IN, 'zones-protegees-fi.geojson')
json.dump({'type': 'FeatureCollection', 'features': sorties},
          io.open(cible, 'w', encoding='utf-8'), ensure_ascii=False)

note('=== zones protégées finlandaises ===')
note('  entités : %d | %d Ko' % (len(sorties), os.path.getsize(cible) // 1024))
note('  identifiants uniques : %s'
     % ('oui' if len({f['properties']['id'] for f in sorties}) == len(sorties) else 'NON'))
note('  parcs nationaux : %d' % sum(1 for f in sorties if 'kansallispuisto' in f['properties']['name'].lower()))

app = [f['properties'] for f in sorties if f['properties'].get('contour_approche')]
part = [f['properties'] for f in sorties if f['properties'].get('anneaux_approches')]
note('')
note('  CONTOUR PRINCIPAL approché : %d (%.1f %%)' % (len(app), 100.0 * len(app) / max(1, len(sorties))))
note('  au moins un anneau approché : %d' % len(part))
if app:
    s = [p['surface_ha'] for p in app if p.get('surface_ha')]
    note('  surfaces des contours principaux approchés : médiane %d ha, maximum %d ha'
         % (sorted(s)[len(s) // 2], max(s)))
ok = [f['properties']['surface_ha'] for f in sorties
      if not f['properties'].get('contour_approche') and f['properties'].get('surface_ha')]
if ok:
    note('  surfaces des contours exacts : médiane %d ha' % sorted(ok)[len(ok) // 2])

note('')
note('  contrôle sur Lemmenjoki :')
for f in sorties:
    if 'Lemmenjo' in f['properties']['name']:
        note('    %s' % json.dumps(f['properties'], ensure_ascii=False)[:300])
note('')
note('  les plus grandes zones dont le contour principal est approché :')
for p in sorted(app, key=lambda x: -(x.get('surface_ha') or 0))[:5]:
    note('    %-44s %7d ha  %s' % (p['name'][:44], p.get('surface_ha') or 0, p.get('anneaux_approches')))

io.open(os.path.join(IN, 'RAPPORT37.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _parcs/RAPPORT37.txt
echo "=========================================="
echo
echo "Si le rapport est propre, publier :"
echo "  cp _parcs/zones-protegees-fi.geojson ~/Documents/Projets/Periple-Nordique-Data/sources/"
