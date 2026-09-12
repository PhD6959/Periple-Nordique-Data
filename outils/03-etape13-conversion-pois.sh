#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 13 : CONVERSION ET FILTRAGE DES POINTS D'INTÉRÊT — version 1.1
# =============================================================================
#
# 79 610 éléments extraits : trop pour une couche utilisable. Le filtre ci-dessous
# est un ARBITRAGE, discutable et modifiable — il est écrit en clair dans la
# table REGLES pour que tu puisses le corriger sans toucher au reste.
#
# PRINCIPE : ce qui n'a pas de nom n'a d'intérêt que si sa seule présence
# renseigne. Un abri de montagne sans nom reste un abri ; une plage sans nom sur
# 13 000 plages n'apprend rien.
#
# CE QUE LE PROFIL A MONTRÉ, ET QUI CHANGE MES CATÉGORIES
#   - « eau_chaude » ne tient pas comme catégorie : une seule source chaude dans
#     toute la Norvège. Bains publics, zones de baignade et saunas sont versés
#     dans « nature ».
#
# CHANGEMENTS v1.1, après arbitrage
#   - SAUNAS CONSERVÉS. Un sauna de camping se visite, un sauna privé non : on
#     garde ceux qui portent un nom, un exploitant, ou une mention d'accès. Les
#     saunas de maison, non renseignés, restent écartés.
#   - RÉSERVES NATURELLES CONSERVÉES, en catégorie « protege ». Elles ne disent
#     pas si l'on peut y accéder en véhicule, mais elles disent qu'on entre dans
#     une zone où des règles particulières s'appliquent — et la circulation
#     motorisée y est souvent restreinte. Seules les réserves nommées sont
#     retenues.
#     RÉSERVE IMPORTANTE : ce sont des CENTROÏDES, pas des contours. Le point
#     marque le centre d'un polygone parfois vaste ; il signale l'existence de
#     la zone, pas ses limites. La propriété « centroide » le rappelle.
#     Les 145 parcs nationaux, eux, sont extraits avec leur contour réel par une
#     requête distincte : ils sont assez peu nombreux pour cela.
#   - « panorama » n'a pas trouvé les belvédères des routes touristiques
#     norvégiennes : l'étiquette que j'espérais n'est pas employée. Restent des
#     points de vue ordinaires, dont 21 à 29 % seulement portent un nom.
#   - Les réserves naturelles, 15 398 polygones administratifs, font le gros du
#     volume sans rien apprendre : les parcs nationaux couvrent l'essentiel.
#     Elles sont écartées.
#
# UTILISATION — depuis le dossier contenant _pois/
#   bash 03-etape13-conversion-pois.sh
# =============================================================================

set -u

# -----------------------------------------------------------------------------
# Contours réels des parcs nationaux : 145 objets sur les trois pays, assez peu
# pour être extraits avec leur géométrie complète plutôt qu'en centroïdes.
# -----------------------------------------------------------------------------
API="https://overpass-api.de/api/interpreter"
if [ ! -s _pois/parcs-contours.json ]; then
  echo "== contours des parcs nationaux =="
  Q='[out:json][timeout:300];
(
  area["ISO3166-1"="NO"][admin_level=2];
  area["ISO3166-1"="SE"][admin_level=2];
  area["ISO3166-1"="FI"][admin_level=2];
)->.p;
nwr["boundary"="national_park"](area.p);
out geom tags;'
  curl -sS -X POST -d "data=$Q" "$API" -o _pois/parcs-contours.json
  echo "   $(du -h _pois/parcs-contours.json | cut -f1)"
else
  echo "== contours des parcs : déjà téléchargés =="
fi

python3 - <<'PY'
import json, io, os, collections, datetime

IN = '_pois'; AUJ = datetime.date.today().isoformat()
rapport = []
def note(s):
    print(s); rapport.append(s)

