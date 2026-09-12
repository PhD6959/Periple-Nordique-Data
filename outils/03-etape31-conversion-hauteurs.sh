#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 31 : CONVERSION DES HAUTEURS — NORVÈGE ET FINLANDE
# =============================================================================
#
# DEUX CORRECTIONS APRÈS LE PROFIL
#
# 1. UNITÉ FINLANDAISE. Ma détection se fondait sur le maximum : une valeur
#    isolée à 3000 a fait conclure « millimètres », d'où 5 802 obstacles
#    prétendument sous 3,20 m dont un à 0,17 m. On se fonde désormais sur la
#    MÉDIANE, qu'une valeur extrême ne déplace pas. L'exemple à 390 devient
#    3,90 m en centimètres, ce qui est plausible pour un passage inférieur.
#
# 2. CHOIX DU CHAMP NORVÉGIEN. Cinq champs de hauteur coexistent et ne disent
#    pas la même chose :
#      Skilta høyde     hauteur signalée, celle du panneau — 1 943 valeurs
#      Beregnet høyde   hauteur calculée — 3 112 valeurs
#      H-min droite, gauche, milieu   mesures réelles — jusqu'à 3 820 valeurs
#    On retient LA PLUS CONTRAIGNANTE des cinq, comme pour les tronçons de
#    tunnel ce matin : une hauteur signalée de 4,50 m avec un minimum mesuré à
#    4,20 m au bord droit, c'est 4,20 qui décide si l'on serre à droite.
#    La hauteur signalée est conservée à part : c'est celle qu'on lit sur place.
#
# Les trois pays sont ensuite fusionnés dans sources/hauteurs-limitees.geojson.
#
# UTILISATION — depuis le dossier contenant _hauteurs/
#   bash 03-etape31-conversion-hauteurs.sh
# =============================================================================

set -u
python3 - <<'PY'
import json, io, os, glob, collections, datetime, re, statistics, urllib.request

IN = '_hauteurs'; AUJ = datetime.date.today().isoformat()
HAUTEUR = 3.20
rapport = []
def note(s):
    print(s); rapport.append(s)

# ---------------------------------------------------------------- outils
def wgs_wkt(w):
    """NVDB : srid 4326, latitude puis longitude, avec altitude."""
    if not w:
        return None
    t = w.split('(')[0].strip().upper().replace(' Z', '')
    corps = w[w.find('('):]
    def pts(b):
        out = []
        for p in b.split(','):
            v = p.replace('(', ' ').replace(')', ' ').split()
            if len(v) >= 2:
                try:
                    lat, lon = float(v[0]), float(v[1])
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

def sans_altitude(g):
    """Les géométries finlandaises portent une altitude en troisième position."""
    if not g:
        return None
    def nett(c):
        return [round(float(c[0]), 5), round(float(c[1]), 5)]
    t = g.get('type')
    if t == 'Point':
        c = nett(g['coordinates'])
        return {'type': 'Point', 'coordinates': c} if 2 <= c[0] <= 34 and 53 <= c[1] <= 73 else None
    if t == 'LineString':
        p = [nett(c) for c in g['coordinates']]
        p = [c for c in p if 2 <= c[0] <= 34 and 53 <= c[1] <= 73]
        return {'type': 'LineString', 'coordinates': p} if len(p) > 1 else None
    if t == 'MultiLineString':
        ls = []
        for l in g['coordinates']:
            p = [nett(c) for c in l]
            p = [c for c in p if 2 <= c[0] <= 34 and 53 <= c[1] <= 73]
            if len(p) > 1:
                ls.append(p)
        return {'type': 'MultiLineString', 'coordinates': ls} if ls else None
    return None

def marque(h):
    m = round(h - HAUTEUR, 2)
    return {'hauteur_max_m': round(h, 2), 'franchissable': m > 0,
            'marge_cm': int(round(m * 100)),
            'vigilance': True if 0 < m < 0.30 else None}

feats_no, feats_fi = [], []

# ---------------------------------------------------------------- Norvège
CHAMPS = ['Skilta høyde', 'Beregnet høyde', 'H-min, høyre kant',
          'H-min, venstre kant', 'H-min, midt']
lot = []
c = os.path.join(IN, 'no-591.ndjson')
if os.path.exists(c):
    lot = [json.loads(l) for l in io.open(c, encoding='utf-8') if l.strip()]

note('=== Norvège ===')
note('  objets lus : %d' % len(lot))
retenu_par = collections.Counter()
sans_hauteur = 0
for o in lot:
    eg = {e.get('navn'): e.get('verdi') for e in (o.get('egenskaper') or [])}
    valeurs = {k: eg[k] for k in CHAMPS if isinstance(eg.get(k), (int, float))}
    if not valeurs:
        sans_hauteur += 1; continue
    champ = min(valeurs, key=valeurs.get)          # la plus contraignante
    h = float(valeurs[champ])
    retenu_par[champ] += 1
    g = wgs_wkt((o.get('geometri') or {}).get('wkt'))
    if not g:
        continue
    p = {'id': 'nvdb-591-%s' % o.get('id'), 'country': 'no', 'source': 'NVDB', 'updated': AUJ,
         'name': '%s %.2f m' % (eg.get('Navn') or eg.get('Type hinder') or 'obstacle', h),
         'type': 'hauteur_limitee', 'obstacle': eg.get('Type hinder'),
         'hauteur_signalee_m': eg.get('Skilta høyde'),
         'mesure_retenue': champ, 'largeur_m': eg.get('Bredde'),
         'methode': eg.get('Målemetode'), 'mesure_du': eg.get('Måledato')}
    p.update(marque(h))
    feats_no.append({'type': 'Feature', 'geometry': g,
                     'properties': {k: v for k, v in p.items() if v is not None}})
