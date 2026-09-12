#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 17 : NETTOYAGE DES COUCHES FUSIONNÉES
# =============================================================================
#
# DEUX DÉFAUTS CONSTATÉS APRÈS PUBLICATION
#
# 1. ferries.geojson compte 2 812 entités pour 2 803 identifiants : neuf
#    doublons. Un même objet OSM est revenu deux fois dans une requête.
#
# 2. Les tunnels sont découpés en segments. Klaratunneln, à Stockholm, apparaît
#    cinq fois — ce sont cinq tronçons du même ouvrage. Sur une carte, cinq
#    marqueurs superposés pour un seul tunnel n'apprennent rien et faussent les
#    décomptes.
#    Les segments partageant nom, pays et numéro de route sont regroupés en une
#    entité. On conserve la HAUTEUR LA PLUS BASSE des segments : c'est elle qui
#    décide du passage, et une moyenne serait dangereuse.
#
# Les entités norvégiennes issues de la NVDB ne sont pas concernées : elles
# décrivent le tunnel entier, pas ses tronçons.
#
# UTILISATION — depuis le dossier contenant _sefi/
#   bash 03-etape17-nettoyage.sh
# =============================================================================

set -u
python3 - <<'PY'
import json, io, os, collections, urllib.request

IN = '_sefi'
BASE = 'https://raw.githubusercontent.com/PhD6959/Periple-Nordique-Data/main/sources/'
rapport = []
def note(s):
    print(s); rapport.append(s)

def charger(fichier):
    try:
        with urllib.request.urlopen(BASE + fichier, timeout=60) as r:
            return json.loads(r.read().decode('utf-8'))['features']
    except Exception as e:
        note('  %s : téléchargement impossible (%s)' % (fichier, str(e)[:60]))
        return None

# ------------------------------------------------------------ 1. doublons
note('=== retrait des doublons d\'identifiant ===')
for fichier in ('ferries.geojson', 'tunnels.geojson', 'cols-fermetures.geojson'):
    fs = charger(fichier)
    if fs is None:
        continue
    vus, garde, doublons = set(), [], collections.Counter()
    for f in fs:
        i = f['properties']['id']
        if i in vus:
            doublons[i] += 1; continue
        vus.add(i); garde.append(f)
    json.dump({'type': 'FeatureCollection', 'features': garde},
              io.open(os.path.join(IN, fichier), 'w', encoding='utf-8'), ensure_ascii=False)
    note('  %-26s %5d -> %5d (%d doublon(s))' % (fichier, len(fs), len(garde), len(fs) - len(garde)))
    if doublons:
        note('       identifiants concernés : %s' % ', '.join(list(doublons)[:5]))

# ------------------------------------------------------------ 2. segments de tunnel
note('')
note('=== regroupement des segments de tunnel ===')
c = os.path.join(IN, 'tunnels.geojson')
fs = json.load(io.open(c, encoding='utf-8'))['features']

groupes = collections.OrderedDict()
seuls = []
for f in fs:
    p = f['properties']
    if p.get('source') != 'OSM' or p.get('name') in (None, 'tunnel'):
        seuls.append(f); continue
    cle = (p['country'], p['name'], p.get('route') or '')
    groupes.setdefault(cle, []).append(f)

fusionnes, rassembles = [], 0
for cle, lot in groupes.items():
    if len(lot) == 1:
        fusionnes.append(lot[0]); continue
    rassembles += len(lot)
    # on garde le segment le plus contraignant, et on note le nombre de tronçons
    hauteurs = [x['properties'].get('hauteur_max_m') for x in lot
                if x['properties'].get('hauteur_max_m')]
    poids = [x['properties'].get('poids_max_t') for x in lot
             if x['properties'].get('poids_max_t')]
    longueurs = [x['properties'].get('longueur_m') for x in lot
                 if x['properties'].get('longueur_m')]
    ref = lot[0]
    p = dict(ref['properties'])
    if hauteurs:
        p['hauteur_max_m'] = min(hauteurs)   # la plus basse décide du passage
    if poids:
        p['poids_max_t'] = min(poids)
    if longueurs:
        p['longueur_m'] = max(longueurs)
    p['troncons'] = len(lot)
    fusionnes.append({'type': 'Feature', 'geometry': ref['geometry'], 'properties': p})

total = seuls + fusionnes
json.dump({'type': 'FeatureCollection', 'features': total},
          io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)
note('  %d entités -> %d (%d segments regroupés en %d ouvrages)'
     % (len(fs), len(total), rassembles,
        sum(1 for f in fusionnes if f['properties'].get('troncons'))))
note('  taille : %d Ko' % (os.path.getsize(c) // 1024))

note('')
note('=== tunnels les plus bas, après regroupement ===')
bas = sorted((f['properties'] for f in total if f['properties'].get('hauteur_max_m')),
             key=lambda p: p['hauteur_max_m'])[:12]
for p in bas:
    note('  %-34s %s  %.2f m  %s' % (p['name'][:34], p['country'], p['hauteur_max_m'],
                                     ('%d tronçons' % p['troncons']) if p.get('troncons') else ''))
h = [f['properties']['hauteur_max_m'] for f in total if f['properties'].get('hauteur_max_m')]
note('')
note('  tunnels avec hauteur limite : %d sur %d' % (len(h), len(total)))
note('  sous 4,00 m : %d | sous 3,50 m : %d | sous 3,00 m : %d'
     % (sum(1 for x in h if x < 4), sum(1 for x in h if x < 3.5), sum(1 for x in h if x < 3)))

note('')
note('=== contrôle final ===')
for fichier in ('ferries.geojson', 'tunnels.geojson', 'cols-fermetures.geojson'):
    d = json.load(io.open(os.path.join(IN, fichier), encoding='utf-8'))
    fsx = d['features']
    note('  %-26s %5d entités | %5d id uniques | %s | %d Ko'
         % (fichier, len(fsx), len({f['properties']['id'] for f in fsx}),
            dict(collections.Counter(f['properties']['country'] for f in fsx)),
            os.path.getsize(os.path.join(IN, fichier)) // 1024))

io.open(os.path.join(IN, 'RAPPORT17.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _sefi/RAPPORT17.txt
echo "=========================================="
echo "À me transmettre : _sefi/RAPPORT17.txt"
