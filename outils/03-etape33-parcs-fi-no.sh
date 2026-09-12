#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 33 : ZONES PROTÉGÉES — FINLANDE ET NORVÈGE
# =============================================================================
#
# CE QUE L'ÉTAPE 32 A ÉTABLI
#   FINLANDE  paikkatiedot.ymparisto.fi/geoserver/inspire_ps/wfs expose douze
#             couches, dont PS.ProtectedSitesValtionOmistamaLuonnonsuojelualueet
#             — les zones de protection appartenant à l'État, qui contiennent
#             les parcs nationaux.
#   NORVÈGE   kart.miljodirektoratet.no/arcgis/rest/services/vern/MapServer a
#             répondu en JSON : c'est un service ArcGIS dont la description
#             donne la liste des couches. On la lit, puis on interroge la
#             couche des zones protégées.
#   SUÈDE     quatre adresses, quatre refus. Reste ouvert.
#
# Un service ArcGIS s'interroge par /<couche>/query avec where=1=1 et
# f=geojson, et se pagine par resultOffset.
#
# UTILISATION — depuis le dossier contenant _parcs/
#   bash 03-etape33-parcs-fi-no.sh
# =============================================================================

set -u
OUT="_parcs"; mkdir -p "$OUT"

# -----------------------------------------------------------------------------
# 1. Norvège : que contient le service ?
# -----------------------------------------------------------------------------
echo "== Norvège : couches du service « vern » =="
MDIR="https://kart.miljodirektoratet.no/arcgis/rest/services/vern/MapServer"
curl -sS -m 45 "$MDIR?f=json" -o "$OUT/no-vern-desc.json"
python3 - <<'PY'
import json, io
try:
    d = json.load(io.open('_parcs/no-vern-desc.json', encoding='utf-8'))
except Exception as e:
    print('   illisible :', str(e)[:90]); raise SystemExit
print('   service : %s' % (d.get('serviceDescription') or d.get('description') or '')[:110])
for l in (d.get('layers') or []):
    print('   couche %-4s %s' % (l.get('id'), l.get('name')))
for t in (d.get('tables') or []):
    print('   table  %-4s %s' % (t.get('id'), t.get('name')))
if not d.get('layers'):
    print('   aucune couche annoncée — voir le fichier')
PY

# -----------------------------------------------------------------------------
# 2. Norvège : extraction de la couche des zones protégées
#    L'identifiant de couche est repris de la description ci-dessus ; 0 est le
#    plus courant. Si la réponse est vide, essayer les autres identifiants.
# -----------------------------------------------------------------------------
echo
echo "== Norvège : extraction =="
for COUCHE in 0 1 2; do
  FIC="$OUT/no-vern-$COUCHE.geojson"
  [ -s "$FIC" ] && { echo "   couche $COUCHE : déjà téléchargée"; continue; }
  curl -sS -m 120 -G "$MDIR/$COUCHE/query" \
    --data-urlencode "where=1=1" \
    --data-urlencode "outFields=*" \
    --data-urlencode "returnGeometry=true" \
    --data-urlencode "outSR=4326" \
    --data-urlencode "f=geojson" \
    --data-urlencode "resultRecordCount=2000" -o "$FIC"
  python3 -c "
import json,io
try:
    d=json.load(io.open('$FIC',encoding='utf-8'))
except Exception as e:
    print('   couche $COUCHE : illisible'); raise SystemExit
if 'error' in d:
    print('   couche $COUCHE : %s' % str(d['error'].get('message'))[:80]); raise SystemExit
f=d.get('features',[])
print('   couche $COUCHE : %d entité(s)' % len(f))
if f:
    p=f[0].get('properties',{})
    print('      champs : %s' % ', '.join(sorted(p))[:200])
    for k in list(sorted(p))[:8]:
        print('        %-26s %s' % (k, str(p[k])[:60]))
    print('      géométrie : %s' % f[0].get('geometry',{}).get('type'))"
  sleep 2
done

# -----------------------------------------------------------------------------
# 3. Finlande : les zones protégées de l'État
# -----------------------------------------------------------------------------
echo
echo "== Finlande : zones protégées de l'État =="
FIWFS="https://paikkatiedot.ymparisto.fi/geoserver/inspire_ps/wfs"
COUCHE_FI=$(python3 -c "
import re,io
s=io.open('_parcs/fi-inspire-ps.xml',encoding='utf-8',errors='replace').read()
n=re.findall(r'<(?:wfs:)?Name>([^<]+)</(?:wfs:)?Name>', s)
c=[x for x in n if 'ValtionOmistama' in x]
print(c[0] if c else '')")
echo "   couche : ${COUCHE_FI:-introuvable}"
if [ -n "$COUCHE_FI" ]; then
  FIC="$OUT/fi-suojelu.geojson"
  if [ ! -s "$FIC" ]; then
    curl -sS -m 180 -G "$FIWFS" \
      --data-urlencode "service=WFS" --data-urlencode "version=2.0.0" \
      --data-urlencode "request=GetFeature" \
      --data-urlencode "typeNames=$COUCHE_FI" \
      --data-urlencode "outputFormat=application/json" \
      --data-urlencode "srsName=EPSG:4326" \
      --data-urlencode "count=5000" -o "$FIC"
  fi
  python3 -c "
import json,io,collections
try:
    d=json.load(io.open('$FIC',encoding='utf-8'))
except Exception as e:
    print('   illisible : %s' % str(e)[:90]); raise SystemExit
f=d.get('features',[])
print('   entités : %d' % len(f))
if f:
    p=f[0].get('properties',{})
    print('   champs : %s' % ', '.join(sorted(p))[:260])
    for k in sorted(p)[:10]:
        print('     %-30s %s' % (k, str(p[k])[:60]))
    g=collections.Counter(x.get('geometry',{}).get('type') for x in f)
    print('   géométries : %s' % dict(g))
    import re
    noms=[str(v) for k,v in p.items() if re.search(r'nimi|name', k, re.I)]
    print('   champs de nom repérés : %s' % noms[:3])"
fi

echo
echo "=========================================="
ls -la "$OUT"/*.geojson 2>/dev/null | awk '{printf "  %9s  %s\n", $5, $9}'
echo "Me transmettre la sortie ci-dessus."