# --------------------------------------------------------------------------
# RÈGLES DE FILTRAGE — une ligne par type d'objet.
#   'tous'   : conservé, nommé ou non
#   'nomme'  : conservé seulement s'il porte un nom
#   'ecarte' : jamais conservé
# --------------------------------------------------------------------------
REGLES = {
    # nature
    'waterfall':           ('nature', 'nomme'),
    'glacier':             ('nature', 'nomme'),
    'cave_entrance':       ('nature', 'nomme'),
    'beach':               ('nature', 'nomme'),
    'national_park':       ('nature', 'tous'),
    'nature_reserve':      ('protege', 'nomme'),
    'public_bath':         ('nature', 'nomme'),
    'hot_spring':          ('nature', 'tous'),
    'swimming_area':       ('nature', 'nomme'),
    'sauna':               ('nature', 'renseigne'),
    # patrimoine
    'archaeological_site': ('patrimoine', 'nomme'),
    'rune_stone':          ('patrimoine', 'tous'),
    'rock_carving':        ('patrimoine', 'tous'),
    'museum':              ('patrimoine', 'nomme'),
    'mine':                ('patrimoine', 'nomme'),
    'ship':                ('patrimoine', 'nomme'),
    'church':              ('patrimoine', 'nomme'),
    'place_of_worship':    ('patrimoine', 'nomme'),
    # panorama
    'viewpoint':           ('panorama', 'nomme'),
    'picnic_site':         ('panorama', 'nomme'),
    'rest_area':           ('panorama', 'nomme'),
    # faune — rare et décisif, on garde tout
    'bird_hide':           ('faune', 'tous'),
    # refuge — un abri sans nom reste un abri
    'wilderness_hut':      ('refuge', 'tous'),
    'alpine_hut':          ('refuge', 'tous'),
    'shelter':             ('refuge', 'tous'),
}

def marqueur(t):
    """Le type d'objet, tel qu'OSM le désigne. L'ordre reflète la précision."""
    for cle in ('waterway', 'historic', 'boundary', 'natural', 'leisure',
                'tourism', 'amenity', 'highway', 'building'):
        v = t.get(cle)
        if v and v in REGLES:
            return v
    return None

PAYS = {'NO': 'no', 'SE': 'se', 'FI': 'fi'}
feats, vus, hors, lus = [], set(), 0, 0
retenu = collections.Counter()
ecarte = collections.Counter()

for iso, code in PAYS.items():
    c = os.path.join(IN, 'osm-%s.json' % iso)
    if not os.path.exists(c):
        note('fichier absent : ' + c); continue
    els = json.load(io.open(c, encoding='utf-8')).get('elements', [])
    lus += len(els); n0 = len(feats)
    for e in els:
        t = e.get('tags', {}) or {}
        m = marqueur(t)
        if not m:
            ecarte['type non retenu'] += 1; continue
        cat, regle = REGLES[m]
        nom = t.get('name')
        if regle == 'ecarte':
            ecarte[m] += 1; continue
        if regle == 'nomme' and not nom:
            ecarte['%s sans nom' % m] += 1; continue
        if regle == 'renseigne' and not (nom or t.get('operator') or t.get('access')):
            # un sauna de maison ne porte ni nom, ni exploitant, ni mention d'accès
            ecarte['%s non renseigné' % m] += 1; continue
        lat = e.get('lat') or (e.get('center') or {}).get('lat')
        lon = e.get('lon') or (e.get('center') or {}).get('lon')
        if lat is None or lon is None:
            ecarte['sans coordonnées'] += 1; continue
        lat, lon = round(float(lat), 5), round(float(lon), 5)
        if not (2 <= lon <= 34 and 53 <= lat <= 73):
            hors += 1; continue
        cle = (m, lat, lon)
        if cle in vus:
            ecarte['doublon'] += 1; continue
        vus.add(cle)
        retenu[m] += 1

        GEN = {'nature': 'site naturel', 'patrimoine': 'site historique',
               'panorama': 'point de vue', 'faune': 'observatoire', 'refuge': 'abri',
               'protege': 'zone protégée'}
        p = {'id': 'osm-%s-%s' % (e.get('type', 'n')[0], e.get('id')),
             'country': code, 'name': nom or GEN[cat], 'type': cat,
             'source': 'OSM', 'updated': AUJ,
             'objet': m,
             'exploitant': t.get('operator'),
             'acces': t.get('access'),
             'abri_type': t.get('shelter_type'),
             'site_web': t.get('website') or t.get('url'),
             'horaires': t.get('opening_hours'),
             'description': (t.get('description') or '')[:200] or None,
             # une réserve est un polygone : le point n'en est que le centre
             'centroide': True if m == 'nature_reserve' else None,
             'protection': t.get('protection_title') or t.get('protect_class') if m == 'nature_reserve' else None}
        feats.append({'type': 'Feature',
                      'geometry': {'type': 'Point', 'coordinates': [lon, lat]},
                      'properties': {k: v for k, v in p.items() if v is not None}})
    note('%s : %d éléments -> %d retenus' % (iso, len(els), len(feats) - n0))

