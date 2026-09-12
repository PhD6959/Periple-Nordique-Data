#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 29 : LES QUATRE DERNIERS DOUBLONS
# =============================================================================
#
# Le rapport 28 les a nommés, et ils relèvent de DEUX CAS OPPOSÉS.
#
# 1. VRAI DOUBLON — poids-limites.geojson
#    trv-10083:280000-3:153273-0.9955_1.0000 apparaît deux fois, aux mêmes
#    coordonnées au cent-millième près. C'est une double saisie de la base.
#    → on écarte la seconde occurrence.
#
# 2. COLLISION DE CLÉ — aires-repos-se.geojson
#    Trois identifiants désignent DEUX LIEUX DIFFÉRENTS. Förkärla Ö apparaît à
#    12,82° et 15,43° de longitude, soit deux cents kilomètres d'écart ;
#    Morokulien de même. Ce ne sont pas des doublons : ce sont deux aires
#    distinctes que ma clé confond, Feature_Oid n'étant pas propre à l'aire.
#    → on les garde TOUTES, en ajoutant les coordonnées à l'identifiant.
#
# La distinction se fait sur les coordonnées : deux occurrences au même endroit
# sont un doublon, deux occurrences à des endroits différents sont deux objets.
# Le seuil est fixé à 50 mètres, soit environ 0,0005 degré de latitude.
#
# Ce script ne retélécharge rien.
#
# UTILISATION — depuis le dossier contenant _vagdata/
#   bash 03-etape29-doublons.sh
# =============================================================================

set -u
python3 - <<'PY'
import json, io, os, collections, math

IN = '_vagdata'
SEUIL_M = 50
rapport = []
def note(s):
    print(s); rapport.append(s)

def premier_point(f):
    c = f['geometry']['coordinates']
    while isinstance(c[0], list):
        c = c[0]
    return c[0], c[1]

def distance_m(a, b):
    """Distance approchée, suffisante pour trancher entre 80 m et 200 km."""
    dx = (a[0] - b[0]) * 111320 * math.cos(math.radians((a[1] + b[1]) / 2))
    dy = (a[1] - b[1]) * 110540
    return math.hypot(dx, dy)

FICHIERS = ('hauteurs-limitees.geojson', 'poids-limites.geojson', 'largeurs-limites.geojson',
            'barrieres-se.geojson', 'bacs-se.geojson', 'aires-repos-se.geojson')

note('=== traitement des doublons ===')
for nom in FICHIERS:
    c = os.path.join(IN, nom)
    if not os.path.exists(c):
        note('  %-28s absent' % nom); continue
    d = json.load(io.open(c, encoding='utf-8'))
    fs = d['features']
    par_id = collections.OrderedDict()
    for f in fs:
        par_id.setdefault(f['properties']['id'], []).append(f)

    garde, ecartes, distingues = [], 0, 0
    for cle, lot in par_id.items():
        if len(lot) == 1:
            garde.append(lot[0]); continue
        # on compare les positions deux à deux
        retenus = [lot[0]]
        for f in lot[1:]:
            p = premier_point(f)
            if any(distance_m(p, premier_point(g)) < SEUIL_M for g in retenus):
                ecartes += 1           # même endroit : doublon de saisie
            else:
                retenus.append(f)      # endroit différent : autre objet
        # les objets distincts reçoivent un identifiant enrichi des coordonnées
        if len(retenus) > 1:
            for f in retenus:
                lon, lat = premier_point(f)
                f['properties']['id'] = '%s@%.5f,%.5f' % (cle, lon, lat)
                distingues += 1
        garde.extend(retenus)

    d['features'] = garde
    json.dump(d, io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)
    ids = {f['properties']['id'] for f in garde}
    etat = 'ok' if len(ids) == len(garde) else 'DOUBLONS RESTANTS : %d' % (len(garde) - len(ids))
    note('  %-28s %6d -> %6d entités | écartés %d | distingués %d | %s'
         % (nom, len(fs), len(garde), ecartes, distingues, etat))

note('')
note('=== contrôle final des six couches ===')
for nom in FICHIERS:
    c = os.path.join(IN, nom)
    if not os.path.exists(c):
        continue
    fs = json.load(io.open(c, encoding='utf-8'))['features']
    ids = {f['properties']['id'] for f in fs}
    hors = 0
    for f in fs:
        lon, lat = premier_point(f)
        if not (2 <= lon <= 34 and 53 <= lat <= 73):
            hors += 1
    manq = sum(1 for f in fs
               if any(not f['properties'].get(k) for k in ('id', 'country', 'name', 'type', 'source', 'updated')))
    note('  %-28s %6d entités | %6d id uniques | schéma incomplet %d | hors emprise %d | %5d Ko'
         % (nom, len(fs), len(ids), manq, hors, os.path.getsize(c) // 1024))

note('')
note('=== couches décisives ===')
h = json.load(io.open(os.path.join(IN, 'hauteurs-limitees.geojson'), encoding='utf-8'))['features']
note('  hauteurs : %d dont %d infranchissables à 3,20 m, %d en vigilance'
     % (len(h), sum(1 for f in h if not f['properties']['franchissable']),
        sum(1 for f in h if f['properties'].get('vigilance'))))
b = json.load(io.open(os.path.join(IN, 'barrieres-se.geojson'), encoding='utf-8'))['features']
note('  barrières : %d dont %d verrouillées'
     % (len(b), sum(1 for f in b if f['properties']['verrouillee'])))
a = json.load(io.open(os.path.join(IN, 'aires-repos-se.geojson'), encoding='utf-8'))['features']
note('  aires : %d dont %d avec vidange, %d avec toilettes'
     % (len(a), sum(1 for f in a if f['properties'].get('vidange')),
        sum(1 for f in a if f['properties'].get('toilettes'))))

io.open(os.path.join(IN, 'RAPPORT29.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _vagdata/RAPPORT29.txt
echo "=========================================="
echo
echo "Si tout est propre, publier les six couches :"
echo "  cp _vagdata/hauteurs-limitees.geojson _vagdata/poids-limites.geojson \\"
echo "     _vagdata/largeurs-limites.geojson _vagdata/barrieres-se.geojson \\"
echo "     _vagdata/bacs-se.geojson _vagdata/aires-repos-se.geojson \\"
echo "     ~/Documents/Projets/Periple-Nordique-Data/sources/"
