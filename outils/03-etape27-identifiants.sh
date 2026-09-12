#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 27 : IDENTIFIANTS ET FILTRAGE DES OBSTACLES
# =============================================================================
#
# DEUX CORRECTIONS
#
# 1. IDENTIFIANTS EN DOUBLE. Cinq fichiers sur six comptent plus d'entités que
#    d'identifiants uniques — 1048 pour 472 sur les poids. La base suédoise est
#    à positionnement linéaire : un même obstacle apparaît sur plusieurs
#    tronçons, avec le même Feature_Oid mais un Element_Id différent.
#    L'identifiant devient « trv-<Feature_Oid>-<Element_Id> », ce qui distingue
#    les occurrences sans rien perdre. Une propriété « occurrences » indique
#    combien de tronçons portent le même obstacle.
#
# 2. VOLUME DES OBSTACLES. 72 448 entités et 21 Mo, soit le triple de tout ce
#    qui a été publié jusqu'ici. Le type Väghinder ne porte pas la catégorie de
#    la voie, contrairement au type norvégien, donc pas de filtrage possible de
#    ce côté. On filtre sur la NATURE de l'obstacle : ne sont retenus que ceux
#    qui ferment une voie carrossable.
#      RETENUS   låst grind eller bom                barrière verrouillée
#                ej öppningsbar grind eller cykelfålla portail non ouvrable
#                eftergivlig grind                   barrière souple
#      ÉCARTÉS   pollare, betonghinder, stenhinder, spårviddshinder, övrigt
#                — pollards, blocs de béton, obstacles de voirie urbaine, qui
#                ne ferment pas une route mais aménagent une rue.
#
# UTILISATION — depuis le dossier contenant _vagdata/
#   bash 03-etape27-identifiants.sh
# =============================================================================

set -u
python3 - <<'PY'
import json, io, os, glob, collections, datetime, re

IN = '_vagdata'; AUJ = datetime.date.today().isoformat()
HAUTEUR, PTAC, LARGEUR = 3.20, 3.5, 2.2
rapport = []
def note(s):
    print(s); rapport.append(s)

def objets(chemin):
    try:
        res = json.load(io.open(chemin, encoding='utf-8'))['RESPONSE']['RESULT'][0]
    except Exception:
        return []
    c = [k for k in res if k != 'INFO']
    return res[c[0]] if c else []

def wgs(g):
    if not isinstance(g, dict):
        return None
    w = g.get('WKT-WGS84-3D') or g.get('WKT-WGS84')
    if not w:
        return None
    t = w.split('(')[0].strip().upper().replace(' Z', '')
    corps = w[w.find('(') + 1:w.rfind(')')]
    def pts(b):
        out = []
        for p in b.split(','):
            v = p.replace('(', ' ').replace(')', ' ').split()
            if len(v) >= 2:
                try:
                    lon, lat = float(v[0]), float(v[1])
                except ValueError:
                    continue
                if 2 <= lon <= 34 and 53 <= lat <= 73:
                    out.append([round(lon, 5), round(lat, 5)])
        return out
    if t == 'POINT':
        p = pts(corps); return {'type': 'Point', 'coordinates': p[0]} if p else None
    if t == 'LINESTRING':
        p = pts(corps); return {'type': 'LineString', 'coordinates': p} if len(p) > 1 else None
    if t == 'MULTILINESTRING':
        ls = [x for x in (pts(b) for b in re.findall(r'\(([^()]*)\)', corps)) if len(x) > 1]
        return {'type': 'MultiLineString', 'coordinates': ls} if ls else None
    return None

def identite(o):
    """Feature_Oid désigne l'objet, Element_Id le tronçon qui le porte.
    Les deux ensemble distinguent les occurrences."""
    a = o.get('Feature_Oid') or o.get('GID')
    b = o.get('Element_Id')
    return 'trv-%s' % a if b is None else 'trv-%s-%s' % (a, b)

def compter_occurrences(lot):
    return collections.Counter(o.get('Feature_Oid') or o.get('GID') for o in lot)

sorties = {}

