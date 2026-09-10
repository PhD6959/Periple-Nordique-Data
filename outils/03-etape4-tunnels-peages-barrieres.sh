#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 4 : SECONDE PASSE NVDB — tunnels, péages, barrières
# =============================================================================
#
#   581  Tunnel        -> rubrique 5  « Tunnels appelant une décision »
#   45   Bomstasjon    -> rubrique 9  « Péages et badge »
#   607  Vegsperring   -> rubrique 12 « Pistes carrossables et barrières »
#
# Extraction et profil en une seule passe : la sortie contient les décomptes,
# la liste des propriétés avec fréquence et exemple, et deux objets complets.
# C'est tout ce qu'il me faut pour écrire la conversion.
#
# PAGINATION CORRIGÉE : à l'étape 2, la boucle s'était arrêtée à 24 000 objets
# sur 27 788 pour le type 607. On suit désormais le jeton « start » renvoyé par
# l'API, et on s'arrête seulement quand une page revient incomplète.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape4-tunnels-peages-barrieres.sh
# =============================================================================

set -u
OUT="_extract4"; mkdir -p "$OUT"
CLIENT="PeripleNordique2027"
BASE="https://nvdbapiles.atlas.vegvesen.no/vegobjekter/api/v4/vegobjekter"
RES="$OUT/PROFIL4.txt"; : > "$RES"
PAS=1000

log() { echo "$1"; echo "$1" >> "$RES"; }

extraire () {
  local ID="$1" NOM="$2" SLUG="$3" FIC="$OUT/no-$3.json"
  log ""
  log "=== NO $ID $NOM ==="

  local URL="$BASE/$ID?antall=$PAS&srid=4326&inkluder=metadata,egenskaper,geometri,lokasjon&inkluderAntall=true"
  local PAGE=0 TOTAL=0
  : > "$OUT/tmp-$SLUG.ndjson"
  while [ -n "$URL" ] && [ "$PAGE" -lt 60 ]; do
    curl -sS -H "Accept: application/json" -H "X-Client: $CLIENT" "$URL" -o "$OUT/tmp-page.json"
    local INFO
    INFO=$(python3 -c "
import json,io
try:
    d=json.load(io.open('$OUT/tmp-page.json',encoding='utf-8'))
except Exception as e:
    print('ERREUR|' + str(e)[:80] + '|'); raise SystemExit
r=d.get('objekter', d.get('vegobjekter', []))
m=d.get('metadata',{}) or {}
suiv=(m.get('neste') or {}).get('href','') if r else ''
print('%d|%s|%s' % (len(r), suiv, m.get('antall','?')))")
    local N=${INFO%%|*}
    local RESTE=${INFO#*|}
    local SUIV=${RESTE%%|*}
    local ANNONCE=${RESTE##*|}
    [ "$N" = "ERREUR" ] && { log "   échec : $RESTE"; return; }
    python3 -c "
import json,io
d=json.load(io.open('$OUT/tmp-page.json',encoding='utf-8'))
for o in d.get('objekter', d.get('vegobjekter', [])):
    io.open('$OUT/tmp-$SLUG.ndjson','a',encoding='utf-8').write(json.dumps(o,ensure_ascii=False)+'\n')"
    TOTAL=$((TOTAL+N))
    PAGE=$((PAGE+1))
    [ "$PAGE" -eq 1 ] && log "   annoncés : $ANNONCE"
    [ "$N" -lt "$PAS" ] && break
    URL="$SUIV"
  done
  log "   récupérés : $TOTAL en $PAGE page(s)"

  python3 - "$OUT/tmp-$SLUG.ndjson" "$FIC" "$NOM" >> "$RES" 2>&1 <<'PY'
import sys, json, io, collections
src, dst, titre = sys.argv[1], sys.argv[2], sys.argv[3]
objets = [json.loads(l) for l in io.open(src, encoding='utf-8') if l.strip()]
json.dump(objets, io.open(dst, 'w', encoding='utf-8'), ensure_ascii=False)

def ap(v, n=52):
    s = str(v).replace('\n', ' ')
    return s[:n] + ('…' if len(s) > n else '')

props = {}
for o in objets:
    for e in (o.get('egenskaper') or []):
        k = (e.get('id'), e.get('navn'), e.get('egenskapstype'))
        if k not in props:
            props[k] = [0, e.get('verdi'), set()]
        props[k][0] += 1
        if e.get('egenskapstype') == 'Tekstenum' and len(props[k][2]) < 6:
            props[k][2].add(str(e.get('verdi')))
print('   propriétés (id | nom | type | présence | exemple / valeurs) :')
for (eid, navn, etype), (n, ex, vals) in sorted(props.items(), key=lambda x: -x[1][0]):
    suite = ', '.join(sorted(vals)) if vals else ap(ex)
    print('     %-6s | %-34s | %-11s | %6d | %s' % (eid, ap(navn, 34), ap(etype, 11), n, ap(suite, 60)))

g = collections.Counter(str((o.get('geometri') or {}).get('wkt', '')).split('(')[0].strip()[:18] for o in objets)
print('   géométries :', dict(g))
print('   srid :', dict(collections.Counter((o.get('geometri') or {}).get('srid') for o in objets)))
for o in objets[:2]:
    o = dict(o); gg = dict(o.get('geometri') or {})
    if 'wkt' in gg:
        gg['wkt'] = ap(gg['wkt'], 90)
    o['geometri'] = gg
    o.pop('lokasjon', None)
    print('   échantillon :', json.dumps(o, ensure_ascii=False)[:900])
PY
  rm -f "$OUT/tmp-page.json" "$OUT/tmp-$SLUG.ndjson"
}

log "Seconde passe NVDB du $(date '+%Y-%m-%d %H:%M')"
extraire 581 "Tunnel"      "581-tunnel"
extraire 45  "Bomstasjon"  "45-bomstasjon"
extraire 607 "Vegsperring" "607-vegsperring"

log ""
log "=== tailles ==="
ls -la "$OUT" | awk 'NR>3 {print $5, $9}' >> "$RES"

echo
echo "=========================================="
cat "$RES"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL4.txt"
