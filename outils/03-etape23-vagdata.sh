#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 23 : BASE ROUTIÈRE SUÉDOISE — RECONNAISSANCE
# =============================================================================
#
# Le namespace vägdata.nvdb_dk_o expose la base routière nationale suédoise,
# équivalent de la NVDB norvégienne dont on a tiré ce matin les cols, ferries,
# tunnels, péages et barrières.
#
# NEUF TYPES CIBLÉS, par ordre d'intérêt pour un fourgon de 3,20 m et 3,5 t :
#   Höjdhinder_upp_till_45_dm   obstacles en hauteur jusqu'à 4,5 m — DÉCISIF
#   Bärighet                     classe de portance du tronçon
#   BegränsadBruttovikt          poids brut limité
#   BegränsadFordonsbredd        largeur limitée
#   BegränsadFordonslängd        longueur limitée
#   Färjeled                     liaisons de bacs, vues comme réseau routier
#   Rastplatser                  aires de repos          (vägdata.vis_dk_o)
#   Vägnummer                    numérotation des routes
#   Väghinder                    obstacles sur la voie
#
# On ne sait pas encore quelles versions de schéma s'appliquent. Le script en
# essaie plusieurs et, pour chaque type accepté, compte les objets et montre
# leurs champs. C'est une reconnaissance, aucune donnée n'est convertie.
#
# ATTENTION AU VOLUME : la base couvre tout le réseau suédois. On demande cinq
# objets par type, et on interroge le compte total séparément.
#
# LA CLÉ EST LUE DANS ~/.trafikverket-key.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape23-vagdata.sh
# =============================================================================

set -u
OUT="_vagdata"; mkdir -p "$OUT"
CLE_FICHIER="$HOME/.trafikverket-key"
API="https://api.trafikinfo.trafikverket.se/v2/data.json"

[ -s "$CLE_FICHIER" ] || { echo "Clé absente : $CLE_FICHIER"; exit 1; }
CLE=$(cat "$CLE_FICHIER")

essayer () {
  local TYPE="$1" NS="$2"; shift 2
  echo "== $TYPE ($NS) =="
  for V in "$@"; do
    local FIC="$OUT/$TYPE-$V.json"
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
    print('REFUS|'+str(res['ERROR'].get('MESSAGE'))[:100]); raise SystemExit
cles=[k for k in res if k!='INFO']
print('OK|%s|%d' % (cles[0] if cles else '?', len(res[cles[0]]) if cles else 0))")
    local CODE=${ETAT%%|*} R=${ETAT#*|}
    if [ "$CODE" = "OK" ]; then
      echo "   schemaversion $V ACCEPTÉ — ${R##*|} objet(s) sur l'échantillon"
      echo "$TYPE|$NS|$V" >> "$OUT/ok.txt"
      return 0
    fi
    echo "   $V : $CODE ${R:0:80}"
    rm -f "$FIC"
  done
  echo "   aucune version acceptée"
  return 1
}

: > "$OUT/ok.txt"
essayer Höjdhinder_upp_till_45_dm  vägdata.nvdb_dk_o  1.2 1.1 1.0 1.3
essayer Bärighet                   vägdata.nvdb_dk_o  1.2 1.1 1.0 1.3
essayer BegränsadBruttovikt        vägdata.nvdb_dk_o  1.2 1.1 1.0
essayer BegränsadFordonsbredd      vägdata.nvdb_dk_o  1.2 1.1 1.0
essayer BegränsadFordonslängd      vägdata.nvdb_dk_o  1.2 1.1 1.0
essayer Färjeled                   vägdata.nvdb_dk_o  1.2 1.1 1.0
essayer Väghinder                  vägdata.nvdb_dk_o  1.2 1.1 1.0
essayer Vägnummer                  vägdata.nvdb_dk_o  1.2 1.1 1.0
essayer Rastplatser                vägdata.vis_dk_o   1.2 1.1 1.0

python3 - <<'PY' > "$OUT/PROFIL23.txt" 2>&1
import json, io, os, collections

OUT = '_vagdata'
f = os.path.join(OUT, 'ok.txt')
lignes = [l.strip() for l in io.open(f, encoding='utf-8')] if os.path.exists(f) else []
lignes = [l for l in lignes if l]

print('=== types accessibles ===')
for l in lignes:
    t, ns, v = l.split('|')
    print('  %-28s %-20s schemaversion %s' % (t, ns, v))
if not lignes:
    print('  aucun')

for l in lignes:
    t, ns, v = l.split('|')
    c = os.path.join(OUT, '%s-%s.json' % (t, v))
    if not os.path.exists(c):
        continue
    res = json.load(io.open(c, encoding='utf-8'))['RESPONSE']['RESULT'][0]
    cle = [k for k in res if k != 'INFO'][0]
    lot = res[cle]
    print('')
    print('=' * 70)
    print('%s — %d objet(s) sur l\'échantillon' % (t, len(lot)))
    if not lot:
        print('  aucune donnée'); continue
    ch = collections.Counter()
    for e in lot:
        for k in e:
            ch[k] += 1
    print('  champs : %s' % ', '.join(sorted(ch)))
    ex = max(lot, key=len)
    for k in sorted(ex):
        print('    %-30s %s' % (k, json.dumps(ex[k], ensure_ascii=False)[:150]))
PY

echo
echo "=========================================="
cat "$OUT/PROFIL23.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL23.txt — la clé n'y figure pas."
