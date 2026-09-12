#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 19 : RECONNAISSANCE DE L'ÖPPET API DE TRAFIKVERKET
# =============================================================================
#
# But : éprouver la clé et inventorier ce que l'API expose, pour être prêt en
# mars 2027. Aujourd'hui, en septembre, les jeux saisonniers — restrictions de
# dégel, fermetures hivernales — seront vraisemblablement vides. Ce n'est pas
# un échec : l'inventaire vaut pour lui-même.
#
# LA CLÉ NE FIGURE PAS DANS CE SCRIPT. Elle est lue dans un fichier :
#
#   printf '%s' 'TA_CLE_ICI' > ~/.trafikverket-key
#   chmod 600 ~/.trafikverket-key
#
# Ne jamais coller la clé dans un script versionné : ce dossier finira dans un
# dépôt, et le dépôt applicatif est privé mais le site publié est public.
#
# FORME DE L'API — vérifiée le 12/09/2026 sur la documentation Trafiklab :
# requête POST d'un document XML vers /v2/data.json. Le numéro de version du
# schéma est obligatoire et diffère selon le type d'objet ; le script essaie
# plusieurs versions et retient la première acceptée.
#
# Coordonnées : SWEREF 99 TM, mais tout est aussi publié en WGS 84.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape19-trafikverket.sh
# =============================================================================

set -u
OUT="_trv"; mkdir -p "$OUT"
CLE_FICHIER="$HOME/.trafikverket-key"
API="https://api.trafikinfo.trafikverket.se/v2/data.json"

if [ ! -s "$CLE_FICHIER" ]; then
  echo "Clé absente. Créer le fichier :"
  echo "  printf '%s' 'TA_CLE' > $CLE_FICHIER && chmod 600 $CLE_FICHIER"
  exit 1
fi
CLE=$(cat "$CLE_FICHIER")

essayer () {
  local TYPE="$1"; shift
  echo "== $TYPE =="
  for V in "$@"; do
    local REQ="<REQUEST><LOGIN authenticationkey=\"$CLE\" /><QUERY objecttype=\"$TYPE\" schemaversion=\"$V\" limit=\"5\"></QUERY></REQUEST>"
    curl -sS -X POST -H "Content-Type: text/xml" -d "$REQ" "$API" -o "$OUT/$TYPE-$V.json"
    local ETAT
    ETAT=$(python3 -c "
import json,io,sys
try:
    d=json.load(io.open('$OUT/$TYPE-$V.json',encoding='utf-8'))
except Exception as e:
    print('ILLISIBLE|'+str(e)[:60]); raise SystemExit
r=(d.get('RESPONSE') or {})
if 'RESULT' not in r:
    print('ERREUR|'+json.dumps(d,ensure_ascii=False)[:150]); raise SystemExit
res=r['RESULT'][0]
if 'ERROR' in res:
    print('REFUS|'+str(res['ERROR'].get('MESSAGE'))[:110]); raise SystemExit
cles=[k for k in res if k != 'INFO']
n=len(res[cles[0]]) if cles else 0
print('OK|%s|%d' % (cles[0] if cles else '?', n))")
    local CODE=${ETAT%%|*}
    local RESTE=${ETAT#*|}
    if [ "$CODE" = "OK" ]; then
      echo "   schemaversion $V accepté — ${RESTE%%|*}, ${RESTE##*|} enregistrement(s)"
      echo "$TYPE|$V" >> "$OUT/versions-ok.txt"
      return 0
    else
      echo "   schemaversion $V : $CODE ${RESTE:0:90}"
      rm -f "$OUT/$TYPE-$V.json"
    fi
  done
  echo "   aucune version acceptée"
  return 1
}

: > "$OUT/versions-ok.txt"
essayer RoadCondition          1.2 1.1 1.0 2.0
essayer RoadConditionOverview  1.0 1.1
essayer Situation              1.5 1.4 1.3 1.2
essayer WeatherStation         1.0 1.1 2.0 2.1
essayer WeatherMeasurepoint    2.0 2.1 1.0
essayer Camera                 1.0 1.1

python3 - <<'PY' > "$OUT/PROFIL19.txt" 2>&1
import json, io, os, collections

OUT = '_trv'
print('=== versions acceptées ===')
lignes = []
if os.path.exists(os.path.join(OUT, 'versions-ok.txt')):
    lignes = [l.strip() for l in io.open(os.path.join(OUT, 'versions-ok.txt'), encoding='utf-8') if l.strip()]
for l in lignes:
    print('  ' + l.replace('|', '  schemaversion '))
if not lignes:
    print('  aucune — la clé est peut-être invalide, voir les messages ci-dessus')

for l in lignes:
    typ, v = l.split('|')
    c = os.path.join(OUT, '%s-%s.json' % (typ, v))
    if not os.path.exists(c):
        continue
    d = json.load(io.open(c, encoding='utf-8'))
    res = d['RESPONSE']['RESULT'][0]
    cle = [k for k in res if k != 'INFO'][0]
    lot = res[cle]
    print('')
    print('=' * 70)
    print('%s (schemaversion %s) — %d enregistrement(s) sur la page' % (typ, v, len(lot)))
    if not lot:
        print('  AUCUNE DONNÉE AUJOURD\'HUI. Pour un jeu saisonnier, c\'est attendu en septembre.')
        continue
    champs = collections.Counter()
    for e in lot:
        for k in e:
            champs[k] += 1
    print('  champs : %s' % ', '.join(sorted(champs)))
    ex = lot[0]
    for k in sorted(ex):
        val = json.dumps(ex[k], ensure_ascii=False)
        print('    %-28s %s' % (k, val[:110]))

# Situation : quelles catégories de déviation existent aujourd'hui
for l in lignes:
    typ, v = l.split('|')
    if typ != 'Situation':
        continue
    c = os.path.join(OUT, '%s-%s.json' % (typ, v))
    d = json.load(io.open(c, encoding='utf-8'))
    lot = d['RESPONSE']['RESULT'][0].get('Situation', [])
    cats = collections.Counter()
    for s in lot:
        for dev in (s.get('Deviation') or []):
            cats[dev.get('MessageType') or dev.get('MessageCode') or '?'] += 1
    if cats:
        print('')
        print('  catégories de déviation vues sur cet échantillon : %s' % dict(cats))
PY

echo
echo "=========================================="
cat "$OUT/PROFIL19.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL19.txt"
echo "La clé n'y figure pas."
