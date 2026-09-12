#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 30 : HAUTEURS LIMITÉES — NORVÈGE ET FINLANDE
# =============================================================================
#
# La couche des hauteurs n'existait que pour la Suède. Les deux autres pays ont
# leur source, trouvée le 12/09/2026 :
#
#   NORVÈGE   NVDB, vegobjekttype 591 « Høydebegrensning » — « tronçon du réseau
#             où un véhicule peut entrer en conflit avec un obstacle situé
#             au-dessus ». Vérifié au catalogue d'objets de Geonorge.
#             Licence NLOD.
#   FINLANDE  Digiroad, couche WFS digiroad:dr_max_korkeus, relevée parmi les
#             46 couches lors du premier profil du 10/09. Licence CC BY 4.0.
#
# LES NOMS DE CHAMPS NE SONT PAS CONNUS À L'AVANCE. Le script les cherche par
# motif — « høyde » côté norvégien, « korkeus » ou « arvo » côté finlandais —
# et REND COMPTE de ce qu'il a trouvé, plutôt que de supposer.
#
# Il produit deux fichiers séparés. La fusion avec la couche suédoise se fera
# ensuite, une fois les champs confirmés.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape30-hauteurs-no-fi.sh
# =============================================================================

set -u
OUT="_hauteurs"; mkdir -p "$OUT"

