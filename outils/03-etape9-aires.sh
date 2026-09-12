#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 9 : AIRES DE CAMPING-CAR ET SERVICES DE VIDANGE
# =============================================================================
#
# Source : OpenStreetMap via Overpass. LICENCE ODbL, comme la couche des
# services : la couche produite sera publiée sous cette licence.
#
# Étiquettes retenues, choisies pour un fourgon aménagé :
#   tourism=caravan_site              aires dédiées aux véhicules habitables
#   amenity=sanitary_dump_station     vidange des eaux noires et grises
#   tourism=camp_site                 campings, souvent seule option en avril
#   amenity=drinking_water            points d'eau potable
#   shop=laundry | amenity=laundry    laveries
#
# Le camping sauvage n'est pas cartographiable : il relève du droit d'accès à
# la nature, qui varie selon les trois pays et ne couvre pas les véhicules
# motorisés. La documentation du module 3 en traite.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape9-aires.sh
#
# ENSUITE : me recoller _aires/PROFIL9.txt
# =============================================================================

set -u
OUT="_aires"; mkdir -p "$OUT"
API="https://overpass-api.de/api/interpreter"

requete () {
  local ISO="$1" NOM="$2" FIC="$OUT/osm-$1.json"
  if [ -s "$FIC" ]; then
    echo "== $NOM : déjà téléchargé ($(du -h "$FIC" | cut -f1)) =="
    return
  fi
  echo "== $NOM : interrogation d'Overpass =="
  local Q="[out:json][timeout:180];
area[\"ISO3166-1\"=\"$ISO\"][admin_level=2]->.p;
(
  nwr[\"tourism\"=\"caravan_site\"](area.p);
  nwr[\"amenity\"=\"sanitary_dump_station\"](area.p);
  nwr[\"tourism\"=\"camp_site\"](area.p);
  nwr[\"amenity\"=\"drinking_water\"](area.p);
  nwr[\"shop\"=\"laundry\"](area.p);
  nwr[\"amenity\"=\"laundry\"](area.p);
);
out center tags;"
  curl -sS -X POST -d "data=$Q" "$API" -o "$FIC"
  local N
  N=$(python3 -c "
import json,io
try:
    d=json.load(io.open('$FIC',encoding='utf-8')); print(len(d.get('elements',[])))
except Exception as e:
    print('erreur : '+str(e)[:60])")
  echo "   éléments : $N — $(du -h "$FIC" | cut -f1)"
  sleep 20
}

requete NO "Norvège"
requete SE "Suède"
requete FI "Finlande"

python3 - <<'PY' > "$OUT/PROFIL9.txt" 2>&1
import json, io, os, collections

PAYS = {'NO': 'no', 'SE': 'se', 'FI': 'fi'}

def categorie(t):
    if t.get('amenity') == 'sanitary_dump_station': return 'vidange'
    if t.get('tourism') == 'caravan_site':          return 'aire'
    if t.get('tourism') == 'camp_site':             return 'camping'
    if t.get('amenity') == 'drinking_water':        return 'eau'
    return 'laverie'

# services utiles à un fourgon, tels qu'OSM les étiquette
SERVICES = ['sanitary_dump_station', 'drinking_water', 'power_supply', 'shower',
            'toilets', 'waste_disposal', 'washing_machine', 'internet_access',
            'motor_vehicle', 'tents', 'caravans', 'fee', 'openfire', 'wheelchair']

for iso, code in PAYS.items():
    c = os.path.join('_aires', 'osm-%s.json' % iso)
    if not os.path.exists(c):
        print('fichier absent :', c); continue
    try:
        els = json.load(io.open(c, encoding='utf-8')).get('elements', [])
    except Exception as e:
        print('illisible :', c, str(e)[:80]); continue
    print('=' * 70)
    print('%s : %d éléments' % (iso, len(els)))
    print('  par catégorie :', dict(collections.Counter(categorie(e.get('tags', {})) for e in els)))
    print('  sans coordonnées :', sum(1 for e in els if not (e.get('lat') or (e.get('center') or {}).get('lat'))))
    print('  avec un nom :', sum(1 for e in els if e.get('tags', {}).get('name')))

    # quels services sont renseignés, et à quelle fréquence
    freq = collections.Counter()
    for e in els:
        for k in e.get('tags', {}):
            freq[k] += 1
    print('  étiquettes de service renseignées :')
    for s in SERVICES:
        n = freq.get(s, 0)
        if n:
            print('     %-24s %5d' % (s, n))

    # ce que valent les étiquettes décisives
    for cle in ('sanitary_dump_station', 'drinking_water', 'power_supply', 'fee', 'motor_vehicle'):
        vals = collections.Counter(str(e.get('tags', {}).get(cle)) for e in els if cle in e.get('tags', {}))
        if vals:
            print('     valeurs de %-22s %s' % (cle, dict(vals.most_common(5))))

    # exploitants récurrents, pour repérer les réseaux d'aires
    ops = collections.Counter()
    for e in els:
        t = e.get('tags', {})
        if categorie(t) in ('aire', 'camping'):
            n = t.get('operator') or t.get('brand') or ''
            if n:
                ops[n] += 1
    if ops:
        print('  exploitants les plus fréquents :')
        for n, c2 in ops.most_common(10):
            print('     %-34s %5d' % (n[:34], c2))
    print()

print('=' * 70)
tot = 0
for iso in PAYS:
    c = os.path.join('_aires', 'osm-%s.json' % iso)
    if os.path.exists(c):
        tot += len(json.load(io.open(c, encoding='utf-8')).get('elements', []))
print('TOTAL sur les trois pays :', tot, 'éléments')
PY

echo
echo "=========================================="
cat "$OUT/PROFIL9.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL9.txt"
