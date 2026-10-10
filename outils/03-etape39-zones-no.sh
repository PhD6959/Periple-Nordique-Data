#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 39 : ZONES PROTÉGÉES NORVÉGIENNES — NOUVELLE TENTATIVE
# =============================================================================
#
# Le 12 septembre 2026, le service Naturvernområder de Miljødirektoratet
# répondait « Application Error : Could not access any server machines » sur les
# deux couches qui portent les zones — naturvern_omrade et
# naturvern_klasser_omrade — alors que les autres couches du MÊME service
# fonctionnaient. Panne partielle, constatée deux fois à plusieurs minutes
# d'intervalle.
#
# Ce script reprend l'essai, et pousse plus loin si la panne persiste :
#   1. les deux couches de zones, sur le service ArcGIS ;
#   2. la couche 4, foreslatt_naturvern_omrade, non essayée jusqu'ici ;
#   3. la couche 3 des limites, pour vérifier si ses champs portent un
#      rattachement à la zone qu'elles bordent — l'échantillon de 200 n'en
#      montrait aucun, mais il était partiel ;
#   4. Geonorge, qui redistribue les données de Naturbase.
#
# Rien n'est converti ici : c'est une reconnaissance. Si une couche répond, le
# script dit combien d'entités, quels champs et quelle géométrie.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape39-zones-no.sh
# =============================================================================

set -u
OUT="_parcs"; mkdir -p "$OUT"
MDIR="https://kart.miljodirektoratet.no/arcgis/rest/services/vern/MapServer"

# --- combien d'entités une couche annonce-t-elle ?
compter () {
  local N="$1"
  printf '  couche %-2s compte : ' "$N"
  curl -sS -m 45 -G "$MDIR/$N/query" \
    --data-urlencode "where=1=1" --data-urlencode "returnCountOnly=true" \
    --data-urlencode "f=json" -o "$OUT/n$N-compte.json" 2>/dev/null
  python3 -c "
import json,io,re
try:
    t=io.open('$OUT/n$N-compte.json',encoding='utf-8',errors='replace').read()
except Exception:
    print('illisible'); raise SystemExit
if t.lstrip().startswith('<'):
    m=re.search(r'Application Error.{0,120}', re.sub(r'<[^>]+>',' ',t))
    print('SERVICE INDISPONIBLE' + (' — ' + re.sub(r'\s+',' ',m.group(0))[:70] if m else '')); raise SystemExit
try:
    d=json.loads(t)
except Exception:
    print('réponse non JSON'); raise SystemExit
if 'error' in d:
    print('refus : %s' % str(d['error'].get('message'))[:60]); raise SystemExit
print(d.get('count','?'))"
}

# --- un échantillon, pour voir les champs
sonder () {
  local N="$1" NB="${2:-50}"
  local FIC="$OUT/n$N-ech.json"
  curl -sS -m 90 -G "$MDIR/$N/query" \
    --data-urlencode "where=1=1" --data-urlencode "outFields=*" \
    --data-urlencode "returnGeometry=true" --data-urlencode "outSR=4326" \
    --data-urlencode "f=geojson" --data-urlencode "resultRecordCount=$NB" \
    -o "$FIC" 2>/dev/null
  python3 -c "
import json,io,collections,re
try:
    t=io.open('$FIC',encoding='utf-8',errors='replace').read()
except Exception:
    print('    illisible'); raise SystemExit
if t.lstrip().startswith('<'):
    print('    page d\'erreur HTML — service indisponible'); raise SystemExit
try:
    d=json.loads(t)
except Exception:
    print('    réponse non JSON'); raise SystemExit
if 'error' in d:
    print('    refus : %s' % str(d['error'].get('message'))[:70]); raise SystemExit
f=d.get('features',[])
print('    %d entité(s)' % len(f))
if not f: raise SystemExit
print('    géométries : %s' % dict(collections.Counter(x.get('geometry',{}).get('type') for x in f)))
p=f[0].get('properties',{})
print('    champs : %s' % ', '.join(sorted(p))[:300])
# un champ de nom ou de rattachement ?
noms=[k for k in p if re.search(r'navn|name|omrade|vern|id$', k, re.I)]
print('    champs de nom ou de rattachement : %s' % (noms[:8] or 'AUCUN'))
for k in sorted(p)[:8]:
    print('      %-30s %s' % (k, str(p[k])[:56]))"
}

echo "== service Naturvernområder — les couches de zones =="
for N in 0 1 4; do
  compter "$N"
  sonder "$N" 50
  sleep 2
done

echo
echo "== couche 3, les limites : portent-elles un rattachement ? =="
compter 3
sonder 3 200

echo
echo "== Geonorge, qui redistribue Naturbase =="
for U in \
  "https://wfs.geonorge.no/skwms1/wfs.naturvernomrader?service=WFS&request=GetCapabilities&version=2.0.0" \
  "https://wfs.geonorge.no/skwms1/wfs.inspire-ps?service=WFS&request=GetCapabilities&version=2.0.0" \
  "https://nedlasting.geonorge.no/api/capabilities" ; do
  printf '  %-58s ' "$(echo "$U" | sed 's|https://||;s|?.*||')"
  CODE=$(curl -sS -m 40 -o "$OUT/g.txt" -w '%{http_code}' "$U" 2>/dev/null || echo '000')
  if [ "$CODE" != "200" ]; then echo "http $CODE"; continue; fi
  python3 -c "
import re,io
s=io.open('$OUT/g.txt',encoding='utf-8',errors='replace').read()
if 'ServiceException' in s or 'Could not access' in s:
    print('service indisponible'); raise SystemExit
if s.lstrip().startswith(('{','[')):
    print('JSON, %d octets' % len(s)); raise SystemExit
n=re.findall(r'<(?:wfs:)?Name>([^<]+)</(?:wfs:)?Name>', s)
if not n:
    print('pas de couches, %d octets' % len(s)); raise SystemExit
i=[x for x in n if re.search(r'vern|park|natur', x, re.I)]
print('%d couche(s), dont %d en rapport : %s' % (len(n), len(i), ', '.join(i[:4])))"
  sleep 1
done

echo
echo "=========================================="
echo "Me transmettre la sortie ci-dessus."
