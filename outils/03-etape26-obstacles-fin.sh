#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 26 : PAGINATION FINE DES OBSTACLES
# =============================================================================
#
# DEUX CORRECTIONS
#
# 1. La pagination de l'étape 25 employait un pas de 200 000 sur l'identifiant.
#    La première tranche a saturé à 20 000 objets, les suivantes étaient vides :
#    les identifiants tiennent donc tous sous 200 000, et le jeu restait
#    tronqué. Le pas passe à 5 000, et le script s'arrête après dix tranches
#    vides consécutives plutôt que trois — les identifiants peuvent être
#    dispersés.
#
# 2. Le fichier « poidss-limites.geojson » portait deux « s », le nom étant
#    composé à partir du libellé. Il devient « poids-limites.geojson ».
#
# CONTRÔLE AJOUTÉ : si une tranche sature encore, le script le signale et
# nomme la plage concernée, plutôt que de poursuivre en silence.
#
# LA CLÉ EST LUE DANS ~/.trafikverket-key.
#
# UTILISATION — depuis le dossier contenant _vagdata/
#   bash 03-etape26-obstacles-fin.sh
# =============================================================================

set -u
OUT="_vagdata"
CLE_FICHIER="$HOME/.trafikverket-key"
API="https://api.trafikinfo.trafikverket.se/v2/data.json"
PAS=5000
PLAFOND=20000

[ -s "$CLE_FICHIER" ] || { echo "Clé absente : $CLE_FICHIER"; exit 1; }
CLE=$(cat "$CLE_FICHIER")

# on repart de zéro : les pages de l'étape 25 sont tronquées
rm -rf "$OUT/pages"; mkdir -p "$OUT/pages"

