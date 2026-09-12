#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 36 : CONTOURS APPROCHÉS ET PUBLICATION
# =============================================================================
#
# 631 contours sur 9 910 ont été remplacés par leur enveloppe rectangulaire :
# ce sont de très petites zones dont le tracé disparaît sous la simplification.
# Elles restent au bon endroit, mais leur forme est un rectangle.
#
# L'UTILISATEUR DOIT LE SAVOIR. Une propriété « contour_approche » est posée sur
# les entités concernées, comme « centroide » l'est sur les zones suédoises
# tirées d'OpenStreetMap. Une donnée qui ment sur sa propre nature est pire
# qu'une donnée absente.
#
# Ce script relit le fichier d'origine et repose la simplification, en notant
# cette fois quelles entités sont approchées.
#
# UTILISATION — depuis le dossier contenant _parcs/
#   bash 03-etape36-contours-approches.sh
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

d = json.load(io.open(os.path.join(IN, 'fi-suojelu.geojson'), encoding='utf-8'))
fs = d.get('features', [])
sorties = []
approchees = 0
for f in fs:
    g = f.get('geometry') or {}
    if g.get('type') != 'MultiPolygon':
        continue
    polys, approche = [], False
    for poly in g['coordinates']:
        anneaux = []
        for ring in poly:
            a, env = anneau(ring, tolerance_pour(etendue(ring)))
            if env:
                approche = True
            anneaux.append(a)
        if anneaux:
            polys.append(anneaux)
    if not polys:
        continue
    if approche:
        approchees += 1
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
          'contour_approche': True if approche else None}
    sorties.append({'type': 'Feature',
                    'geometry': {'type': 'MultiPolygon', 'coordinates': polys},
                    'properties': {k: v for k, v in pr.items() if v is not None}})

cible = os.path.join(IN, 'zones-protegees-fi.geojson')
json.dump({'type': 'FeatureCollection', 'features': sorties},
          io.open(cible, 'w', encoding='utf-8'), ensure_ascii=False)

note('=== zones protégées finlandaises ===')
note('  entités : %d | %d Ko' % (len(sorties), os.path.getsize(cible) // 1024))
note('  au contour approché : %d (%.0f %%)' % (approchees, 100.0 * approchees / max(1, len(sorties))))
note('  identifiants uniques : %s' % ('oui' if len({f['properties']['id'] for f in sorties}) == len(sorties) else 'NON'))
note('  parcs nationaux : %d' % sum(1 for f in sorties if 'kansallispuisto' in f['properties']['name'].lower()))

# les entités approchées sont-elles bien les plus petites ?
app = [f['properties']['surface_ha'] for f in sorties
       if f['properties'].get('contour_approche') and f['properties'].get('surface_ha')]
ok = [f['properties']['surface_ha'] for f in sorties
      if not f['properties'].get('contour_approche') and f['properties'].get('surface_ha')]
if app and ok:
    note('  surface médiane — approchées : %d ha | exactes : %d ha'
         % (sorted(app)[len(app) // 2], sorted(ok)[len(ok) // 2]))
    note('  la plus grande approchée : %d ha' % max(app))

hors = 0
for f in sorties:
    for poly in f['geometry']['coordinates']:
        for ring in poly:
            for c in ring:
                if not (18 <= c[0] <= 32 and 59 <= c[1] <= 71):
                    hors += 1
                    break
            break
        break
note('  entités hors emprise finlandaise : %d' % hors)
note('')
note('  échantillon exact   : %s' % json.dumps(
    next(f['properties'] for f in sorties if not f['properties'].get('contour_approche')), ensure_ascii=False)[:280])
note('  échantillon approché : %s' % json.dumps(
    next(f['properties'] for f in sorties if f['properties'].get('contour_approche')), ensure_ascii=False)[:280])

io.open(os.path.join(IN, 'RAPPORT36.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _parcs/RAPPORT36.txt
echo "=========================================="
echo
echo "Si le rapport est propre, publier :"
echo "  cp _parcs/zones-protegees-fi.geojson ~/Documents/Projets/Periple-Nordique-Data/sources/"
