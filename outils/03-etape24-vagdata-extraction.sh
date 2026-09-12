#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 24 : BASE ROUTIÈRE SUÉDOISE — EXTRACTION FILTRÉE
# =============================================================================
#
# Neuf types accessibles en schemaversion 1.2, namespace vägdata.nvdb_dk_o
# (vis_dk_o pour les aires de repos). On ne prend que ce qui concerne un
# fourgon de 3,20 m hors tout et 3,5 t de PTAC.
#
# FILTRES APPLIQUÉS CÔTÉ SERVEUR, avec l'élément FILTER de l'API :
#   hauteurs      Fri_höjd < 4,0 m          marge de 80 cm au-dessus du fourgon
#   poids brut    Högsta_tillåtna_bruttovikt < 8 t
#   largeur       Högsta_tillåtna_fordonsbredd < 3,0 m
#   longueur      aucun filtre — le fourgon est court, on prend tout pour
#                 mémoire, le volume étant faible
#   barrières     aucun filtre — toutes, comme côté norvégien
#   bacs, aires   aucun filtre
#   portance      aucun filtre sur cette passe : il faut d'abord savoir ce que
#                 valent les classes suédoises. Le volume serait énorme.
#
# POURQUOI DES SEUILS PLUS LARGES QUE LE FOURGON : un obstacle à 3,50 m ne te
# bloque pas, mais il faut le voir pour juger. Le filtrage fin se fera à
# l'affichage, où il est réversible, et non à l'extraction, où il ne l'est pas.
#
# LA CLÉ EST LUE DANS ~/.trafikverket-key.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape24-vagdata-extraction.sh
# =============================================================================

set -u
OUT="_vagdata"; mkdir -p "$OUT"
CLE_FICHIER="$HOME/.trafikverket-key"
API="https://api.trafikinfo.trafikverket.se/v2/data.json"
NS="vägdata.nvdb_dk_o"

[ -s "$CLE_FICHIER" ] || { echo "Clé absente : $CLE_FICHIER"; exit 1; }
CLE=$(cat "$CLE_FICHIER")

# extraire TYPE NAMESPACE FILTRE_XML
extraire () {
  local TYPE="$1" NSP="$2" FILTRE="$3" FIC="$OUT/x-$1.json"
  echo "== $TYPE =="
  if [ -s "$FIC" ]; then
    echo "   déjà téléchargé ($(du -h "$FIC" | cut -f1))"
    return
  fi
  local REQ="<REQUEST><LOGIN authenticationkey=\"$CLE\" /><QUERY objecttype=\"$TYPE\" namespace=\"$NSP\" schemaversion=\"1.2\" limit=\"20000\"><FILTER>$FILTRE</FILTER></QUERY></REQUEST>"
  curl -sS -X POST -H "Content-Type: text/xml" -d "$REQ" "$API" -o "$FIC"
  python3 -c "
import json,io
try:
    d=json.load(io.open('$FIC',encoding='utf-8'))
except Exception as e:
    print('   illisible :', str(e)[:70]); raise SystemExit
res=(d.get('RESPONSE') or {}).get('RESULT',[{}])[0]
if 'ERROR' in res:
    print('   REFUS :', str(res['ERROR'].get('MESSAGE'))[:140]); raise SystemExit
cles=[k for k in res if k!='INFO']
n=len(res[cles[0]]) if cles else 0
print('   %d objet(s)' % n)
if n>=20000:
    print('   ATTENTION : plafond atteint, le jeu est tronqué')"
  echo "   $(du -h "$FIC" | cut -f1)"
  sleep 3
}

extraire "Höjdhinder_upp_till_45_dm" "$NS" '<LT name="Fri_höjd" value="4.0" />'
extraire "BegränsadBruttovikt"       "$NS" '<LT name="Högsta_tillåtna_bruttovikt" value="8" />'
extraire "BegränsadFordonsbredd"     "$NS" '<LT name="Högsta_tillåtna_fordonsbredd" value="3.0" />'
extraire "BegränsadFordonslängd"     "$NS" ''
extraire "Väghinder"                 "$NS" ''
extraire "Färjeled"                  "$NS" ''
extraire "Rastplatser"               "vägdata.vis_dk_o" ''

python3 - <<'PY' > "$OUT/RAPPORT24.txt" 2>&1
import json, io, os, collections

OUT = '_vagdata'
HAUTEUR, PTAC = 3.20, 3.5

def charger(t):
    c = os.path.join(OUT, 'x-%s.json' % t)
    if not os.path.exists(c):
        return None
    try:
        res = json.load(io.open(c, encoding='utf-8'))['RESPONSE']['RESULT'][0]
    except Exception:
        return None
    cles = [k for k in res if k != 'INFO']
    return res[cles[0]] if cles else []