note('')
note('lus : %d | retenus : %d | hors emprise : %d' % (lus, len(feats), hors))
note('')
note('=== retenus par type ===')
for m, n in retenu.most_common():
    note('  %-22s %6d   (%s, %s)' % (m, n, REGLES[m][0], REGLES[m][1]))
note('')
note('=== écartés, les plus nombreux ===')
for m, n in ecarte.most_common(14):
    note('  %-30s %6d' % (m, n))
note('')
note('=== répartition finale ===')
note('  par catégorie : %s' % dict(collections.Counter(f['properties']['type'] for f in feats)))
note('  par pays      : %s' % dict(collections.Counter(f['properties']['country'] for f in feats)))
note('  avec un nom propre : %d sur %d' % (
    sum(1 for f in feats if f['properties']['name'] not in
        ('site naturel', 'site historique', 'point de vue', 'observatoire', 'abri', 'zone protégée')), len(feats)))
note('  avec un site web : %d | avec une description : %d' % (
    sum(1 for f in feats if f['properties'].get('site_web')),
    sum(1 for f in feats if f['properties'].get('description'))))

# --------------------------------------------------------------------------
# Contours des parcs nationaux : polygones réels, dans un fichier distinct.
# Une zone se lit à ses limites, pas à son centre.
# --------------------------------------------------------------------------
parcs = []
cp = os.path.join(IN, 'parcs-contours.json')
if os.path.exists(cp):
    try:
        els = json.load(io.open(cp, encoding='utf-8')).get('elements', [])
    except Exception as e:
        els = []; note('contours illisibles : ' + str(e)[:80])
    vus_p = set()
    for e in els:
        t = e.get('tags', {}) or {}
        nom = t.get('name')
        if not nom or nom in vus_p:
            continue
        anneaux = []
        if e.get('type') == 'way' and e.get('geometry'):
            anneaux = [[[round(p['lon'], 5), round(p['lat'], 5)] for p in e['geometry']]]
        elif e.get('type') == 'relation':
            for mb in (e.get('members') or []):
                if mb.get('role') == 'outer' and mb.get('geometry'):
                    anneaux.append([[round(p['lon'], 5), round(p['lat'], 5)] for p in mb['geometry']])
        anneaux = [a for a in anneaux if len(a) > 3]
        if not anneaux:
            continue
        vus_p.add(nom)
        pays = 'no' if t.get('addr:country') == 'NO' else None
        cx = sum(p[0] for p in anneaux[0]) / len(anneaux[0])
        cy = sum(p[1] for p in anneaux[0]) / len(anneaux[0])
        if pays is None:
            pays = 'fi' if cx > 20.5 and cy < 70.5 else ('se' if cx > 11.5 and cy < 69.2 else 'no')
        parcs.append({'type': 'Feature',
                      'geometry': {'type': 'MultiLineString', 'coordinates': anneaux},
                      'properties': {'id': 'parc-%s' % e.get('id'), 'country': pays,
                                     'name': nom, 'type': 'parc_national',
                                     'source': 'OSM', 'updated': AUJ,
                                     'site_web': t.get('website') or None}})
    json.dump({'type': 'FeatureCollection', 'features': parcs},
              io.open(os.path.join(IN, 'parcs-nationaux.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
    note('')
    note('-> parcs-nationaux.geojson : %d parcs avec contour, %d Ko'
         % (len(parcs), os.path.getsize(os.path.join(IN, 'parcs-nationaux.geojson')) // 1024))
    note('   par pays : %s' % dict(collections.Counter(f['properties']['country'] for f in parcs)))
    note('   le pays est déduit de la position du contour, faute d\'étiquette fiable — à contrôler.')

json.dump({'type': 'FeatureCollection', 'features': feats},
          io.open(os.path.join(IN, 'pois.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
note('')
note('-> pois.geojson : %d entités, %d Ko'
     % (len(feats), os.path.getsize(os.path.join(IN, 'pois.geojson')) // 1024))

note('')
note('=== échantillons ===')
for cat in ('nature', 'protege', 'patrimoine', 'panorama', 'faune', 'refuge'):
    ex = next((f for f in feats if f['properties']['type'] == cat), None)
    if ex:
        note('  ' + json.dumps(ex['properties'], ensure_ascii=False)[:340])

io.open(os.path.join(IN, 'RAPPORT13.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _pois/RAPPORT13.txt
echo "=========================================="
echo "À me transmettre : _pois/RAPPORT13.txt"