# -----------------------------------------------------------------------------
# NORVÈGE — NVDB, type 591, pagination par le lien « neste »
# -----------------------------------------------------------------------------
CLIENT="PeripleNordique2027"
BASE="https://nvdbapiles.atlas.vegvesen.no/vegobjekter/api/v4/vegobjekter"
echo "== Norvège : Høydebegrensning (591) =="
URL="$BASE/591?antall=1000&srid=4326&inkluder=metadata,egenskaper,geometri,lokasjon&inkluderAntall=true"
PAGE=0; TOTAL=0
: > "$OUT/no-591.ndjson"
while [ -n "$URL" ] && [ "$PAGE" -lt 60 ]; do
  curl -sS -H "Accept: application/json" -H "X-Client: $CLIENT" "$URL" -o "$OUT/tmp.json"
  INFO=$(python3 -c "
import json,io
try:
    d=json.load(io.open('$OUT/tmp.json',encoding='utf-8'))
except Exception as e:
    print('0||ERREUR'); raise SystemExit
r=d.get('objekter', d.get('vegobjekter', []))
m=d.get('metadata',{}) or {}
with io.open('$OUT/no-591.ndjson','a',encoding='utf-8') as f:
    for o in r: f.write(json.dumps(o,ensure_ascii=False)+'\n')
print('%d|%s|%s' % (len(r), (m.get('neste') or {}).get('href','') if r else '', m.get('antall','?')))")
  N=${INFO%%|*}; R=${INFO#*|}; SUIV=${R%%|*}; ANN=${R##*|}
  [ "$PAGE" -eq 0 ] && echo "   annoncés : $ANN"
  TOTAL=$((TOTAL+N)); PAGE=$((PAGE+1))
  [ "$N" -eq 0 ] && break
  [ -z "$SUIV" ] && break
  URL="$SUIV"
done
echo "   récupérés : $TOTAL en $PAGE page(s)"
rm -f "$OUT/tmp.json"

# -----------------------------------------------------------------------------
# FINLANDE — Digiroad, WFS, pagination par startIndex
# -----------------------------------------------------------------------------
FIWFS="https://avoinapi.vaylapilvi.fi/vaylatiedot/digiroad/wfs"
echo "== Finlande : dr_max_korkeus =="
i=0
while [ $i -lt 200000 ]; do
  F="$OUT/fi-korkeus-$i.geojson"
  if [ ! -s "$F" ]; then
    curl -sS -G "$FIWFS" \
      --data-urlencode "service=WFS" --data-urlencode "version=2.0.0" \
      --data-urlencode "request=GetFeature" \
      --data-urlencode "typeNames=digiroad:dr_max_korkeus" \
      --data-urlencode "outputFormat=application/json" \
      --data-urlencode "srsName=EPSG:4326" \
      --data-urlencode "count=20000" --data-urlencode "startIndex=$i" -o "$F"
  fi
  N=$(python3 -c "
import json,io
try:
    print(len(json.load(io.open('$F',encoding='utf-8')).get('features',[])))
except Exception: print(0)")
  echo "   startIndex=$i -> $N"
  [ "$N" -lt 20000 ] && break
  i=$((i+20000))
done

python3 - <<'PY' > "$OUT/PROFIL30.txt" 2>&1
import json, io, os, glob, collections, re

OUT = '_hauteurs'
HAUTEUR = 3.20

# ---------------------------------------------------------------- Norvège
lot = []
c = os.path.join(OUT, 'no-591.ndjson')
if os.path.exists(c):
    lot = [json.loads(l) for l in io.open(c, encoding='utf-8') if l.strip()]
print('=== Norvège — Høydebegrensning (591) ===')
print('  objets : %d' % len(lot))
if lot:
    props = collections.OrderedDict()
    for o in lot:
        for e in (o.get('egenskaper') or []):
            k = (e.get('id'), e.get('navn'), e.get('egenskapstype'))
            props.setdefault(k, [0, e.get('verdi')])
            props[k][0] += 1
    print('  propriétés :')
    for (eid, navn, etype), (n, ex) in sorted(props.items(), key=lambda x: -x[1][0]):
        print('    %-6s | %-36s | %-11s | %6d | %s' % (eid, str(navn)[:36], str(etype)[:11], n, str(ex)[:50]))
    # le champ de hauteur, cherché par motif
    cands = [navn for (_, navn, _) in props if navn and 'høyde' in navn.lower()]
    print('  champs contenant « høyde » : %s' % cands)
    if cands:
        champ = cands[0]
        vals = [ {e.get('navn'): e.get('verdi') for e in (o.get('egenskaper') or [])}.get(champ) for o in lot ]
        vals = [v for v in vals if isinstance(v, (int, float))]
        if vals:
            print('  sur « %s » : %d valeurs | min %.2f | max %.2f' % (champ, len(vals), min(vals), max(vals)))
            print('  sous %.2f m : %d' % (HAUTEUR, sum(1 for v in vals if v <= HAUTEUR)))
            print('  répartition : %s' % dict(sorted(collections.Counter(round(v, 2) for v in vals).items())[:16]))
    g = collections.Counter(str((o.get('geometri') or {}).get('wkt', '')).split('(')[0].strip()[:16] for o in lot)
    print('  géométries : %s' % dict(g))
    o = dict(lot[0]); gg = dict(o.get('geometri') or {})
    if 'wkt' in gg:
        gg['wkt'] = gg['wkt'][:90] + '…'
    o['geometri'] = gg; o.pop('lokasjon', None)
    print('  échantillon : %s' % json.dumps(o, ensure_ascii=False)[:700])

# ---------------------------------------------------------------- Finlande
fs = []
for f in sorted(glob.glob(os.path.join(OUT, 'fi-korkeus-*.geojson'))):
    try:
        fs += json.load(io.open(f, encoding='utf-8')).get('features', [])
    except Exception as e:
        print('page illisible :', f, str(e)[:60])
print('')
print('=== Finlande — dr_max_korkeus ===')
print('  entités : %d' % len(fs))
if fs:
    ch = collections.Counter()
    for x in fs:
        for k in (x.get('properties') or {}):
            ch[k] += 1
    print('  champs : %s' % ', '.join(sorted(ch)))
    p = fs[0].get('properties', {})
    for k in sorted(p):
        print('    %-18s %s' % (k, json.dumps(p[k], ensure_ascii=False)[:70]))
    cands = [k for k in ch if re.search(r'korkeus|arvo|max', k, re.I)]
    print('  champs candidats pour la hauteur : %s' % cands)
    for champ in cands:
        vals = [x['properties'].get(champ) for x in fs]
        vals = [float(v) for v in vals if isinstance(v, (int, float))]
        if not vals:
            continue
        # mètres, décimètres ou centimètres ? Un obstacle routier tient entre
        # 1,5 et 10 m, ce qui suffit à trancher.
        m = max(vals)
        if m < 20:
            unite, div = 'm', 1.0
        elif m < 200:
            unite, div = 'dm', 10.0
        elif m < 2000:
            unite, div = 'cm', 100.0
        else:
            unite, div = 'mm', 1000.0
        print('  « %s » : %d valeurs | min %.0f | max %.0f | unité probable : %s'
              % (champ, len(vals), min(vals), max(vals), unite))
        conv = [v / div for v in vals]
        print('    sous %.2f m : %d' % (HAUTEUR, sum(1 for v in conv if v <= HAUTEUR)))
        print('    répartition : %s' % dict(sorted(collections.Counter(round(v, 2) for v in conv).items())[:14]))
    print('  géométrie du premier : %s' % json.dumps(fs[0].get('geometry'), ensure_ascii=False)[:140])
PY

echo
echo "=========================================="
cat "$OUT/PROFIL30.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL30.txt"