print('=== volumes extraits ===')
lots = {}
for t in ('Höjdhinder_upp_till_45_dm', 'BegränsadBruttovikt', 'BegränsadFordonsbredd',
          'BegränsadFordonslängd', 'Väghinder', 'Färjeled', 'Rastplatser'):
    lot = charger(t)
    lots[t] = lot
    print('  %-30s %s' % (t, 'échec' if lot is None else '%d objets' % len(lot)))

# --- hauteurs : ce qui bloque un fourgon de 3,20 m
lot = lots.get('Höjdhinder_upp_till_45_dm') or []
if lot:
    h = [x.get('Fri_höjd') for x in lot if x.get('Fri_höjd') is not None]
    print('')
    print('=== obstacles en hauteur ===')
    print('  avec hauteur renseignée : %d sur %d' % (len(h), len(lot)))
    print('  INFRANCHISSABLES à %.2f m : %d' % (HAUTEUR, sum(1 for x in h if x <= HAUTEUR)))
    print('  marge sous 30 cm          : %d' % sum(1 for x in h if HAUTEUR < x < HAUTEUR + 0.30))
    print('  répartition : %s' % dict(sorted(collections.Counter(h).items())))
    print('  types d\'obstacle : %s' % dict(collections.Counter(
        x.get('Höjdhindertyp') for x in lot).most_common(10)))
    bas = sorted((x for x in lot if x.get('Fri_höjd') is not None), key=lambda x: x['Fri_höjd'])[:10]
    print('  les plus bas :')
    for x in bas:
        print('    %.2f m  %-22s %s' % (x['Fri_höjd'], x.get('Höjdhindertyp') or '?',
                                        x.get('Höjdhinderidentitet') or ''))

# --- poids et largeur
for t, champ, lib, seuil in (
        ('BegränsadBruttovikt', 'Högsta_tillåtna_bruttovikt', 'poids brut', PTAC),
        ('BegränsadFordonsbredd', 'Högsta_tillåtna_fordonsbredd', 'largeur', 2.2),
        ('BegränsadFordonslängd', 'Högsta_tillåtna_fordonslängd', 'longueur', 7.0)):
    lot = lots.get(t) or []
    if not lot:
        continue
    v = [x.get(champ) for x in lot if x.get(champ) is not None]
    print('')
    print('=== %s ===' % lib)
    print('  objets : %d | valeurs renseignées : %d' % (len(lot), len(v)))
    print('  répartition : %s' % dict(sorted(collections.Counter(v).items())[:14]))
    print('  contraignants pour le fourgon (< %s) : %d' % (seuil, sum(1 for x in v if x < seuil)))

# --- barrières
lot = lots.get('Väghinder') or []
if lot:
    print('')
    print('=== obstacles sur la voie ===')
    print('  objets : %d' % len(lot))
    print('  par type : %s' % dict(collections.Counter(
        x.get('Hindertyp') for x in lot).most_common(12)))

# --- bacs
lot = lots.get('Färjeled') or []
if lot:
    noms = collections.Counter(x.get('Färjeledsnamn') for x in lot if x.get('Färjeledsnamn'))
    print('')
    print('=== liaisons de bacs ===')
    print('  objets : %d | liaisons nommées distinctes : %d' % (len(lot), len(noms)))
    print('  exemples : %s' % ', '.join(list(noms)[:8]))

# --- aires de repos
lot = lots.get('Rastplatser') or []
if lot:
    print('')
    print('=== aires de repos ===')
    print('  objets : %d' % len(lot))
    for champ, lib in (('Latrintömning', 'vidange de toilettes chimiques'),
                       ('Lekutrustning', 'aire de jeu'),
                       ('Lämplig_lastbilsparkeringsplats', 'adaptée aux poids lourds'),
                       ('Samlokaliserad', 'colocalisée')):
        c = collections.Counter(x.get(champ) for x in lot)
        print('  %-32s %s' % (lib, dict(c)))
    tot = [x.get('Totalt_antal_parkeringsplatser_för_personbil') for x in lot
           if isinstance(x.get('Totalt_antal_parkeringsplatser_för_personbil'), int)]
    if tot:
        print('  places voiture : total %d, médiane %d' % (sum(tot), sorted(tot)[len(tot)//2]))
    gest = collections.Counter(x.get('Skötselansvarig') for x in lot)
    print('  gestionnaires : %s' % dict(gest.most_common(5)))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT24.txt"
echo "=========================================="
echo "À me transmettre : $OUT/RAPPORT24.txt — la clé n'y figure pas."
