#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 25 : PAGINATION DES OBSTACLES ET CONVERSION
# =============================================================================
#
# 1. Väghinder a atteint le plafond de 20 000. On pagine par comté — l'API
#    expose CountyNo sur beaucoup de types, mais pas sur celui-ci ; on pagine
#    donc par tranche de GID, identifiant croissant.
#
# 2. BegränsadFordonslängd est abandonné : un seul objet sous 7 m sur 20 000,
#    et 18 687 à 12 m, la limite standard. Rien qui concerne un fourgon.
#
# 3. Conversion des six jeux utiles vers le schéma commun, avec marquage de
#    franchissabilité à 3,20 m et 3,5 t.
#
# UNE RÉSERVE SUR LES HAUTEURS : certaines valeurs portent des décimales
# aberrantes — 2,400000095, 3,900000095 — signe d'une conversion d'unité depuis
# des décimètres. Elles sont arrondies au centimètre, et la marge calculée ne
# doit pas être lue comme une mesure de terrain.
#
# LA CLÉ EST LUE DANS ~/.trafikverket-key.
#
# UTILISATION — depuis le dossier contenant _vagdata/
#   bash 03-etape25-obstacles-conversion.sh
# =============================================================================

set -u
OUT="_vagdata"; mkdir -p "$OUT/pages"
CLE_FICHIER="$HOME/.trafikverket-key"
API="https://api.trafikinfo.trafikverket.se/v2/data.json"

[ -s "$CLE_FICHIER" ] || { echo "Clé absente : $CLE_FICHIER"; exit 1; }
CLE=$(cat "$CLE_FICHIER")

echo "== Väghinder : pagination par tranche de GID =="
DEBUT=0
PAS=200000
for i in $(seq 0 40); do
  FIN=$((DEBUT + PAS))
  FIC="$OUT/pages/vh-$DEBUT.json"
  if [ ! -s "$FIC" ]; then
    REQ="<REQUEST><LOGIN authenticationkey=\"$CLE\" /><QUERY objecttype=\"Väghinder\" namespace=\"vägdata.nvdb_dk_o\" schemaversion=\"1.2\" limit=\"20000\"><FILTER><AND><GTE name=\"GID\" value=\"$DEBUT\" /><LT name=\"GID\" value=\"$FIN\" /></AND></FILTER></QUERY></REQUEST>"
    curl -sS -X POST -H "Content-Type: text/xml" -d "$REQ" "$API" -o "$FIC"
  fi
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
    echo "   GID $DEBUT-$FIN : refus ou illisible — arrêt"
    rm -f "$FIC"
    break
  fi
  echo "   GID $DEBUT-$FIN : $N objet(s)"
  [ "$N" -ge 20000 ] && echo "      TRANCHE SATURÉE — réduire le pas"
  DEBUT=$FIN
  [ "$N" -eq 0 ] && VIDES=$((${VIDES:-0} + 1)) || VIDES=0
  [ "${VIDES:-0}" -ge 3 ] && { echo "   trois tranches vides d'affilée — fin"; break; }
  sleep 2
done

python3 - <<'PY' > "$OUT/RAPPORT25.txt" 2>&1
import json, io, os, glob, collections, datetime, re

IN = '_vagdata'; AUJ = datetime.date.today().isoformat()
HAUTEUR, PTAC, LARGEUR = 3.20, 3.5, 2.2
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
    """La géométrie est en 3D, avec des altitudes à -99999 quand elles manquent.
    On ne garde que longitude et latitude."""
    if not isinstance(g, dict):
        return None
    w = g.get('WKT-WGS84-3D') or g.get('WKT-WGS84')
    if not w:
        return None
    t = w.split('(')[0].strip().upper().replace(' Z', '')
    corps = w[w.find('(') + 1:w.rfind(')')]
    def pts(bloc):
        out = []
        for p in bloc.split(','):
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
        p = pts(corps)
        return {'type': 'Point', 'coordinates': p[0]} if p else None
    if t == 'LINESTRING':
        p = pts(corps)
        return {'type': 'LineString', 'coordinates': p} if len(p) > 1 else None
    if t == 'MULTILINESTRING':
        ls = [pts(b) for b in re.findall(r'\(([^()]*)\)', corps)]
        ls = [x for x in ls if len(x) > 1]
        return {'type': 'MultiLineString', 'coordinates': ls} if ls else None
    return None

def base(o, pays='se'):
    return {'id': 'trv-%s' % (o.get('Feature_Oid') or o.get('GID')),
            'country': pays, 'source': 'TRV', 'updated': AUJ}

sorties = {}

# ---------------------------------------------------------------- hauteurs
lot = objets(os.path.join(IN, 'x-Höjdhinder_upp_till_45_dm.json'))
feats = []
for o in lot:
    g = wgs(o.get('Geometry'))
    h = o.get('Fri_höjd')
    if not g or h is None:
        continue
    h = round(float(h), 2)          # décimales aberrantes issues d'une conversion
    marge = round(h - HAUTEUR, 2)
    p = base(o)
    p.update({'name': '%s %.2f m' % (o.get('Höjdhindertyp') or 'obstacle', h),
              'type': 'hauteur_limitee', 'obstacle': o.get('Höjdhindertyp'),
              'hauteur_max_m': h, 'franchissable': marge > 0,
              'marge_cm': int(round(marge * 100)),
              'reference': o.get('Höjdhinderidentitet')})
    if 0 < marge < 0.30:
        p['vigilance'] = True
    feats.append({'type': 'Feature', 'geometry': g,
                  'properties': {k: v for k, v in p.items() if v is not None}})