# ---------------------------------------------------------------- hauteurs
lot = objets(os.path.join(IN, 'x-Höjdhinder_upp_till_45_dm.json'))
occ = compter_occurrences(lot)
feats = []
for o in lot:
    g = wgs(o.get('Geometry')); h = o.get('Fri_höjd')
    if not g or h is None:
        continue
    h = round(float(h), 2); marge = round(h - HAUTEUR, 2)
    n = occ.get(o.get('Feature_Oid') or o.get('GID'), 1)
    p = {'id': identite(o), 'country': 'se', 'source': 'TRV', 'updated': AUJ,
         'name': '%s %.2f m' % (o.get('Höjdhindertyp') or 'obstacle', h),
         'type': 'hauteur_limitee', 'obstacle': o.get('Höjdhindertyp'),
         'hauteur_max_m': h, 'franchissable': marge > 0, 'marge_cm': int(round(marge * 100)),
         'reference': o.get('Höjdhinderidentitet'),
         'occurrences': n if n > 1 else None,
         'vigilance': True if 0 < marge < 0.30 else None}
    feats.append({'type': 'Feature', 'geometry': g,
                  'properties': {k: v for k, v in p.items() if v is not None}})
sorties['hauteurs-limitees.geojson'] = feats

# ---------------------------------------------------------------- poids, largeur
for fichier, champ, typ, seuil, lib, nom in (
        ('x-BegränsadBruttovikt.json', 'Högsta_tillåtna_bruttovikt', 'poids_limite', PTAC, 'poids', 'poids-limites.geojson'),
        ('x-BegränsadFordonsbredd.json', 'Högsta_tillåtna_fordonsbredd', 'largeur_limitee', LARGEUR, 'largeur', 'largeurs-limites.geojson')):
    lot = objets(os.path.join(IN, fichier))
    occ = compter_occurrences(lot)
    feats = []
    for o in lot:
        g = wgs(o.get('Geometry')); v = o.get(champ)
        if not g or v is None:
            continue
        v = round(float(v), 2)
        n = occ.get(o.get('Feature_Oid') or o.get('GID'), 1)
        p = {'id': identite(o), 'country': 'se', 'source': 'TRV', 'updated': AUJ,
             'name': '%s max %s' % (lib, v), 'type': typ, 'valeur': v,
             'franchissable': v >= seuil,
             'aussi_ensembles': o.get('Avser_även_fordonståg'),
             'info': (o.get('Beskrivning') or '')[:180] or None,
             'occurrences': n if n > 1 else None}
        feats.append({'type': 'Feature', 'geometry': g,
                      'properties': {k: v2 for k, v2 in p.items() if v2 is not None}})
    sorties[nom] = feats

# ---------------------------------------------------------------- obstacles filtrés
RETENUS = {'låst grind eller bom', 'ej öppningsbar grind eller cykelfålla', 'eftergivlig grind'}
lot, vus = [], set()
for f in sorted(glob.glob(os.path.join(IN, 'pages', 'vh-*.json'))):
    for o in objets(f):
        k = (o.get('Feature_Oid'), o.get('Element_Id'))
        if k in vus:
            continue
        vus.add(k); lot.append(o)
occ = compter_occurrences(lot)
feats, ecarte = [], collections.Counter()
for o in lot:
    t = o.get('Hindertyp') or 'obstacle'
    if t not in RETENUS:
        ecarte[t] += 1; continue
    g = wgs(o.get('Geometry'))
    if not g:
        continue
    n = occ.get(o.get('Feature_Oid') or o.get('GID'), 1)
    p = {'id': identite(o), 'country': 'se', 'source': 'TRV', 'updated': AUJ,
         'name': t, 'type': 'barriere', 'modele': t,
         'verrouillee': t == 'låst grind eller bom',
         'occurrences': n if n > 1 else None}
    feats.append({'type': 'Feature', 'geometry': g,
                  'properties': {k2: v for k2, v in p.items() if v is not None}})
sorties['barrieres-se.geojson'] = feats

