#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 28 : IDENTIFIANTS COMPLETS
# =============================================================================
#
# 83 doublons résistaient à l'étape 27 : 75 sur les hauteurs, 4 sur les poids,
# 3 sur les aires, 1 sur les bacs. Certains objets partagent à la fois
# Feature_Oid et Element_Id, et ne se distinguent que par leur POSITION sur le
# tronçon — Start_Measure et End_Measure pour une portion, Measure pour un
# point.
#
# L'identifiant devient donc : trv-<Feature_Oid>-<Element_Id>-<position>
# où la position est arrondie au dix-millième, ce qui suffit à distinguer deux
# objets sans dépendre du bruit des décimales.
#
# GARDE-FOU : si des doublons subsistent malgré cela, le script les NOMME au
# lieu de les taire, avec les champs qui les rendent indiscernables. On saura
# alors s'il s'agit de vrais doublons de la base ou d'une clé encore incomplète.
#
# Ce script ne retélécharge rien : il relit les fichiers déjà extraits.
#
# UTILISATION — depuis le dossier contenant _vagdata/
#   bash 03-etape28-identifiants-complets.sh
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

def position(o):
    """La position de l'objet sur le tronçon, qui distingue deux occurrences
    partageant le même objet et le même tronçon."""
    m = o.get('Measure')
    if m is not None:
        return '%.4f' % float(m)
    a, b = o.get('Start_Measure'), o.get('End_Measure')
    if a is not None or b is not None:
        return '%.4f_%.4f' % (float(a or 0), float(b or 0))
    return None

def identite(o):
    bouts = ['trv', str(o.get('Feature_Oid') or o.get('GID'))]
    if o.get('Element_Id') is not None:
        bouts.append(str(o['Element_Id']))
    p = position(o)
    if p:
        bouts.append(p)
    return '-'.join(bouts)

def occurrences(lot):
    return collections.Counter(o.get('Feature_Oid') or o.get('GID') for o in lot)

def bati(o, occ, extra):
    n = occ.get(o.get('Feature_Oid') or o.get('GID'), 1)
    p = {'id': identite(o), 'country': 'se', 'source': 'TRV', 'updated': AUJ,
         'occurrences': n if n > 1 else None}
    p.update(extra)
    return {k: v for k, v in p.items() if v is not None}

sorties = {}

# ---------------------------------------------------------------- hauteurs
lot = objets(os.path.join(IN, 'x-Höjdhinder_upp_till_45_dm.json'))
occ = occurrences(lot); feats = []
for o in lot:
    g = wgs(o.get('Geometry')); h = o.get('Fri_höjd')
    if not g or h is None:
        continue
    h = round(float(h), 2); marge = round(h - HAUTEUR, 2)
    feats.append({'type': 'Feature', 'geometry': g, 'properties': bati(o, occ, {
        'name': '%s %.2f m' % (o.get('Höjdhindertyp') or 'obstacle', h),
        'type': 'hauteur_limitee', 'obstacle': o.get('Höjdhindertyp'),
        'hauteur_max_m': h, 'franchissable': marge > 0, 'marge_cm': int(round(marge * 100)),
        'reference': o.get('Höjdhinderidentitet'),
        'vigilance': True if 0 < marge < 0.30 else None})})
sorties['hauteurs-limitees.geojson'] = feats

# ---------------------------------------------------------------- poids, largeur
for fichier, champ, typ, seuil, lib, nom in (
        ('x-BegränsadBruttovikt.json', 'Högsta_tillåtna_bruttovikt', 'poids_limite', PTAC, 'poids', 'poids-limites.geojson'),
        ('x-BegränsadFordonsbredd.json', 'Högsta_tillåtna_fordonsbredd', 'largeur_limitee', LARGEUR, 'largeur', 'largeurs-limites.geojson')):
    lot = objets(os.path.join(IN, fichier))
    occ = occurrences(lot); feats = []
    for o in lot:
        g = wgs(o.get('Geometry')); v = o.get(champ)
        if not g or v is None:
            continue
        v = round(float(v), 2)
        feats.append({'type': 'Feature', 'geometry': g, 'properties': bati(o, occ, {
            'name': '%s max %s' % (lib, v), 'type': typ, 'valeur': v,
            'franchissable': v >= seuil,
            'aussi_ensembles': o.get('Avser_även_fordonståg'),
            'info': (o.get('Beskrivning') or '')[:180] or None})})
    sorties[nom] = feats

# ---------------------------------------------------------------- obstacles
RETENUS = {'låst grind eller bom', 'ej öppningsbar grind eller cykelfålla', 'eftergivlig grind'}
lot, vus = [], set()
for f in sorted(glob.glob(os.path.join(IN, 'pages', 'vh-*.json'))):
    for o in objets(f):
        k = (o.get('Feature_Oid'), o.get('Element_Id'), position(o))
        if k in vus:
            continue
        vus.add(k); lot.append(o)
