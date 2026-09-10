#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 2 : EXTRACTION — cols/fermetures et ferries (NO + FI)
# =============================================================================
#
# Chemin d'API corrigé : la V4 se trouve sous /vegobjekter/api/v4/, et non
# sous /vegobjekter/v4/ comme je l'avais supposé à l'étape 1.
#
# Le script compte d'abord, puis télécharge en paginant. Chaque type produit
# un fichier JSON brut et une ligne de résumé.
#
# UTILISATION
#   cd ~/Downloads
#   bash 03-etape2-extraction.sh
#
# ENSUITE : me recoller le contenu de _extract/RESUME.txt.
#   Les fichiers de moins de 400 Ko peuvent être collés directement dans le fil.
#   Au-delà, les déposer dans le dépôt Periple-Nordique-Data sous _brut/ et
#   pousser : j'y ai accès par raw.githubusercontent.com.
# =============================================================================

set -u
OUT="_extract"
mkdir -p "$OUT"
CLIENT="PeripleNordique2027"
BASE="https://nvdbapiles.atlas.vegvesen.no/vegobjekter/api/v4/vegobjekter"
RES="$OUT/RESUME.txt"
: > "$RES"

log() { echo "$1"; echo "$1" >> "$RES"; }

log "Extraction du $(date '+%Y-%m-%d %H:%M')"
log ""

# -----------------------------------------------------------------------------
# NORVÈGE — NVDB API Les V4
# 107  Værutsatt veg      : tronçons exposés, horaires d'ouverture limités
# 1005 Vinterberedskap    : niveau de veille hivernale, par période
# 607  Vegsperring        : barrière physique
# 883  Skredutsatt veg    : tronçons périodiquement fermés par avalanche
# 770  Ferjesamband       : liaison de bac, deux points d'accostage ou plus
# 64   Ferjekai           : quai de bac
# -----------------------------------------------------------------------------
extraire_no () {
  local ID="$1" NOM="$2" FIC="$OUT/no-$3.json"

  # comptage préalable, pour ne pas lancer un téléchargement à l'aveugle
  local N
  N=$(curl -sS -H "Accept: application/json" -H "X-Client: $CLIENT" \
      "$BASE/$ID?antall=1&inkluderAntall=true" \
      | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); m=d.get('metadata',{})
    print(m.get('antall', m.get('returnert','?')))
except Exception as e:
    print('erreur')" 2>/dev/null)
  log "NO $ID $NOM : $N objet(s) annoncé(s)"
  if [ "$N" = "erreur" ] || [ "$N" = "" ]; then
    log "   -> échec du comptage, type ignoré"
    return
  fi

  # téléchargement paginé, géométrie en WGS 84 (srid 4326)
  local URL="$BASE/$ID?antall=1000&srid=4326&inkluder=metadata,egenskaper,geometri,lokasjon"
  local PAGE=1
  : > "$OUT/tmp-pages.txt"
  while [ -n "$URL" ] && [ "$PAGE" -le 30 ]; do
    curl -sS -H "Accept: application/json" -H "X-Client: $CLIENT" "$URL" -o "$OUT/tmp-page.json"
    cat "$OUT/tmp-page.json" >> "$OUT/tmp-pages.txt"; echo >> "$OUT/tmp-pages.txt"
    URL=$(python3 -c "import sys,json
try:
    d=json.load(open('$OUT/tmp-page.json'))
    n=d.get('metadata',{}).get('neste',{})
    r=d.get('objekter', d.get('vegobjekter', []))
    print(n.get('href','') if r else '')
except Exception:
    print('')" 2>/dev/null)
    PAGE=$((PAGE+1))
  done

  # fusion des pages en une seule liste d'objets
  python3 - "$OUT/tmp-pages.txt" "$FIC" <<'PY'
import sys, json, io
src, dst = sys.argv[1], sys.argv[2]
objets = []
for ligne in io.open(src, encoding='utf-8'):
    ligne = ligne.strip()
    if not ligne:
        continue
    try:
        d = json.loads(ligne)
    except Exception:
        continue
    objets += d.get('objekter', d.get('vegobjekter', []))
json.dump(objets, io.open(dst, 'w', encoding='utf-8'), ensure_ascii=False)
print('   -> %d objet(s) écrit(s) dans %s' % (len(objets), dst))
PY
  tail -1 "$RES" >/dev/null
  log "   -> $(python3 -c "import json,io;print(len(json.load(io.open('$FIC',encoding='utf-8'))))" 2>/dev/null || echo '?') objet(s), $(du -h "$FIC" 2>/dev/null | cut -f1)"
  rm -f "$OUT/tmp-page.json" "$OUT/tmp-pages.txt"
}

log "=== NORVÈGE — cols et fermetures ==="
extraire_no 107  "Værutsatt veg"    "107-vaerutsatt-veg"
extraire_no 1005 "Vinterberedskap"  "1005-vinterberedskap"
extraire_no 607  "Vegsperring"      "607-vegsperring"
extraire_no 883  "Skredutsatt veg"  "883-skredutsatt-veg"
log ""
log "=== NORVÈGE — ferries ==="
extraire_no 770  "Ferjesamband"     "770-ferjesamband"
extraire_no 64   "Ferjekai"         "64-ferjekai"
log ""

# -----------------------------------------------------------------------------
# FINLANDE — WFS ouvert de Väylävirasto (Digiroad), sortie GeoJSON directe
# dr_kelirikko : restrictions de dégel — c'est la rubrique 10, mais la couche
# est là et l'extraction ne coûte rien.
# -----------------------------------------------------------------------------
log "=== FINLANDE — Digiroad WFS ==="
FIWFS="https://avoinapi.vaylapilvi.fi/vaylatiedot/digiroad/wfs"
curl -sS "$FIWFS?service=WFS&version=2.0.0&request=GetFeature&typeNames=digiroad:dr_kelirikko&outputFormat=application/json&srsName=EPSG:4326&count=5000" \
  -o "$OUT/fi-kelirikko.geojson"
log "FI kelirikko : $(python3 -c "import json,io
try:
    d=json.load(io.open('$OUT/fi-kelirikko.geojson',encoding='utf-8'))
    print(str(len(d.get('features',[])))+' entité(s)')
except Exception as e:
    print('échec : '+str(e)[:80])" 2>/dev/null), $(du -h "$OUT/fi-kelirikko.geojson" 2>/dev/null | cut -f1)"

# échantillon de propriétés, pour que je cale le schéma
python3 - <<'PY' >> "$RES" 2>&1
import json, io
try:
    d = json.load(io.open('_extract/fi-kelirikko.geojson', encoding='utf-8'))
    f = (d.get('features') or [None])[0]
    if f:
        print('   propriétés kelirikko :', ', '.join(sorted(f.get('properties', {}).keys())))
except Exception as e:
    print('   échantillon indisponible :', str(e)[:120])
PY

log ""
log "=== Tailles produites ==="
ls -la "$OUT" | awk '{print $5, $9}' >> "$RES"

echo
echo "=========================================="
cat "$RES"
echo "=========================================="
echo "À me transmettre : le contenu de $OUT/RESUME.txt"
