#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 20 : VERSIONS DE SCHÉMA DES TYPES RESTANTS
# =============================================================================
#
# À l'étape 19, trois types sur six ont été acceptés. Les trois autres — dont
# Situation, le plus important — ont été refusés sans que je puisse savoir
# pourquoi : mon script supprimait la réponse d'erreur après échec.
#
# Or l'API indique dans son message la version qu'elle attend. Ce script la lit
# au lieu de la jeter, et la réemploie immédiatement.
#
# MÉTHODE
#   1. Une requête volontairement fautive — schemaversion 0.0 — pour provoquer
#      un message d'erreur qui nomme les versions acceptées.
#   2. Extraction des numéros cités dans ce message.
#   3. Nouvel essai avec chacun d'eux.
#
# Si le message ne nomme aucune version, le script balaie un éventail plus large
# que l'étape 19.
#
# LA CLÉ EST LUE DANS ~/.trafikverket-key, jamais écrite ici.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape20-versions.sh
# =============================================================================

set -u
OUT="_trv"; mkdir -p "$OUT"
CLE_FICHIER="$HOME/.trafikverket-key"
API="https://api.trafikinfo.trafikverket.se/v2/data.json"

[ -s "$CLE_FICHIER" ] || { echo "Clé absente : $CLE_FICHIER"; exit 1; }
CLE=$(cat "$CLE_FICHIER")

interroger () {
  local TYPE="$1" V="$2" FIC="$3"
  local REQ="<REQUEST><LOGIN authenticationkey=\"$CLE\" /><QUERY objecttype=\"$TYPE\" schemaversion=\"$V\" limit=\"5\"></QUERY></REQUEST>"
  curl -sS -X POST -H "Content-Type: text/xml" -d "$REQ" "$API" -o "$FIC"
}

chercher () {
  local TYPE="$1"
  echo "== $TYPE =="

  # 1. provoquer le message d'erreur, qui nomme les versions acceptées
  interroger "$TYPE" "0.0" "$OUT/sonde-$TYPE.json"
  local MSG
  MSG=$(python3 -c "
import json,io
try:
    d=json.load(io.open('$OUT/sonde-$TYPE.json',encoding='utf-8'))
    res=(d.get('RESPONSE') or {}).get('RESULT',[{}])[0]
    print(str((res.get('ERROR') or {}).get('MESSAGE',''))[:300])
except Exception as e:
    print('')")
  echo "   message : ${MSG:-aucun}"

  # 2. numéros de version cités dans le message
  local CANDIDATES
  CANDIDATES=$(python3 -c "
import re
m='''$MSG'''
v=sorted(set(re.findall(r'\b(\d+\.\d+)\b', m)), key=lambda x:[int(p) for p in x.split('.')], reverse=True)
v=[x for x in v if x!='0.0']
print(' '.join(v))")

  if [ -z "$CANDIDATES" ]; then
    echo "   aucune version nommée — balayage large"
    CANDIDATES="2.1 2.0 1.9 1.8 1.7 1.6 1.5 1.4 1.3 1.2 1.1 1.0"
  else
    echo "   versions nommées : $CANDIDATES"
  fi

  # 3. essayer chacune
  for V in $CANDIDATES; do
    interroger "$TYPE" "$V" "$OUT/$TYPE-$V.json"
    local ETAT
    ETAT=$(python3 -c "
import json,io
try:
    d=json.load(io.open('$OUT/$TYPE-$V.json',encoding='utf-8'))
except Exception as e:
    print('ILLISIBLE'); raise SystemExit
res=(d.get('RESPONSE') or {}).get('RESULT',[{}])[0]
if 'ERROR' in res:
    print('REFUS'); raise SystemExit
cles=[k for k in res if k!='INFO']
print('OK|%s|%d' % (cles[0] if cles else '?', len(res[cles[0]]) if cles else 0))")
    if [ "${ETAT%%|*}" = "OK" ]; then
      local R=${ETAT#*|}
      echo "   -> schemaversion $V ACCEPTÉ : ${R%%|*}, ${R##*|} enregistrement(s)"
      echo "$TYPE|$V" >> "$OUT/versions-ok2.txt"
      return 0
    fi
    rm -f "$OUT/$TYPE-$V.json"
  done
  echo "   aucune version acceptée"
  return 1
}

: > "$OUT/versions-ok2.txt"
chercher Situation
chercher RoadConditionOverview
chercher WeatherStation
chercher FerryRoute
chercher FerryAnnouncement

python3 - <<'PY' > "$OUT/PROFIL20.txt" 2>&1
import json, io, os, collections

OUT = '_trv'
lignes = []
f = os.path.join(OUT, 'versions-ok2.txt')
if os.path.exists(f):
    lignes = [l.strip() for l in io.open(f, encoding='utf-8') if l.strip()]

print('=== versions trouvées à cette passe ===')
for l in lignes:
    print('  ' + l.replace('|', '  schemaversion '))
if not lignes:
    print('  aucune')

for l in lignes:
    typ, v = l.split('|')
    c = os.path.join(OUT, '%s-%s.json' % (typ, v))
    if not os.path.exists(c):
        continue
    res = json.load(io.open(c, encoding='utf-8'))['RESPONSE']['RESULT'][0]
    cle = [k for k in res if k != 'INFO'][0]
    lot = res[cle]
    print('')
    print('=' * 70)
    print('%s (schemaversion %s) — %d enregistrement(s)' % (typ, v, len(lot)))
    if not lot:
        print('  aucune donnée aujourd\'hui — attendu pour un jeu saisonnier')
        continue
    champs = collections.Counter()
    for e in lot:
        for k in e:
            champs[k] += 1
    print('  champs : %s' % ', '.join(sorted(champs)))
    ex = lot[0]
    for k in sorted(ex):
        print('    %-26s %s' % (k, json.dumps(ex[k], ensure_ascii=False)[:120]))

    if typ == 'Situation':
        cats = collections.Counter()
        for s in lot:
            for dev in (s.get('Deviation') or []):
                cats[dev.get('MessageType') or dev.get('MessageCode') or '?'] += 1
        print('  catégories de déviation sur cet échantillon : %s' % dict(cats))
PY

echo
echo "=========================================="
cat "$OUT/PROFIL20.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL20.txt — la clé n'y figure pas."
