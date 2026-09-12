#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 38 : BLOCS D'ITINÉRAIRE — LECTURE DU DOCUMENT SOURCE
# =============================================================================
#
# REMPLACE L'ÉTAPE 11, qui portait les seize ancrages ET les seize blocs écrits
# en dur. Le document d'itinéraire bougera ; une copie figée dans un script
# serait devenue fausse en silence, sans que rien ne le signale.
#
# CE SCRIPT NE RECOPIE RIEN :
#   - les BLOCS — numéro, nom, dates, contenu, étape — sont lus dans
#     docs/doc-periple-nordique-2027-itineraire.html, le document lui-même ;
#   - les ANCRAGES sont lus dans sources/blocs-ancrages.json, parce qu'un
#     ancrage est un choix et non une donnée du document.
#
# CE QU'IL SIGNALE ET QUI ARRÊTE LA PRODUCTION :
#   - un bloc du document sans ancrage : l'itinéraire a gagné un bloc ;
#   - un ancrage sans bloc correspondant : l'itinéraire en a perdu un ;
#   - la version du document différente de celle consignée au manifeste.
#   Dans ces trois cas il écrit quand même un rapport, mais pas de couche :
#   une couche incomplète est pire qu'une couche absente.
#
# LA VERSION DU DOCUMENT EST CONSIGNÉE au manifeste, rubrique blocs-itineraire.
# C'est elle qui dit si la couche publiée correspond à l'itinéraire courant.
#
# UTILISATION — depuis la racine du dépôt de données
#   bash outils/03-etape38-blocs-depuis-document.sh
# =============================================================================

set -u
RACINE=$(cd "$(dirname "$0")/.." && pwd)
cd "$RACINE" || exit 1
OUT="_blocs"; mkdir -p "$OUT"
echo "Dépôt : $RACINE"

python3 - <<'PY'
import json, io, os, re, sys, time, datetime, urllib.request, urllib.parse

DOC = os.path.join('docs', 'doc-periple-nordique-2027-itineraire.html')
ANC = os.path.join('sources', 'blocs-ancrages.json')
MAN = 'manifest-donnees.json'
OUT = '_blocs'
AUJ = datetime.date.today().isoformat()
rapport = []
arret = []

def note(s):
    print(s); rapport.append(s)

def bloquant(s):
    note('  ARRÊT : ' + s); arret.append(s)

# ------------------------------------------------------------ le document
if not os.path.exists(DOC):
    note("Document d'itinéraire introuvable : %s" % DOC)
    note("Il doit vivre dans docs/ du dépôt de données : c'est la source de la couche.")
    sys.exit(1)

s = io.open(DOC, encoding='utf-8', errors='replace').read()
m = re.search(r'Version\s*([\d.]+)\s*—\s*([^<]{0,40})', s)
version_doc = m.group(1) if m else '?'
date_doc = (m.group(2).strip() if m else '?')
note('=== document source ===')
note('  %s' % DOC)
note('  version %s — %s' % (version_doc, date_doc))

