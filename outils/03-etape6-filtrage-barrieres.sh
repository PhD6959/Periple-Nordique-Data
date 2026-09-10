#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 6 : FILTRAGE DES BARRIÈRES ET FINALISATION
# =============================================================================
#
# CONSTAT DE L'ÉTAPE 5
#   27 784 barrières, 10 Mo. Trop lourd, et surtout trop indifférencié :
#   9 079 sont des « Trafikkavviser », séparateurs de trafic urbains qui ne
#   ferment aucune piste, et 559 sont sur route européenne, nationale ou
#   départementale — ce sont des fermetures d'exploitation, pas des accès.
#
# CE QUE LE FILTRE RETIENT
#   Les barrières qui commandent l'accès à une voie susceptible d'être
#   empruntée : catégories privée, forestière et communale, et fonctions de
#   fermeture véritable — verrouillée, non verrouillée, télécommandée, à péage.
#
# UTILISATION — depuis le dossier contenant _out5/
#   bash 03-etape6-filtrage-barrieres.sh
# =============================================================================

set -u
OUT="_out5"

python3 - <<'PY'
import json, io, os, collections
OUT='_out5'; rapport=[]
def note(s):
    print(s); rapport.append(s)

CAT_UTILES = {'privat', 'skogsveg', 'kommunal'}
FONCTIONS_UTILES = {'Låst sperring', 'Ulåst Sperring', 'Fjernstyrt sperring', 'Betalingssperre'}

c = os.path.join(OUT, 'barrieres.geojson')
d = json.load(io.open(c, encoding='utf-8'))
avant = len(d['features']); taille_avant = os.path.getsize(c)

gardees, exclus = [], collections.Counter()
for f in d['features']:
    p = f['properties']
    if p.get('categorie_voie') not in CAT_UTILES:
        exclus['catégorie de voie : %s' % p.get('categorie_voie')] += 1; continue
    if p.get('fonction') not in FONCTIONS_UTILES:
        exclus['fonction : %s' % p.get('fonction')] += 1; continue
    # allègement : « remarque » et « name » n'apportent rien de plus que « modele »
    gardees.append({'type': 'Feature', 'geometry': f['geometry'], 'properties': {
        'id': p['id'], 'country': p['country'], 'name': p.get('modele') or 'barrière',
        'type': 'barriere', 'source': p['source'], 'updated': p['updated'],
        'route': p.get('route'), 'kommune': p.get('kommune'),
        'categorie_voie': p.get('categorie_voie'), 'fonction': p.get('fonction'),
        'verrouillee': p.get('fonction') == 'Låst sperring'}})

d['features'] = gardees
json.dump(d, io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)

note('=== filtrage des barrières ===')
note('  %d -> %d entités | %d Ko -> %d Ko' % (avant, len(gardees), taille_avant // 1024, os.path.getsize(c) // 1024))
note('  exclus :')
for k, v in exclus.most_common(12):
    note('    %-42s %6d' % (k, v))
note('  retenues par catégorie : %s' % dict(collections.Counter(f['properties']['categorie_voie'] for f in gardees)))
note('  retenues par fonction  : %s' % dict(collections.Counter(f['properties']['fonction'] for f in gardees)))
note('  dont verrouillées      : %d' % sum(1 for f in gardees if f['properties']['verrouillee']))

note('')
note('=== contrôle final des trois couches ===')
OBLIG = ('id', 'country', 'name', 'type', 'source', 'updated')
for nom in ('tunnels.geojson', 'peages.geojson', 'barrieres.geojson'):
    c = os.path.join(OUT, nom)
    d = json.load(io.open(c, encoding='utf-8'))
    fs = d['features']
    ids = set(f['properties']['id'] for f in fs)
    manq = sum(1 for f in fs if any(not f['properties'].get(k) for k in OBLIG))
    hors = 0
    for f in fs:
        cc = f['geometry']['coordinates']
        while isinstance(cc[0], list):
            cc = cc[0]
        if not (2 <= cc[0] <= 34 and 53 <= cc[1] <= 73):
            hors += 1
    note('  %-20s %6d entités | %6d id uniques | schéma incomplet %d | hors emprise %d | %5d Ko'
         % (nom, len(fs), len(ids), manq, hors, os.path.getsize(c) // 1024))

io.open(os.path.join(OUT, 'RAPPORT6.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT6.txt"
echo "=========================================="
echo
echo "Si le rapport est propre, copier vers le dépôt :"
echo "  cp $OUT/tunnels.geojson $OUT/peages.geojson $OUT/barrieres.geojson \\"
echo "     ~/Documents/Projets/Periple-Nordique-Data/sources/"
