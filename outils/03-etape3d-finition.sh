#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 3d : FINITION DES TROIS COUCHES
# =============================================================================
#
# 1. NOMS — 1078 entités des cols n'ont pas de nom : la NVDB ne renseigne
#    « Navn » que sur les cols nommés. Un tronçon sans nom mais avec un numéro
#    de route et des dates reste utile ; il lui faut juste une étiquette
#    lisible. On la compose à partir de ce qui existe, sans rien inventer.
#
# 2. TAILLE FI — 15 296 tronçons pour 6 Mo. La géométrie exacte d'un tronçon
#    à tonnage limité importe moins que son existence : on simplifie plus
#    fort sur cette couche seule.
#
# 3. Contrôle final avant dépôt.
#
# UTILISATION — depuis le dossier contenant _out/
#   bash 03-etape3d-finition.sh
# =============================================================================

set -u
OUT="_out"

python3 - <<'PY'
import json, io, os, math

OUT = '_out'; rapport = []
def note(s):
    print(s); rapport.append(s)

# ---------------------------------------------------------------- outils
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

def simplifier(g, tol):
    t = g.get('type')
    if t == 'LineString':
        s = douglas(g['coordinates'], tol)
        return {'type': 'LineString', 'coordinates': s} if len(s) > 1 else None
    if t == 'MultiLineString':
        ls = [douglas(l, tol) for l in g['coordinates']]
        ls = [l for l in ls if len(l) > 1]
        return {'type': 'MultiLineString', 'coordinates': ls} if ls else None
    return g

def pts(g):
    c = g['coordinates']
    if g['type'] == 'Point':
        return 1
    if g['type'] == 'LineString':
        return len(c)
    return sum(len(l) for l in c)

# ---------------------------------------------------------------- 1. noms
note('=== noms des cols ===')
c = os.path.join(OUT, 'cols-fermetures.geojson')
d = json.load(io.open(c, encoding='utf-8'))
compose = 0
for f in d['features']:
    p = f['properties']
    if p.get('name') and p['name'] != 'sans nom':
        continue
    morceaux = []
    if p.get('route'):
        # F5627 -> Fv5627, E6 -> E6, R15 -> Rv15 : notation norvégienne usuelle
        r = p['route']
        morceaux.append({'F': 'Fv', 'R': 'Rv', 'K': 'Kv', 'P': 'Pv'}.get(r[0], '') + r[1:] if r[0] in 'FRKP' else r)
    if p.get('de') or p.get('a'):
        morceaux.append(' - '.join(x for x in (p.get('de'), p.get('a')) if x))
    elif p.get('ferme_du') and p.get('ferme_au'):
        morceaux.append('fermé %s → %s' % (p['ferme_du'], p['ferme_au']))
    if p.get('kommune') and len(morceaux) < 2:
        morceaux.append('kommune %s' % p['kommune'])
    p['name'] = ' · '.join(morceaux) if morceaux else 'tronçon %s' % p['id'].split('-')[-1]
    p['nom_compose'] = True
    compose += 1
note('  noms composés : %d' % compose)
json.dump(d, io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)

# ---------------------------------------------------------------- 2. FI plus léger
note('')
note('=== allègement de la couche finlandaise ===')
c = os.path.join(OUT, 'restrictions-degel.geojson')
d = json.load(io.open(c, encoding='utf-8'))
avant_o, avant_p = os.path.getsize(c), sum(pts(f['geometry']) for f in d['features'])
gardees = []
for f in d['features']:
    g = simplifier(f['geometry'], 0.0005)   # ~27 m, suffisant pour situer un tronçon
    if g:
        f['geometry'] = g
        gardees.append(f)
d['features'] = gardees
json.dump(d, io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)
note('  %d entités | %d -> %d points | %d Ko -> %d Ko'
     % (len(gardees), avant_p, sum(pts(f['geometry']) for f in gardees),
        avant_o // 1024, os.path.getsize(c) // 1024))

# ---------------------------------------------------------------- 3. contrôle final
note('')
note('=== contrôle final ===')
for nom in ('cols-fermetures.geojson', 'ferries.geojson', 'restrictions-degel.geojson'):
    c = os.path.join(OUT, nom)
    d = json.load(io.open(c, encoding='utf-8'))
    fs = d['features']
    manquants, hors, types = 0, 0, {}
    obligatoires = ('id', 'country', 'name', 'type', 'source', 'updated')
    ids = set()
    for f in fs:
        p = f['properties']
        types[p.get('type')] = types.get(p.get('type'), 0) + 1
        if any(not p.get(k) for k in obligatoires):
            manquants += 1
        ids.add(p.get('id'))
        cc = f['geometry']['coordinates']
        while isinstance(cc[0], list):
            cc = cc[0]
        if not (2 <= cc[0] <= 34 and 53 <= cc[1] <= 73):
            hors += 1
    note('  %-26s %5d entités | %5d id uniques | schéma incomplet %d | hors emprise %d | %4d Ko'
         % (nom, len(fs), len(ids), manquants, hors, os.path.getsize(c) // 1024))
    note('      types : %s' % types)

note('')
note('=== échantillons de noms composés ===')
d = json.load(io.open(os.path.join(OUT, 'cols-fermetures.geojson'), encoding='utf-8'))
ex = [f['properties'] for f in d['features'] if f['properties'].get('nom_compose')][:4]
for p in ex:
    note('  %-44s %s → %s' % (p['name'], p.get('ferme_du'), p.get('ferme_au')))

io.open(os.path.join(OUT, 'RAPPORT-3d.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT-3d.txt"
echo "=========================================="
ls -la "$OUT"/*.geojson
