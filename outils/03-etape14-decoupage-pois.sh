#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 14 : DÉCOUPAGE DES POINTS D'INTÉRÊT ET REPRISE DES PARCS
# =============================================================================
#
# DEUX PROBLÈMES CONSTATÉS AU RAPPORT 13
#
# 1. 44 042 entités et 12,9 Mo dans un seul fichier : la plus grosse couche du
#    module, et indivisible à l'affichage. Or ses catégories n'ont pas le même
#    usage — on cherche un abri quand on cherche un abri, pas quand on cherche
#    un musée. Le fichier est découpé en trois, chacun activable séparément :
#      pois.geojson             nature, patrimoine, panorama, faune
#      refuges.geojson          abris, cabanes, huttes
#      zones-protegees.geojson  réserves naturelles nommées
#
# 2. Les contours de parcs nationaux sont manqués : 32 parcs seulement, et une
#    répartition par pays manifestement fausse — 24 en Finlande, 2 en Norvège,
#    alors que la Norvège en compte plusieurs dizaines. Deux causes : la requête
#    unique sur trois zones, et la déduction du pays par la position. On reprend
#    pays par pays, comme les autres extractions, ce qui donne le pays par
#    construction.
#
# UTILISATION — depuis le dossier contenant _pois/
#   bash 03-etape14-decoupage-pois.sh
# =============================================================================

set -u
IN="_pois"
API="https://overpass-api.de/api/interpreter"

# -----------------------------------------------------------------------------
# Reprise des contours de parcs, une requête par pays
# -----------------------------------------------------------------------------
for ISO in NO SE FI; do
  F="$IN/parcs-$ISO.json"
  if [ -s "$F" ]; then
    echo "== parcs $ISO : déjà téléchargé ($(du -h "$F" | cut -f1)) =="
    continue
  fi
  echo "== parcs $ISO =="
  Q="[out:json][timeout:300];
area[\"ISO3166-1\"=\"$ISO\"][admin_level=2]->.p;
(
  way[\"boundary\"=\"national_park\"](area.p);
  relation[\"boundary\"=\"national_park\"](area.p);
);
out geom tags;"
  curl -sS -X POST -d "data=$Q" "$API" -o "$F"
  echo "   $(python3 -c "
import json,io
try:
    print(len(json.load(io.open('$F',encoding='utf-8')).get('elements',[])), 'objets')
except Exception as e:
    print('erreur :', str(e)[:60])") — $(du -h "$F" | cut -f1)"
  sleep 20
done

python3 - <<'PY'
import json, io, os, collections, datetime

IN = '_pois'; AUJ = datetime.date.today().isoformat()
rapport = []
def note(s):
    print(s); rapport.append(s)

# --------------------------------------------------------------- découpage
GROUPES = {
    'pois.geojson':            ('nature', 'patrimoine', 'panorama', 'faune'),
    'refuges.geojson':         ('refuge',),
    'zones-protegees.geojson': ('protege',),
}

src = os.path.join(IN, 'pois.geojson')
d = json.load(io.open(src, encoding='utf-8'))
fs = d['features']
note('=== découpage de %d entités ===' % len(fs))
for nom, cats in GROUPES.items():
    part = [f for f in fs if f['properties']['type'] in cats]
    json.dump({'type': 'FeatureCollection', 'features': part},
              io.open(os.path.join(IN, nom), 'w', encoding='utf-8'), ensure_ascii=False)
    taille = os.path.getsize(os.path.join(IN, nom)) // 1024
    note('  %-24s %6d entités, %5d Ko   (%s)' % (nom, len(part), taille, ', '.join(cats)))
    note('       par pays : %s' % dict(collections.Counter(f['properties']['country'] for f in part)))

# --------------------------------------------------------------- parcs
note('')
note('=== parcs nationaux, contours ===')
parcs, vus = [], set()
for iso, code in (('NO', 'no'), ('SE', 'se'), ('FI', 'fi')):
    c = os.path.join(IN, 'parcs-%s.json' % iso)
    if not os.path.exists(c):
        note('  %s : fichier absent' % iso); continue
    try:
        els = json.load(io.open(c, encoding='utf-8')).get('elements', [])
    except Exception as e:
        note('  %s : illisible — %s' % (iso, str(e)[:70])); continue
    n0 = len(parcs)
    for e in els:
        t = e.get('tags', {}) or {}
        nom = t.get('name')
        if not nom:
            continue
        cle = (code, nom)
        if cle in vus:
            continue
        anneaux = []
        if e.get('geometry'):
            anneaux = [[[round(p['lon'], 5), round(p['lat'], 5)] for p in e['geometry']]]
        for mb in (e.get('members') or []):
            if mb.get('role') in ('outer', '') and mb.get('geometry'):
                anneaux.append([[round(p['lon'], 5), round(p['lat'], 5)] for p in mb['geometry']])
        anneaux = [a for a in anneaux if len(a) > 3]
        if not anneaux:
            continue
        vus.add(cle)
        parcs.append({'type': 'Feature',
                      'geometry': {'type': 'MultiLineString', 'coordinates': anneaux},
                      'properties': {'id': 'parc-%s-%s' % (code, e.get('id')), 'country': code,
                                     'name': nom, 'type': 'parc_national',
                                     'source': 'OSM', 'updated': AUJ,
                                     'site_web': t.get('website') or None,
                                     'operateur': t.get('operator') or None}})
    note('  %s : %d objets lus -> %d parcs avec contour' % (iso, len(els), len(parcs) - n0))

json.dump({'type': 'FeatureCollection', 'features': parcs},
          io.open(os.path.join(IN, 'parcs-nationaux.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
note('  -> parcs-nationaux.geojson : %d parcs, %d Ko'
     % (len(parcs), os.path.getsize(os.path.join(IN, 'parcs-nationaux.geojson')) // 1024))
note('  par pays : %s' % dict(collections.Counter(f['properties']['country'] for f in parcs)))
pts = sum(sum(len(a) for a in f['geometry']['coordinates']) for f in parcs)
note('  points de contour : %d, soit %d par parc en moyenne' % (pts, pts // max(1, len(parcs))))

note('')
note('=== quelques parcs, pour contrôle ===')
for f in sorted(parcs, key=lambda x: x['properties']['name'])[:10]:
    p = f['properties']
    n = sum(len(a) for a in f['geometry']['coordinates'])
    note('  %-38s %s  %4d points' % (p['name'][:38], p['country'], n))

io.open(os.path.join(IN, 'RAPPORT14.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _pois/RAPPORT14.txt
echo "=========================================="
echo "À me transmettre : _pois/RAPPORT14.txt"