occ = occurrences(lot); feats = []
for o in lot:
    t = o.get('Hindertyp') or 'obstacle'
    if t not in RETENUS:
        continue
    g = wgs(o.get('Geometry'))
    if not g:
        continue
    feats.append({'type': 'Feature', 'geometry': g, 'properties': bati(o, occ, {
        'name': t, 'type': 'barriere', 'modele': t,
        'verrouillee': t == 'låst grind eller bom'})})
sorties['barrieres-se.geojson'] = feats

# ---------------------------------------------------------------- bacs, aires
lot = objets(os.path.join(IN, 'x-Färjeled.json'))
occ = occurrences(lot); feats = []
for o in lot:
    g = wgs(o.get('Geometry'))
    if not g:
        continue
    feats.append({'type': 'Feature', 'geometry': g, 'properties': bati(o, occ, {
        'name': o.get('Färjeledsnamn') or 'liaison', 'type': 'liaison',
        'exploitation': 'Trafikverket'})})
sorties['bacs-se.geojson'] = feats

lot = objets(os.path.join(IN, 'x-Rastplatser.json'))
occ = occurrences(lot)
oui = lambda v: str(v).strip().lower() == 'ja'
feats = []
for o in lot:
    g = wgs(o.get('Geometric_Position')) or wgs(o.get('Geometry'))
    if not g:
        continue
    p = {'name': o.get('Rastplatsnamn') or 'aire de repos', 'type': 'aire',
         'vidange': oui(o.get('Latrintömning')),
         'toilettes': (o.get('Totalt_antal_toaletter') or 0) > 0,
         'places_voiture': o.get('Totalt_antal_parkeringsplatser_för_personbil'),
         'places_poids_lourd': o.get('Totalt_antal_parkeringsplatser_för_lastbil_släp'),
         'tables': o.get('Totalt_antal_bord_med_sittplatser'),
         'aire_de_jeu': oui(o.get('Lekutrustning')),
         'gestionnaire': o.get('Skötselansvarig')}
    p['equipee'] = bool(p['vidange'] or p['toilettes'])
    feats.append({'type': 'Feature', 'geometry': g, 'properties': bati(o, occ, p)})
sorties['aires-repos-se.geojson'] = feats

# ---------------------------------------------------------------- écriture
note('=== fichiers produits ===')
restants = {}
for nom, feats in sorties.items():
    c = os.path.join(IN, nom)
    json.dump({'type': 'FeatureCollection', 'features': feats},
              io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)
    ids = collections.Counter(f['properties']['id'] for f in feats)
    doubles = {k: v for k, v in ids.items() if v > 1}
    restants[nom] = doubles
    note('  %-28s %6d entités | %6d id uniques | %5d Ko%s'
         % (nom, len(feats), len(ids), os.path.getsize(c) // 1024,
            '' if not doubles else '  — %d DOUBLON(S)' % (len(feats) - len(ids))))

# ---------------------------------------------------------------- doublons nommés
note('')
note('=== doublons restants, nommés ===')
aucun = True
for nom, doubles in restants.items():
    if not doubles:
        continue
    aucun = False
    note('  %s : %d identifiant(s) en double' % (nom, len(doubles)))
    feats = sorties[nom]
    for cle in list(doubles)[:4]:
        lot = [f for f in feats if f['properties']['id'] == cle]
        note('    %s — %d occurrences' % (cle, len(lot)))
        for f in lot[:2]:
            cc = f['geometry']['coordinates']
            while isinstance(cc[0], list):
                cc = cc[0]
            note('      %s à %.5f, %.5f' % (f['properties'].get('name'), cc[0], cc[1]))
if aucun:
    note('  aucun — tous les identifiants sont uniques')

note('')
note('=== couches décisives ===')
h = sorties['hauteurs-limitees.geojson']
note('  hauteurs : %d dont %d infranchissables, %d en vigilance'
     % (len(h), sum(1 for f in h if not f['properties']['franchissable']),
        sum(1 for f in h if f['properties'].get('vigilance'))))
b = sorties['barrieres-se.geojson']
note('  barrières : %d dont %d verrouillées'
     % (len(b), sum(1 for f in b if f['properties']['verrouillee'])))
a = sorties['aires-repos-se.geojson']
note('  aires : %d dont %d avec vidange, %d avec toilettes'
     % (len(a), sum(1 for f in a if f['properties'].get('vidange')),
        sum(1 for f in a if f['properties'].get('toilettes'))))

io.open(os.path.join(IN, 'RAPPORT28.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _vagdata/RAPPORT28.txt
echo "=========================================="
echo "À me transmettre : _vagdata/RAPPORT28.txt"
