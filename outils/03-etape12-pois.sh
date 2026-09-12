#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 12 : POINTS D'INTÉRÊT
# =============================================================================
#
# Source : OpenStreetMap via Overpass. LICENCE ODbL.
#
# SIX CATÉGORIES, arrêtées avec Philippe :
#   nature      cascades, points de vue, plages, glaciers, grottes, parcs
#               nationaux et réserves
#   eau_chaude  sources chaudes, saunas publics, piscines de plein air
#   patrimoine  églises en bois debout, sites vikings, musées, art rupestre,
#               villes minières
#   panorama    aires de repos panoramiques et belvédères des routes
#               touristiques nationales norvégiennes
#   faune       colonies d'oiseaux, observatoires, réserves ornithologiques
#   refuge      huttes en accès libre, abris, cabanes de randonnée
#
# LE FILTRE EST LARGE À DESSEIN : mieux vaut extraire trop et trier au profil
# que rater une catégorie et refaire trois requêtes. Le volume attendu est le
# plus élevé du module.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape12-pois.sh
#
# ENSUITE : me recoller _pois/PROFIL12.txt
# =============================================================================

set -u
OUT="_pois"; mkdir -p "$OUT"
API="https://overpass-api.de/api/interpreter"

requete () {
  local ISO="$1" NOM="$2" FIC="$OUT/osm-$1.json"
  if [ -s "$FIC" ]; then
    echo "== $NOM : déjà téléchargé ($(du -h "$FIC" | cut -f1)) =="
    return
  fi
  echo "== $NOM : interrogation d'Overpass =="
  local Q="[out:json][timeout:300];
area[\"ISO3166-1\"=\"$ISO\"][admin_level=2]->.p;
(
  nwr[\"waterway\"=\"waterfall\"](area.p);
  nwr[\"tourism\"=\"viewpoint\"](area.p);
  nwr[\"natural\"=\"beach\"](area.p);
  nwr[\"natural\"=\"glacier\"](area.p);
  nwr[\"natural\"=\"cave_entrance\"](area.p);
  nwr[\"boundary\"=\"national_park\"](area.p);
  nwr[\"leisure\"=\"nature_reserve\"](area.p);

  nwr[\"natural\"=\"hot_spring\"](area.p);
  nwr[\"amenity\"=\"public_bath\"](area.p);
  nwr[\"leisure\"=\"sauna\"](area.p);
  nwr[\"leisure\"=\"swimming_area\"](area.p);

  nwr[\"historic\"=\"church\"](area.p);
  nwr[\"building\"=\"church\"][\"heritage\"](area.p);
  nwr[\"historic\"=\"archaeological_site\"](area.p);
  nwr[\"historic\"=\"rune_stone\"](area.p);
  nwr[\"historic\"=\"rock_carving\"](area.p);
  nwr[\"tourism\"=\"museum\"](area.p);
  nwr[\"historic\"=\"mine\"](area.p);
  nwr[\"historic\"=\"ship\"](area.p);

  nwr[\"tourism\"=\"picnic_site\"][\"tourism:national_route\"](area.p);
  nwr[\"highway\"=\"rest_area\"][\"tourism\"=\"viewpoint\"](area.p);

  nwr[\"leisure\"=\"bird_hide\"](area.p);
  nwr[\"tourism\"=\"wilderness_hut\"](area.p);
  nwr[\"amenity\"=\"shelter\"][\"shelter_type\"=\"basic_hut\"](area.p);
  nwr[\"amenity\"=\"shelter\"][\"shelter_type\"=\"lean_to\"](area.p);
  nwr[\"tourism\"=\"alpine_hut\"](area.p);
);
out center tags;"
  curl -sS -X POST -d "data=$Q" "$API" -o "$FIC"
  local N
  N=$(python3 -c "
import json,io
try:
    d=json.load(io.open('$FIC',encoding='utf-8')); print(len(d.get('elements',[])))
except Exception as e:
    print('erreur : '+str(e)[:70])")
  echo "   éléments : $N — $(du -h "$FIC" | cut -f1)"
  sleep 25
}

requete NO "Norvège"
requete SE "Suède"
requete FI "Finlande"

python3 - <<'PY' > "$OUT/PROFIL12.txt" 2>&1
import json, io, os, collections

PAYS = {'NO': 'no', 'SE': 'se', 'FI': 'fi'}

def categorie(t):
    if t.get('waterway') == 'waterfall': return 'nature'
    if t.get('natural') in ('beach', 'glacier', 'cave_entrance'): return 'nature'
    if t.get('boundary') == 'national_park' or t.get('leisure') == 'nature_reserve': return 'nature'
    if t.get('natural') == 'hot_spring' or t.get('amenity') == 'public_bath': return 'eau_chaude'
    if t.get('leisure') in ('sauna', 'swimming_area'): return 'eau_chaude'
    if t.get('leisure') == 'bird_hide': return 'faune'
    if t.get('tourism') in ('wilderness_hut', 'alpine_hut') or t.get('amenity') == 'shelter': return 'refuge'
    if t.get('historic') in ('church', 'archaeological_site', 'rune_stone', 'rock_carving', 'mine', 'ship'): return 'patrimoine'
    if t.get('tourism') == 'museum' or t.get('building') == 'church': return 'patrimoine'
    if t.get('tourism') == 'viewpoint' or t.get('highway') == 'rest_area': return 'panorama'
    if t.get('tourism') == 'picnic_site': return 'panorama'
    return 'autre'

total = 0
for iso, code in PAYS.items():
    c = os.path.join('_pois', 'osm-%s.json' % iso)
    if not os.path.exists(c):
        print('fichier absent :', c); continue
    try:
        els = json.load(io.open(c, encoding='utf-8')).get('elements', [])
    except Exception as e:
        print('illisible :', c, str(e)[:90]); continue
    total += len(els)
    print('=' * 70)
    print('%s : %d éléments' % (iso, len(els)))
    cats = collections.Counter(categorie(e.get('tags', {})) for e in els)
    print('  par catégorie :', dict(cats))
    print('  sans coordonnées :', sum(1 for e in els if not (e.get('lat') or (e.get('center') or {}).get('lat'))))
    print('  avec un nom :', sum(1 for e in els if e.get('tags', {}).get('name')))

    # ce qui compose chaque catégorie, pour repérer le bruit
    for cat in ('nature', 'eau_chaude', 'patrimoine', 'panorama', 'faune', 'refuge', 'autre'):
        sous = collections.Counter()
        for e in els:
            t = e.get('tags', {})
            if categorie(t) != cat:
                continue
            marque = (t.get('waterway') or t.get('natural') or t.get('historic') or
                      t.get('tourism') or t.get('leisure') or t.get('boundary') or
                      t.get('amenity') or t.get('highway') or t.get('building') or '?')
            sous[marque] += 1
        if sous:
            print('  -- %-11s %5d : %s' % (cat, sum(sous.values()), dict(sous.most_common(8))))

    # part des entités nommées par catégorie : une cascade sans nom est peu utile
    print('  part nommée par catégorie :')
    for cat in ('nature', 'eau_chaude', 'patrimoine', 'panorama', 'faune', 'refuge'):
        n = [e for e in els if categorie(e.get('tags', {})) == cat]
        if n:
            nommes = sum(1 for e in n if e.get('tags', {}).get('name'))
            print('     %-11s %5d dont %5d nommées (%3.0f %%)' % (cat, len(n), nommes, 100.0 * nommes / len(n)))
    print()

print('=' * 70)
print('TOTAL sur les trois pays :', total, 'éléments')
PY

echo
echo "=========================================="
cat "$OUT/PROFIL12.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL12.txt"