note('  sans aucune hauteur : %d' % sans_hauteur)
note('  champ le plus contraignant retenu : %s' % dict(retenu_par))
note('  entités : %d dont %d infranchissables, %d en vigilance'
     % (len(feats_no), sum(1 for f in feats_no if not f['properties']['franchissable']),
        sum(1 for f in feats_no if f['properties'].get('vigilance'))))
ecarts = [f['properties'] for f in feats_no
          if f['properties'].get('hauteur_signalee_m')
          and abs(f['properties']['hauteur_signalee_m'] - f['properties']['hauteur_max_m']) >= 0.10]
note('  écart d\'au moins 10 cm entre hauteur signalée et mesure retenue : %d' % len(ecarts))
for p in sorted(ecarts, key=lambda x: x['hauteur_max_m'])[:5]:
    note('    %-34s signalée %.2f, retenue %.2f (%s)'
         % (str(p.get('name'))[:34], p['hauteur_signalee_m'], p['hauteur_max_m'], p['mesure_retenue']))

# ---------------------------------------------------------------- Finlande
fs = []
for f in sorted(glob.glob(os.path.join(IN, 'fi-korkeus-*.geojson'))):
    try:
        fs += json.load(io.open(f, encoding='utf-8')).get('features', [])
    except Exception:
        pass
note('')
note('=== Finlande ===')
note('  entités lues : %d' % len(fs))
vals = [x['properties'].get('arvo') for x in fs]
vals = [float(v) for v in vals if isinstance(v, (int, float)) and v > 0]
if vals:
    med = statistics.median(vals)
    # la médiane d'un obstacle routier se situe entre 1,5 et 10 m ; l'unité s'en déduit
    if med < 20:
        unite, div = 'm', 1.0
    elif med < 200:
        unite, div = 'dm', 10.0
    elif med < 2000:
        unite, div = 'cm', 100.0
    else:
        unite, div = 'mm', 1000.0
    note('  médiane de « arvo » : %.0f -> unité retenue : %s' % (med, unite))
    note('  après conversion : min %.2f m, médiane %.2f m, max %.2f m'
         % (min(vals) / div, med / div, max(vals) / div))
    for x in fs:
        v = x['properties'].get('arvo')
        if not isinstance(v, (int, float)) or v <= 0:
            continue
        h = float(v) / div
        if not (1.0 <= h <= 12.0):        # hors de cette plage, la valeur n'est pas une hauteur
            continue
        g = sans_altitude(x.get('geometry'))
        if not g:
            continue
        pr = x['properties']
        p = {'id': 'digiroad-%s' % pr.get('id'), 'country': 'fi', 'source': 'VAYLA', 'updated': AUJ,
             'name': 'hauteur %.2f m' % h, 'type': 'hauteur_limitee',
             'kunta': pr.get('kuntakoodi'), 'sens': pr.get('vaik_suunt')}
        p.update(marque(h))
        feats_fi.append({'type': 'Feature', 'geometry': g,
                         'properties': {k: v2 for k, v2 in p.items() if v2 is not None}})
    note('  entités : %d dont %d infranchissables, %d en vigilance'
         % (len(feats_fi), sum(1 for f in feats_fi if not f['properties']['franchissable']),
            sum(1 for f in feats_fi if f['properties'].get('vigilance'))))
    note('  écartées hors plage 1–12 m : %d' % (len(vals) - len(feats_fi)))

# ---------------------------------------------------------------- fusion
note('')
note('=== fusion avec la couche suédoise ===')
BASE = 'https://raw.githubusercontent.com/PhD6959/Periple-Nordique-Data/main/sources/hauteurs-limitees.geojson'
try:
    with urllib.request.urlopen(BASE, timeout=60) as r:
        anciennes = json.loads(r.read().decode('utf-8'))['features']
except Exception as e:
    note('  téléchargement impossible (%s) — fusion abandonnée' % str(e)[:60])
    anciennes = None

if anciennes is not None:
    ids = {f['properties']['id'] for f in anciennes}
    ajout = [f for f in feats_no + feats_fi if f['properties']['id'] not in ids]
    total = anciennes + ajout
    c = os.path.join(IN, 'hauteurs-limitees.geojson')
    json.dump({'type': 'FeatureCollection', 'features': total},
              io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)
    note('  %d + %d = %d entités, %d Ko' % (len(anciennes), len(ajout), len(total),
                                            os.path.getsize(c) // 1024))
    note('  par pays   : %s' % dict(collections.Counter(f['properties']['country'] for f in total)))
    note('  par source : %s' % dict(collections.Counter(f['properties']['source'] for f in total)))
    note('  infranchissables à %.2f m : %d' % (HAUTEUR, sum(1 for f in total if not f['properties']['franchissable'])))
    note('  par pays   : %s' % dict(collections.Counter(
        f['properties']['country'] for f in total if not f['properties']['franchissable'])))
    ids2 = {f['properties']['id'] for f in total}
    note('  identifiants uniques : %s' % ('oui' if len(ids2) == len(total) else 'NON, %d doublons' % (len(total) - len(ids2))))

note('')
note('=== échantillons ===')
for lot2, lbl in ((feats_no, 'Norvège'), (feats_fi, 'Finlande')):
    bas = sorted((f for f in lot2 if not f['properties']['franchissable']),
                 key=lambda f: f['properties']['hauteur_max_m'])[:2]
    for f in bas:
        note('  %-9s %s' % (lbl, json.dumps(f['properties'], ensure_ascii=False)[:260]))

io.open(os.path.join(IN, 'RAPPORT31.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _hauteurs/RAPPORT31.txt
echo "=========================================="
echo "À me transmettre : _hauteurs/RAPPORT31.txt"