sorties['hauteurs-limitees.geojson'] = feats
note('=== hauteurs limitées ===')
note('  %d entités | infranchissables : %d | vigilance : %d'
     % (len(feats), sum(1 for f in feats if not f['properties']['franchissable']),
        sum(1 for f in feats if f['properties'].get('vigilance'))))

# ---------------------------------------------------------------- poids et largeur
for fichier, champ, typ, seuil, lib in (
        ('x-BegränsadBruttovikt.json', 'Högsta_tillåtna_bruttovikt', 'poids_limite', PTAC, 'poids'),
        ('x-BegränsadFordonsbredd.json', 'Högsta_tillåtna_fordonsbredd', 'largeur_limitee', LARGEUR, 'largeur')):
    lot = objets(os.path.join(IN, fichier))
    feats = []
    for o in lot:
        g = wgs(o.get('Geometry'))
        v = o.get(champ)
        if not g or v is None:
            continue
        v = round(float(v), 2)
        p = base(o)
        p.update({'name': '%s max %s' % (lib, v), 'type': typ,
                  'valeur': v, 'franchissable': v >= seuil,
                  'aussi_ensembles': o.get('Avser_även_fordonståg'),
                  'info': (o.get('Beskrivning') or '')[:180] or None})
        feats.append({'type': 'Feature', 'geometry': g,
                      'properties': {k: v2 for k, v2 in p.items() if v2 is not None}})
    sorties['%ss-limites.geojson' % lib] = feats
    note('=== %s ===' % lib)
    note('  %d entités | bloquants : %d'
         % (len(feats), sum(1 for f in feats if not f['properties']['franchissable'])))

# ---------------------------------------------------------------- obstacles paginés
lot, vus = [], set()
for f in sorted(glob.glob(os.path.join(IN, 'pages', 'vh-*.json'))):
    for o in objets(f):
        k = o.get('Feature_Oid') or o.get('GID')
        if k in vus:
            continue
        vus.add(k); lot.append(o)
if not lot:
    lot = objets(os.path.join(IN, 'x-Väghinder.json'))
feats = []
for o in lot:
    g = wgs(o.get('Geometry'))
    if not g:
        continue
    t = o.get('Hindertyp') or 'obstacle'
    p = base(o)
    p.update({'name': t, 'type': 'barriere', 'modele': t,
              'verrouillee': t == 'låst grind eller bom'})
    feats.append({'type': 'Feature', 'geometry': g,
                  'properties': {k: v for k, v in p.items() if v is not None}})
sorties['barrieres-se.geojson'] = feats
note('=== obstacles sur la voie ===')
note('  %d entités | verrouillées : %d'
     % (len(feats), sum(1 for f in feats if f['properties']['verrouillee'])))
note('  par type : %s' % dict(collections.Counter(f['properties']['modele'] for f in feats).most_common(8)))

# ---------------------------------------------------------------- bacs
lot = objets(os.path.join(IN, 'x-Färjeled.json'))
feats = []
for o in lot:
    g = wgs(o.get('Geometry'))
    if not g:
        continue
    p = base(o)
    p.update({'name': o.get('Färjeledsnamn') or 'liaison', 'type': 'liaison',
              'exploitation': 'Trafikverket'})
    feats.append({'type': 'Feature', 'geometry': g,
                  'properties': {k: v for k, v in p.items() if v is not None}})
sorties['bacs-se.geojson'] = feats
note('=== liaisons de bacs ===')
note('  %d entités' % len(feats))

# ---------------------------------------------------------------- aires de repos
lot = objets(os.path.join(IN, 'x-Rastplatser.json'))
feats = []
def oui(v):
    return str(v).strip().lower() == 'ja'
for o in lot:
    g = wgs(o.get('Geometric_Position')) or wgs(o.get('Geometry'))
    if not g:
        continue
    p = base(o)
    p.update({'name': o.get('Rastplatsnamn') or 'aire de repos', 'type': 'aire',
              'vidange': oui(o.get('Latrintömning')),
              'toilettes': (o.get('Totalt_antal_toaletter') or 0) > 0,
              'places_voiture': o.get('Totalt_antal_parkeringsplatser_för_personbil'),
              'places_poids_lourd': o.get('Totalt_antal_parkeringsplatser_för_lastbil_släp'),
              'tables': o.get('Totalt_antal_bord_med_sittplatser'),
              'aire_de_jeu': oui(o.get('Lekutrustning')),
              'gestionnaire': o.get('Skötselansvarig')})
    p['equipee'] = bool(p['vidange'] or p['toilettes'])
    feats.append({'type': 'Feature', 'geometry': g,
                  'properties': {k: v for k, v in p.items() if v is not None}})
sorties['aires-repos-se.geojson'] = feats
note('=== aires de repos ===')
note('  %d entités | avec vidange : %d | avec toilettes : %d'
     % (len(feats), sum(1 for f in feats if f['properties'].get('vidange')),
        sum(1 for f in feats if f['properties'].get('toilettes'))))

# ---------------------------------------------------------------- écriture
note('')
note('=== fichiers produits ===')
for nom, feats in sorties.items():
    c = os.path.join(IN, nom)
    json.dump({'type': 'FeatureCollection', 'features': feats},
              io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)
    note('  %-28s %6d entités, %5d Ko' % (nom, len(feats), os.path.getsize(c) // 1024))

note('')
note('=== échantillons ===')
for nom in ('hauteurs-limitees.geojson', 'barrieres-se.geojson', 'aires-repos-se.geojson'):
    f = sorties.get(nom) or []
    if f:
        note('  ' + json.dumps(f[0]['properties'], ensure_ascii=False)[:300])

io.open(os.path.join(IN, 'RAPPORT25.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT25.txt"
echo "=========================================="
echo "À me transmettre : $OUT/RAPPORT25.txt"