# ---------------------------------------------------------------- bacs, aires
lot = objets(os.path.join(IN, 'x-Färjeled.json'))
occ = compter_occurrences(lot)
feats = []
for o in lot:
    g = wgs(o.get('Geometry'))
    if not g:
        continue
    n = occ.get(o.get('Feature_Oid') or o.get('GID'), 1)
    p = {'id': identite(o), 'country': 'se', 'source': 'TRV', 'updated': AUJ,
         'name': o.get('Färjeledsnamn') or 'liaison', 'type': 'liaison',
         'exploitation': 'Trafikverket', 'occurrences': n if n > 1 else None}
    feats.append({'type': 'Feature', 'geometry': g,
                  'properties': {k: v for k, v in p.items() if v is not None}})
sorties['bacs-se.geojson'] = feats

lot = objets(os.path.join(IN, 'x-Rastplatser.json'))
oui = lambda v: str(v).strip().lower() == 'ja'
feats = []
for o in lot:
    g = wgs(o.get('Geometric_Position')) or wgs(o.get('Geometry'))
    if not g:
        continue
    p = {'id': identite(o), 'country': 'se', 'source': 'TRV', 'updated': AUJ,
         'name': o.get('Rastplatsnamn') or 'aire de repos', 'type': 'aire',
         'vidange': oui(o.get('Latrintömning')),
         'toilettes': (o.get('Totalt_antal_toaletter') or 0) > 0,
         'places_voiture': o.get('Totalt_antal_parkeringsplatser_för_personbil'),
         'places_poids_lourd': o.get('Totalt_antal_parkeringsplatser_för_lastbil_släp'),
         'tables': o.get('Totalt_antal_bord_med_sittplatser'),
         'aire_de_jeu': oui(o.get('Lekutrustning')),
         'gestionnaire': o.get('Skötselansvarig')}
    p['equipee'] = bool(p['vidange'] or p['toilettes'])
    feats.append({'type': 'Feature', 'geometry': g,
                  'properties': {k: v for k, v in p.items() if v is not None}})
sorties['aires-repos-se.geojson'] = feats

# ---------------------------------------------------------------- écriture et contrôle
note('=== obstacles : filtrage sur la nature ===')
note('  retenus : %d' % len(sorties['barrieres-se.geojson']))
note('  écartés :')
for k, v in ecarte.most_common():
    note('    %-40s %6d' % (k, v))

note('')
note('=== fichiers produits ===')
for nom, feats in sorties.items():
    c = os.path.join(IN, nom)
    json.dump({'type': 'FeatureCollection', 'features': feats},
              io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)
    ids = {f['properties']['id'] for f in feats}
    multi = sum(1 for f in feats if f['properties'].get('occurrences'))
    note('  %-28s %6d entités | %6d id uniques | %5d sur plusieurs tronçons | %5d Ko'
         % (nom, len(feats), len(ids), multi, os.path.getsize(c) // 1024))
    if len(ids) != len(feats):
        note('       DOUBLONS RESTANTS : %d' % (len(feats) - len(ids)))

note('')
note('=== contrôle des couches décisives ===')
h = json.load(io.open(os.path.join(IN, 'hauteurs-limitees.geojson'), encoding='utf-8'))['features']
note('  hauteurs : %d infranchissables, %d en vigilance'
     % (sum(1 for f in h if not f['properties']['franchissable']),
        sum(1 for f in h if f['properties'].get('vigilance'))))
b = json.load(io.open(os.path.join(IN, 'barrieres-se.geojson'), encoding='utf-8'))['features']
note('  barrières : %d dont %d verrouillées'
     % (len(b), sum(1 for f in b if f['properties']['verrouillee'])))
a = json.load(io.open(os.path.join(IN, 'aires-repos-se.geojson'), encoding='utf-8'))['features']
note('  aires : %d dont %d avec vidange' % (len(a), sum(1 for f in a if f['properties'].get('vidange'))))

io.open(os.path.join(IN, 'RAPPORT27.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _vagdata/RAPPORT27.txt
echo "=========================================="
echo "À me transmettre : _vagdata/RAPPORT27.txt"
