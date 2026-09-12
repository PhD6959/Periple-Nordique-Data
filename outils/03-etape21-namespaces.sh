#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 21 : RECONNAISSANCE AVEC LES ESPACES DE NOMS
# =============================================================================
#
# CE QUI MANQUAIT : l'attribut « namespace » de l'élément QUERY. Sans lui, l'API
# ne cherche que dans l'espace par défaut et répond « ObjectType does not
# exists » — littéralement vrai, et trompeur pour qui l'ignore.
#
# QUATRE ESPACES, relevés dans le banc d'essai du portail :
#   road.trafficinfo    situations : restrictions, convois, déviations
#   road.weatherinfo    météo routière, dont la profondeur de gel
#   ferry.trafficinfo   liaisons et départs de bacs
#   vägdata.nvdb_dk_o   base routière suédoise, l'équivalent de la NVDB
#   vägdata.aggregat_o  agrégats de la base routière
#
# LA CLÉ EST LUE DANS ~/.trafikverket-key.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape21-namespaces.sh
# =============================================================================

set -u
OUT="_trv"; mkdir -p "$OUT"
CLE_FICHIER="$HOME/.trafikverket-key"
API="https://api.trafikinfo.trafikverket.se/v2/data.json"

[ -s "$CLE_FICHIER" ] || { echo "Clé absente : $CLE_FICHIER"; exit 1; }
CLE=$(cat "$CLE_FICHIER")

essayer () {
  local TYPE="$1" NS="$2"; shift 2
  echo "== $TYPE  ($NS) =="
  for V in "$@"; do
    local FIC="$OUT/ns-$TYPE-$V.json"
    local REQ="<REQUEST><LOGIN authenticationkey=\"$CLE\" /><QUERY objecttype=\"$TYPE\" namespace=\"$NS\" schemaversion=\"$V\" limit=\"5\"></QUERY></REQUEST>"
    curl -sS -X POST -H "Content-Type: text/xml" -d "$REQ" "$API" -o "$FIC"
    local ETAT
    ETAT=$(python3 -c "
import json,io
try:
    d=json.load(io.open('$FIC',encoding='utf-8'))
except Exception:
    print('ILLISIBLE|'); raise SystemExit
res=(d.get('RESPONSE') or {}).get('RESULT',[{}])[0]
if 'ERROR' in res:
    print('REFUS|'+str(res['ERROR'].get('MESSAGE'))[:120]); raise SystemExit
cles=[k for k in res if k!='INFO']
print('OK|%s|%d' % (cles[0] if cles else '?', len(res[cles[0]]) if cles else 0))")
    local CODE=${ETAT%%|*}
    local R=${ETAT#*|}
    if [ "$CODE" = "OK" ]; then
      echo "   schemaversion $V ACCEPTÉ — ${R%%|*}, ${R##*|} enregistrement(s)"
      echo "$TYPE|$NS|$V" >> "$OUT/ns-ok.txt"
      return 0
    fi
    echo "   $V : $CODE ${R:0:100}"
    rm -f "$FIC"
  done
  return 1
}

: > "$OUT/ns-ok.txt"

# --- ce qui décide du passage en avril
essayer Situation              road.trafficinfo   1.5 1.4 1.3 1.2 1.1 1.0
essayer RoadConditionOverview  road.trafficinfo   1.0 1.1 1.2
essayer FrostDepthMeasurepoint road.weatherinfo   1.0 1.1 2.0
essayer WeatherStation         road.weatherinfo   1.0 1.1 2.0
essayer FerryRoute             ferry.trafficinfo  1.2 1.1 1.0
essayer FerryAnnouncement      ferry.trafficinfo  1.2 1.1 1.0

python3 - <<'PY' > "$OUT/PROFIL21.txt" 2>&1
import json, io, os, collections

OUT = '_trv'
f = os.path.join(OUT, 'ns-ok.txt')
lignes = [l.strip() for l in io.open(f, encoding='utf-8')] if os.path.exists(f) else []
lignes = [l for l in lignes if l]

print('=== types accessibles ===')
for l in lignes:
    t, ns, v = l.split('|')
    print('  %-24s %-20s schemaversion %s' % (t, ns, v))
if not lignes:
    print('  aucun')

for l in lignes:
    t, ns, v = l.split('|')
    c = os.path.join(OUT, 'ns-%s-%s.json' % (t, v))
    if not os.path.exists(c):
        continue
    res = json.load(io.open(c, encoding='utf-8'))['RESPONSE']['RESULT'][0]
    cle = [k for k in res if k != 'INFO'][0]
    lot = res[cle]
    print('')
    print('=' * 70)
    print('%s — %d enregistrement(s)' % (t, len(lot)))
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
        print('    %-26s %s' % (k, json.dumps(ex[k], ensure_ascii=False)[:130]))

    if t == 'Situation':
        cats = collections.Counter()
        for s in lot:
            for dev in (s.get('Deviation') or []):
                cats[dev.get('MessageType') or dev.get('MessageCode') or '?'] += 1
        print('')
        print('  CATÉGORIES DE DÉVIATION sur cet échantillon : %s' % dict(cats))
        print('  (on cherche Bärighetsnedsättning — restriction de portance —,')
        print('   Kolonnkörning — conduite en convoi — et Avvikande färjetider.)')
PY

echo
echo "=========================================="
cat "$OUT/PROFIL21.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL21.txt — la clé n'y figure pas."