echo "== Väghinder : pagination par tranches de $PAS =="
DEBUT=0; VIDES=0; SATUREES=0; TOTAL=0
for i in $(seq 0 80); do
  FIN=$((DEBUT + PAS))
  FIC="$OUT/pages/vh-$DEBUT.json"
  REQ="<REQUEST><LOGIN authenticationkey=\"$CLE\" /><QUERY objecttype=\"Väghinder\" namespace=\"vägdata.nvdb_dk_o\" schemaversion=\"1.2\" limit=\"$PLAFOND\"><FILTER><AND><GTE name=\"GID\" value=\"$DEBUT\" /><LT name=\"GID\" value=\"$FIN\" /></AND></FILTER></QUERY></REQUEST>"
  curl -sS -X POST -H "Content-Type: text/xml" -d "$REQ" "$API" -o "$FIC"
  N=$(python3 -c "
import json,io
try:
    d=json.load(io.open('$FIC',encoding='utf-8'))
    res=(d.get('RESPONSE') or {}).get('RESULT',[{}])[0]
    if 'ERROR' in res:
        print('-1'); raise SystemExit
    c=[k for k in res if k!='INFO']
    print(len(res[c[0]]) if c else 0)
except Exception:
    print('-1')")
  if [ "$N" = "-1" ]; then
    echo "   GID $DEBUT-$FIN : refus — arrêt"; rm -f "$FIC"; break
  fi
  TOTAL=$((TOTAL + N))
  if [ "$N" -ge "$PLAFOND" ]; then
    echo "   GID $DEBUT-$FIN : $N — SATURÉE, cette plage est incomplète"
    SATUREES=$((SATUREES + 1))
  elif [ "$N" -gt 0 ]; then
    echo "   GID $DEBUT-$FIN : $N"
  else
    rm -f "$FIC"
  fi
  if [ "$N" -eq 0 ]; then VIDES=$((VIDES + 1)); else VIDES=0; fi
  [ "$VIDES" -ge 10 ] && { echo "   dix tranches vides d'affilée — fin"; break; }
  DEBUT=$FIN
  sleep 1
done
echo "   cumul brut : $TOTAL | tranches saturées : $SATUREES"

python3 - <<'PY' > "$OUT/RAPPORT26.txt" 2>&1
import json, io, os, glob, collections, datetime, re

IN = '_vagdata'; AUJ = datetime.date.today().isoformat()
rapport = []
def note(s):
    print(s); rapport.append(s)

def objets(chemin):
    try:
        res = json.load(io.open(chemin, encoding='utf-8'))['RESPONSE']['RESULT'][0]
    except Exception:
        return []
    c = [k for k in res if k != 'INFO']
    return res[c[0]] if c else []

def wgs(g):
    if not isinstance(g, dict):
        return None
    w = g.get('WKT-WGS84-3D') or g.get('WKT-WGS84')
    if not w:
        return None
    t = w.split('(')[0].strip().upper().replace(' Z', '')
    corps = w[w.find('(') + 1:w.rfind(')')]
    def pts(b):
        out = []
        for p in b.split(','):
            v = p.replace('(', ' ').replace(')', ' ').split()
            if len(v) >= 2:
                try:
                    lon, lat = float(v[0]), float(v[1])
                except ValueError:
                    continue
                if 2 <= lon <= 34 and 53 <= lat <= 73:
                    out.append([round(lon, 5), round(lat, 5)])
        return out
    if t == 'POINT':
        p = pts(corps); return {'type': 'Point', 'coordinates': p[0]} if p else None
    if t == 'LINESTRING':
        p = pts(corps); return {'type': 'LineString', 'coordinates': p} if len(p) > 1 else None
    if t == 'MULTILINESTRING':
        ls = [x for x in (pts(b) for b in re.findall(r'\(([^()]*)\)', corps)) if len(x) > 1]
        return {'type': 'MultiLineString', 'coordinates': ls} if ls else None
    return None

# --- obstacles, toutes pages confondues
lot, vus = [], set()
pages = sorted(glob.glob(os.path.join(IN, 'pages', 'vh-*.json')))
brut = 0
for f in pages:
    o = objets(f)
    brut += len(o)
    for x in o:
        k = x.get('Feature_Oid') or x.get('GID')
        if k in vus:
            continue
        vus.add(k); lot.append(x)

note('=== obstacles sur la voie ===')
note('  pages : %d | objets bruts : %d | uniques : %d' % (len(pages), brut, len(lot)))

gids = [x.get('GID') for x in lot if isinstance(x.get('GID'), int)]
if gids:
    note('  plage d\'identifiants : %d à %d' % (min(gids), max(gids)))

feats = []
for o in lot:
    g = wgs(o.get('Geometry'))
    if not g:
        continue
    t = o.get('Hindertyp') or 'obstacle'
    feats.append({'type': 'Feature', 'geometry': g, 'properties': {
        'id': 'trv-%s' % (o.get('Feature_Oid') or o.get('GID')),
        'country': 'se', 'source': 'TRV', 'updated': AUJ,
        'name': t, 'type': 'barriere', 'modele': t,
        'verrouillee': t == 'låst grind eller bom'}})
c = os.path.join(IN, 'barrieres-se.geojson')
json.dump({'type': 'FeatureCollection', 'features': feats},
          io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)
note('  -> %d entités, %d Ko | verrouillées : %d'
     % (len(feats), os.path.getsize(c) // 1024,
        sum(1 for f in feats if f['properties']['verrouillee'])))
note('  par type : %s' % dict(collections.Counter(f['properties']['modele'] for f in feats).most_common(8)))

# --- correction du nom de fichier
vieux = os.path.join(IN, 'poidss-limites.geojson')
neuf = os.path.join(IN, 'poids-limites.geojson')
if os.path.exists(vieux):
    os.replace(vieux, neuf)
    note('')
    note('  fichier renommé : poidss-limites.geojson -> poids-limites.geojson')

note('')
note('=== les six fichiers ===')
for nom in ('hauteurs-limitees.geojson', 'poids-limites.geojson', 'largeurs-limites.geojson',
            'barrieres-se.geojson', 'bacs-se.geojson', 'aires-repos-se.geojson'):
    c = os.path.join(IN, nom)
    if not os.path.exists(c):
        note('  %-28s ABSENT' % nom); continue
    d = json.load(io.open(c, encoding='utf-8'))
    fs = d['features']
    ids = {f['properties']['id'] for f in fs}
    hors = 0
    for f in fs:
        cc = f['geometry']['coordinates']
        while isinstance(cc[0], list):
            cc = cc[0]
        if not (2 <= cc[0] <= 34 and 53 <= cc[1] <= 73):
            hors += 1
    note('  %-28s %6d entités | %6d id uniques | hors emprise %d | %5d Ko'
         % (nom, len(fs), len(ids), hors, os.path.getsize(c) // 1024))

io.open(os.path.join(IN, 'RAPPORT26.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT26.txt"
echo "=========================================="
echo "À me transmettre : $OUT/RAPPORT26.txt"
