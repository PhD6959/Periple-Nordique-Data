#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 7 : EXTRACTION DES SERVICES (carburant, alimentation, alcool)
# =============================================================================
#
# Source : OpenStreetMap via l'API Overpass. LICENCE ODbL — attribution
# obligatoire et propagation aux données dérivées. La couche produite sera donc
# publiée en ODbL, ce qui doit figurer dans le manifeste et dans le README.
#
# Trois requêtes, une par pays, chacune couvrant :
#   amenity=fuel                      stations-service
#   shop=supermarket | convenience    alimentation
#   shop=alcohol                      monopoles d'alcool et cavistes
#
# L'API Overpass est publique et limitée en débit : le script attend entre les
# requêtes et réutilise les fichiers déjà téléchargés si on le relance.
#
# UTILISATION
#   bash 03-etape7-services.sh
#
# ENSUITE : me recoller _services/PROFIL7.txt — la liste des enseignes réelles.
# C'est elle qui servira à écrire la table de normalisation, plutôt que ma
# mémoire : la note du manifeste l'exige explicitement.
# =============================================================================

set -u
OUT="_services"; mkdir -p "$OUT"
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
  nwr[\"amenity\"=\"fuel\"](area.p);
  nwr[\"shop\"=\"supermarket\"](area.p);
  nwr[\"shop\"=\"convenience\"](area.p);
  nwr[\"shop\"=\"alcohol\"](area.p);
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
  sleep 20   # Overpass est un service public partagé : on ne le bouscule pas
}

requete NO "Norvège"
requete SE "Suède"
requete FI "Finlande"

python3 - <<'PY' > "$OUT/PROFIL7.txt" 2>&1
import json, io, os, collections

PAYS = {'NO': 'no', 'SE': 'se', 'FI': 'fi'}
categorie = lambda t: ('carburant' if t.get('amenity') == 'fuel'
                       else 'alcool' if t.get('shop') == 'alcohol'
                       else 'alimentation')

tout = {}
for iso, code in PAYS.items():
    c = os.path.join('_services', 'osm-%s.json' % iso)
    if not os.path.exists(c):
        print('fichier absent :', c); continue
    try:
        d = json.load(io.open(c, encoding='utf-8'))
    except Exception as e:
        print('illisible :', c, str(e)[:80]); continue
    els = d.get('elements', [])
    tout[code] = els
    print('=' * 70)
    print('%s : %d éléments' % (iso, len(els)))
    cats = collections.Counter(categorie(e.get('tags', {})) for e in els)
    print('  par catégorie :', dict(cats))
    sans_geo = sum(1 for e in els if not (e.get('lat') or (e.get('center') or {}).get('lat')))
    print('  sans coordonnées :', sans_geo)
    for cat in ('carburant', 'alimentation', 'alcool'):
        noms = collections.Counter()
        for e in els:
            t = e.get('tags', {})
            if categorie(t) != cat:
                continue
            n = t.get('brand') or t.get('operator') or t.get('name') or '(sans nom)'
            noms[n] += 1
        print('  -- %s : %d éléments, %d libellés distincts' % (cat, sum(noms.values()), len(noms)))
        for n, c2 in noms.most_common(22):
            print('       %-34s %5d' % (n[:34], c2))
    # étiquettes utiles présentes
    cles = collections.Counter()
    for e in els:
        for k in e.get('tags', {}):
            cles[k] += 1
    interessantes = ['brand', 'operator', 'name', 'opening_hours', 'fuel:diesel',
                     'fuel:lpg', 'compressed_air', 'self_service', 'shop', 'amenity']
    print('  étiquettes utiles :', {k: cles.get(k, 0) for k in interessantes})
    print()

print('=' * 70)
total = sum(len(v) for v in tout.values())
print('TOTAL sur les trois pays :', total, 'éléments')
PY

echo
echo "=========================================="
cat "$OUT/PROFIL7.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL7.txt"