# le tableau des blocs
blocs = []
for ligne in re.findall(r'<tr>(.*?)</tr>', s, re.S):
    cells = [re.sub(r'<[^>]+>', ' ', x) for x in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', ligne, re.S)]
    cells = [re.sub(r'\s+', ' ', x).strip() for x in cells]
    if len(cells) >= 4 and cells[0].isdigit():
        # Le nom et les dates sont collés : « Barreau E14 — d'est en ouest15–20 mai · 6 jours ».
        # Couper au premier chiffre donnerait « Barreau E ». On repère le début
        # des dates par un jour suivi d'un mois, ou d'un tiret puis d'un jour.
        MOIS = ('janvier|février|mars|avril|mai|juin|juillet|août|septembre|'
                'octobre|novembre|décembre')
        md = re.search(r'\d{1,2}(?:\s*[–—-]\s*\d{1,2}\s*(?:er)?)?\s+(?:%s)\b.*jours\s*$' % MOIS,
                       cells[1])
        blocs.append({'n': int(cells[0]),
                      'nom': (cells[1][:md.start()].strip() if md else cells[1]),
                      'dates': (md.group(0).strip() if md else ''),
                      'contenu': cells[2],
                      'etape': cells[3] if cells[3] not in ('—', '-', '') else None})
blocs.sort(key=lambda b: b['n'])
note('  blocs lus : %d' % len(blocs))
if not blocs:
    bloquant("aucun bloc lu — la mise en forme du tableau a changé, le lecteur est à reprendre")

# ------------------------------------------------------------- les ancrages
if not os.path.exists(ANC):
    note("Fichier d'ancrages introuvable : %s" % ANC)
    sys.exit(1)
A = json.load(io.open(ANC, encoding='utf-8'))['ancrages']
note('  ancrages déclarés : %d' % len(A))

nums_doc = {b['n'] for b in blocs}
nums_anc = {int(k) for k in A}
for n in sorted(nums_doc - nums_anc):
    nom = next(b['nom'] for b in blocs if b['n'] == n)
    bloquant("bloc %d « %s » sans ancrage — ajouter une entrée à %s" % (n, nom[:40], ANC))
for n in sorted(nums_anc - nums_doc):
    bloquant("ancrage %d « %s » sans bloc dans le document — le retirer ou vérifier le document"
             % (n, A[str(n)]['lieu']))

# ------------------------------------------- la version consignée au manifeste
version_man = None
if os.path.exists(MAN):
    M = json.load(io.open(MAN, encoding='utf-8'))
    for r in M.get('rubriques', []):
        if r['id'] == 'blocs-itineraire':
            mm = re.search(r'version\s*([\d.]+)', str(r.get('source') or ''), re.I)
            version_man = mm.group(1) if mm else None
if version_man and version_man != version_doc:
    note('')
    note('  Le manifeste consigne la version %s, le document porte la %s.'
         % (version_man, version_doc))
    note("  L'itinéraire a changé : la couche va être reproduite, et la rubrique")
    note("  blocs-itineraire du manifeste doit être mise à jour avec la nouvelle version.")
elif version_man:
    note('  version conforme au manifeste (%s)' % version_man)

if arret:
    note('')
    note('=== aucune couche produite ===')
    note('  %d point(s) à traiter avant de relancer.' % len(arret))
    io.open(os.path.join(OUT, 'RAPPORT38.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
    sys.exit(2)

# ------------------------------------------------------------- géocodage
PAYS = {'SE': 'se', 'NO': 'no', 'FI': 'fi', 'EE': 'ee', 'LV': 'lv', 'LT': 'lt', 'PL': 'pl'}

def geocoder(nom, iso):
    url = ('https://geocoding-api.open-meteo.com/v1/search?name=%s&count=5&language=fr&countryCode=%s'
           % (urllib.parse.quote(nom), iso))
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            d = json.loads(r.read().decode('utf-8'))
    except Exception as e:
        return None, 'échec : ' + str(e)[:60]
    res = d.get('results') or []
    for x in res:
        if str(x.get('country_code', '')).upper() == iso:
            return (x['latitude'], x['longitude']), '%s, %s' % (x.get('name'), x.get('admin1') or x.get('country'))
    if res:
        x = res[0]
        return (x['latitude'], x['longitude']), 'PAYS DIFFÉRENT : %s (%s)' % (x.get('name'), x.get('country_code'))
    return None, 'aucun résultat'

note('')
note('=== géocodage ===')
feats, echecs = [], []
for b in blocs:
    a = A[str(b['n'])]
    coord, detail = geocoder(a['lieu'], a['pays'])
    if not coord:
        echecs.append((b['n'], a['lieu'], detail))
        note('  %2d %-38s %-16s ÉCHEC : %s' % (b['n'], b['nom'][:38], a['lieu'], detail))
        continue
    lat, lon = coord
    note('  %2d %-38s %-16s %.4f, %.4f' % (b['n'], b['nom'][:38], a['lieu'], lat, lon))
    p = {'id': 'bloc-%02d' % b['n'], 'country': PAYS.get(a['pays'], a['pays'].lower()),
         'name': '%d · %s' % (b['n'], b['nom']), 'type': 'bloc',
         'source': 'interne', 'updated': AUJ,
         'numero': b['n'], 'dates': b['dates'], 'contenu': b['contenu'],
         'etape': b['etape'], 'ancrage': a['lieu'], 'ancrage_motif': a.get('motif'),
         'document_version': version_doc}
    feats.append({'type': 'Feature',
                  'geometry': {'type': 'Point', 'coordinates': [round(lon, 5), round(lat, 5)]},
                  'properties': {k: v for k, v in p.items() if v is not None}})
    time.sleep(1.2)

if echecs:
    note('')
    bloquant('%d géocodage(s) en échec : %s'
             % (len(echecs), ', '.join('%d %s' % (n, l) for n, l, _ in echecs)))
    note('  Aucune couche produite : elle serait incomplète.')
    io.open(os.path.join(OUT, 'RAPPORT38.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
    sys.exit(2)

cible = os.path.join(OUT, 'blocs-itineraire.geojson')
json.dump({'type': 'FeatureCollection', 'features': feats},
          io.open(cible, 'w', encoding='utf-8'), ensure_ascii=False)
note('')
note('-> %s : %d blocs, %d octets' % (cible, len(feats), os.path.getsize(cible)))

# contrôle : le profil des latitudes doit suivre la forme du voyage
note('')
note('=== contrôle de cohérence géographique ===')
lat = {f['properties']['numero']: f['geometry']['coordinates'][1] for f in feats}
for n in sorted(lat):
    note('  %2d  %5.2f°N %s' % (n, lat[n], '#' * int((lat[n] - 54) * 1.6)))
note('')
note('  Le profil doit monter jusqu\'au bloc le plus septentrional puis redescendre.')
note('  Une dent isolée signale un ancrage géocodé au mauvais endroit.')

io.open(os.path.join(OUT, 'RAPPORT38.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY
CODE=$?

echo
echo "=========================================="
cat "$OUT/RAPPORT38.txt" 2>/dev/null
echo "=========================================="
if [ "$CODE" -eq 0 ]; then
  echo "Si le rapport est propre, publier :"
  echo "  cp _blocs/blocs-itineraire.geojson sources/"
else
  echo "Production interrompue — voir le rapport ci-dessus."
fi
exit $CODE
