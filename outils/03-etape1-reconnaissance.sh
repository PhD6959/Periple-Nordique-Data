#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 1 : RECONNAISSANCE DES SOURCES
# =============================================================================
#
# Ce script ne collecte aucune donnée définitive. Il interroge les catalogues
# des trois administrations pour établir les identifiants exacts dont j'ai
# besoin avant de rédiger les vraies requêtes d'extraction.
#
# Les sorties sont volontairement courtes : elles sont faites pour être
# recollées dans le fil de discussion.
#
# UTILISATION
#   1. Ouvrir le Terminal
#   2. cd ~/Downloads
#   3. bash 03-etape1-reconnaissance.sh
#   4. Recoller le contenu des fichiers produits dans _reco/
#
# PRÉREQUIS : curl (fourni par macOS) et python3.
#   Si python3 manque : xcode-select --install
# =============================================================================

set -u
OUT="_reco"
mkdir -p "$OUT"
echo "Sorties dans : $(pwd)/$OUT"
echo

# -----------------------------------------------------------------------------
# NORVÈGE — catalogue d'objets de la NVDB
# On cherche les identifiants de « Værutsatt veg », « Ferjekai », « Tunnel »
# et « Bomstasjon ». L'en-tête X-Client est demandé par Statens vegvesen pour
# identifier l'appelant : ce n'est pas une clé, juste une politesse.
# -----------------------------------------------------------------------------
echo "== NO 1/2 : catalogue NVDB =="
curl -sS -H "Accept: application/json" -H "X-Client: PeripleNordique2027" \
  "https://nvdbapiles.atlas.vegvesen.no/datakatalog/api/v1/vegobjekttyper" \
  -o "$OUT/no-datakatalog-brut.json"

python3 - <<'PY' > "$OUT/no-types.txt" 2>&1
import json, re, io
try:
    d = json.load(io.open('_reco/no-datakatalog-brut.json', encoding='utf-8'))
except Exception as e:
    print('ECHEC lecture du catalogue :', e); raise SystemExit
items = d if isinstance(d, list) else d.get('vegobjekttyper', d.get('objekttyper', []))
print('types au catalogue :', len(items))
motifs = ('vaerutsatt', 'vrutsatt', 'ferje', 'ferge', 'tunnel', 'bomstasjon',
          'bomst', 'vinter', 'sperring', 'skred', 'rasteplass')
def norm(s):
    return re.sub(r'[^a-z]', '', str(s).lower().replace('æ','ae').replace('ø','o').replace('å','a'))
for it in items:
    n = norm(it.get('navn'))
    if any(m in n for m in motifs):
        print(it.get('id'), '|', it.get('navn'), '|', (it.get('beskrivelse') or '')[:110].replace('\n', ' '))
PY
echo "   -> $OUT/no-types.txt"

echo "== NO 2/2 : volumétrie d'un type (exemple, à ajuster) =="
# Simple contrôle que l'API de lecture répond. 967 est un identifiant d'essai ;
# je remplacerai par les bons identifiants une fois le catalogue lu.
curl -sS -H "Accept: application/json" -H "X-Client: PeripleNordique2027" \
  "https://nvdbapiles.atlas.vegvesen.no/vegobjekter/v4/vegobjekttyper" \
  -o "$OUT/no-api-test.json"
head -c 400 "$OUT/no-api-test.json" > "$OUT/no-api-test.txt"; echo >> "$OUT/no-api-test.txt"
echo "   -> $OUT/no-api-test.txt"
echo

# -----------------------------------------------------------------------------
# FINLANDE — interface WFS ouverte de Väylävirasto (Digiroad)
# On liste les couches disponibles pour repérer bacs, restrictions de tonnage
# et fermetures saisonnières.
# -----------------------------------------------------------------------------
echo "== FI : couches WFS Digiroad =="
curl -sS "https://avoinapi.vaylapilvi.fi/vaylatiedot/digiroad/wfs?service=wfs&request=GetCapabilities" \
  -o "$OUT/fi-wfs-brut.xml"

python3 - <<'PY' > "$OUT/fi-couches.txt" 2>&1
import re, io
try:
    s = io.open('_reco/fi-wfs-brut.xml', encoding='utf-8', errors='replace').read()
except Exception as e:
    print('ECHEC lecture WFS :', e); raise SystemExit
noms = re.findall(r'<(?:wfs:)?Name>([^<]+)</(?:wfs:)?Name>', s)
titres = re.findall(r'<(?:wfs:)?Title>([^<]+)</(?:wfs:)?Title>', s)
print('couches annoncées :', len(noms))
for n, t in zip(noms, titres):
    print(n, '|', t)
PY
echo "   -> $OUT/fi-couches.txt"
echo

# -----------------------------------------------------------------------------
# SUÈDE — l'Öppet API exige une clé, gratuite.
# -----------------------------------------------------------------------------
cat > "$OUT/se-a-faire.txt" <<'TXT'
SUÈDE — étape manuelle avant toute extraction

1. Créer un compte et une clé sur https://data.trafikverket.se
2. LIRE les conditions de licence acceptées à la création de la clé, et me
   dire ce qu'elles autorisent en matière de republication : c'est ce qui
   décidera si les données suédoises peuvent aller dans un dépôt public ou
   seulement être consultées.
3. Ne pas coller la clé dans le fil de discussion. Elle servira en local.

Une fois la clé en main, je fournirai la requête POST correspondante.
TXT
echo "== SE : voir $OUT/se-a-faire.txt =="
echo

echo "Terminé. Fichiers à recoller dans le fil :"
echo "  $OUT/no-types.txt"
echo "  $OUT/no-api-test.txt"
echo "  $OUT/fi-couches.txt"
ls -la "$OUT"
