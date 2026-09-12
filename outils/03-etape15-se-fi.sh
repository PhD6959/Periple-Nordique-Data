#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 15 : FERRIES, TUNNELS ET FERMETURES — SUÈDE ET FINLANDE
# =============================================================================
#
# Contournement de la clé Trafikverket, qui n'arrive pas. Ce qu'elle
# apporterait, c'est le temps réel — fermetures du jour, état de la chaussée.
# Les couches statiques, elles, sont dans OpenStreetMap.
#
# La Finlande est traitée en même temps : ses ferries manquaient aussi, aucune
# couche de bac ne figurant parmi les 46 couches Digiroad.
#
# LICENCE ODbL, comme les cinq couches déjà tirées d'OSM.
#
# CE QU'ON CHERCHE
#   ferries   route=ferry (liaisons) et amenity=ferry_terminal (embarcadères)
#   tunnels   tunnel=yes sur le réseau principal, avec leurs restrictions
#   cols      mountain_pass=yes, et les voies fermées une partie de l'année
#             (seasonal, snowplowing, access:conditional)
#
# RÉSERVE : la Suède et la Finlande n'ont pas de cols au sens norvégien. Ce
# qu'on cherche est plutôt la route fermée l'hiver — en Laponie surtout. Si la
# récolte est maigre, la rubrique passera en « traité par lien » côté suédois,
# ce qui est un état terminal acceptable et non un échec.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape15-se-fi.sh
# =============================================================================

set -u
OUT="_sefi"; mkdir -p "$OUT"
API="https://overpass-api.de/api/interpreter"

requete () {
  local ISO="$1" NOM="$2" FIC="$OUT/osm-$1.json"
  if [ -s "$FIC" ]; then
    echo "== $NOM : déjà téléchargé ($(du -h "$FIC" | cut -f1)) =="
    return
  fi
  echo "== $NOM =="
  local Q="[out:json][timeout:300];
area[\"ISO3166-1\"=\"$ISO\"][admin_level=2]->.p;
(
  way[\"route\"=\"ferry\"](area.p);
  way[\"motor_vehicle\"][\"route\"=\"ferry\"](area.p);
  nwr[\"amenity\"=\"ferry_terminal\"](area.p);

  way[\"tunnel\"=\"yes\"][\"highway\"~\"^(motorway|trunk|primary|secondary)\$\"](area.p);
  nwr[\"mountain_pass\"=\"yes\"](area.p);
  way[\"highway\"~\"^(primary|secondary|tertiary|unclassified)\$\"][\"seasonal\"](area.p);
  way[\"highway\"~\"^(primary|secondary|tertiary|unclassified)\$\"][\"snowplowing\"=\"no\"](area.p);
);
out center tags;"
  curl -sS -X POST -d "data=$Q" "$API" -o "$FIC"
  echo "   $(python3 -c "
import json,io
try:
    print(len(json.load(io.open('$FIC',encoding='utf-8')).get('elements',[])), 'éléments')
except Exception as e:
    print('erreur :', str(e)[:70])") — $(du -h "$FIC" | cut -f1)"
  sleep 25
}

requete SE "Suède"
requete FI "Finlande"

python3 - <<'PY' > "$OUT/PROFIL15.txt" 2>&1
import json, io, os, collections

def categorie(t):
    if t.get('amenity') == 'ferry_terminal': return 'quai'
    if t.get('route') == 'ferry':            return 'liaison'
    if t.get('mountain_pass') == 'yes':      return 'col'
    if t.get('seasonal') or t.get('snowplowing') == 'no': return 'saisonnier'
    if t.get('tunnel') == 'yes':             return 'tunnel'
    return 'autre'

for iso in ('SE', 'FI'):
    c = os.path.join('_sefi', 'osm-%s.json' % iso)
    if not os.path.exists(c):
        print('fichier absent :', c); continue
    try:
        els = json.load(io.open(c, encoding='utf-8')).get('elements', [])
    except Exception as e:
        print('illisible :', c, str(e)[:90]); continue
    print('=' * 70)
    print('%s : %d éléments' % (iso, len(els)))
    print('  par catégorie :', dict(collections.Counter(categorie(e.get('tags', {})) for e in els)))
    print('  avec un nom :', sum(1 for e in els if e.get('tags', {}).get('name')))
    print('  sans coordonnées :', sum(1 for e in els if not (e.get('lat') or (e.get('center') or {}).get('lat'))))

    for cat in ('liaison', 'quai', 'tunnel', 'col', 'saisonnier'):
        sel = [e for e in els if categorie(e.get('tags', {})) == cat]
        if not sel:
            print('  -- %-11s aucun' % cat); continue
        nommes = sum(1 for e in sel if e.get('tags', {}).get('name'))
        print('  -- %-11s %5d dont %5d nommés' % (cat, len(sel), nommes))
        # étiquettes utiles présentes sur cette catégorie
        freq = collections.Counter()
        for e in sel:
            for k in e.get('tags', {}):
                freq[k] += 1
        utiles = ['operator', 'duration', 'motor_vehicle', 'fee', 'maxheight', 'maxweight',
                  'length', 'seasonal', 'snowplowing', 'access', 'opening_hours', 'ref', 'ele']
        montre = {k: freq[k] for k in utiles if freq.get(k)}
        if montre:
            print('       étiquettes : %s' % montre)
        for e in sel[:3]:
            t = e.get('tags', {})
            print('       ex. %s' % json.dumps({k: v for k, v in t.items() if k in utiles + ['name', 'highway', 'ref']}, ensure_ascii=False)[:150])
    print()
PY

echo
echo "=========================================="
cat "$OUT/PROFIL15.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL15.txt"
