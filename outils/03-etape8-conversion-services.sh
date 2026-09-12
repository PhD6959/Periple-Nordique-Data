#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 8 : CONVERSION DES SERVICES — version 1.1
# =============================================================================
#
# Produit _services/services.geojson à partir des trois extractions OSM.
#
# TABLE DE NORMALISATION : établie à partir des libellés réellement observés au
# profil de l'étape 7, et non de mémoire. Elle traite trois cas :
#   - la casse : Seo / SEO, st1 / ST1 / St1, systembolaget / Systembolaget
#   - les variantes : Bunker oil / Bunker Oil, din-X / Din-X, Handlar'n / Handlarn
#   - les déclinaisons : Shell Express, Teboil D, ABC!, Systembolaget Ånge,
#     Gulating Larvik, Coop (Sweden) — ramenées à l'enseigne mère.
#
# La correspondance se fait par plus longue enseigne d'abord, et à l'intérieur
# d'une même catégorie : « Neste K » est une enseigne d'alimentation distincte
# de « Neste », station-service.
#
# CHANGEMENTS v1.1, d'après le rapport du 10/09/2026
#   - Repli inter-catégories : « Preem » et « St1 » n'étaient pas reconnus quand
#     la station porte shop=convenience sans amenity=fuel, donc classée en
#     alimentation, où ces enseignes n'étaient pas listées. La correspondance
#     essaie désormais la catégorie de l'objet, puis les autres.
#   - Enseignes ajoutées, relevées parmi les non-reconnus : MyWay, 24 SJU,
#     AutoMat, Alltank, Pekås, Huili, X:-tra, Dalvik Oil, Bunker Oil déjà présent.
#   - « Independent » écarté : ce n'est pas une enseigne mais un marqueur
#     signalant une station sans marque.
#
# LICENCE : ODbL. La couche produite est dérivée d'OpenStreetMap, l'attribution
# est obligatoire et la licence se propage.
#
# UTILISATION — depuis le dossier contenant _services/
#   bash 03-etape8-conversion-services.sh
# =============================================================================

set -u
python3 - <<'PY'
import json, io, os, collections, datetime, unicodedata

IN = '_services'; AUJ = datetime.date.today().isoformat()
rapport = []
def note(s):
    print(s); rapport.append(s)

# --------------------------------------------------------------- enseignes
# Relevées au profil du 10/09/2026. L'ordre n'importe pas : la correspondance
# essaie les plus longues d'abord.
ENSEIGNES = {
 'carburant': ['Circle K', 'Uno-X', 'St1', 'YX', 'Esso', 'Driv', 'LPG Norge', 'Automat1',
   'Bunker Oil', 'Tanken', 'Best', 'Trønder Oil', 'Haltbakk Express', 'Gasum', 'Preem',
   'Knapphus', 'MH24', 'OKQ8', 'Ingo', 'Qstar', 'Tanka', 'Din-X', 'Gulf', 'Bilisten',
   'Såifa', 'Fordonsgas', 'E.ON', 'PS Energi', 'Oljeshejkerna Johnsson',
   'Neste Truck', 'Neste', 'ABC', 'Teboil', 'SEO', 'Shell', 'BIG',
   'MyWay', '24 SJU', 'AutoMat', 'Alltank', 'Dalvik Oil', 'Runes Bensin & Oljeimport'],
 'alimentation': ['Kiwi', 'Rema 1000', 'Extra', 'Joker', 'Spar', 'Coop Prix', 'Bunnpris',
   'Meny', 'Nærbutikken', '7-Eleven', 'Coop Marked', 'Coop Mega', 'Matkroken', 'Snarkjøp',
   'Mix', 'Obs', 'Deli de Luca', 'Holdbart', 'Europris', 'Circle K',
   'Maxi ICA Stormarknad', 'ICA Supermarket', 'ICA Kvantum', 'ICA Nära', 'ICA',
   'Coop', 'Willys', 'Hemköp', 'Lidl', 'Tempo', 'Handlarn', 'Direkten', 'City Gross',
   'Frendo', 'Matöppet', 'OKQ8', 'Pressbyrån',
   'K-Citymarket', 'K-Supermarket', 'K-Market', 'S-market', 'Sale', 'Alepa', 'Prisma',
   'HalpaHalli', 'Neste K', 'M-Market', 'Minimani', 'ABC',
   'Pekås', 'Huili', 'X:-tra'],
 'alcool': ['Vinmonopolet', 'Vinmonopol', 'Nordpolet', 'Gulating', 'Systembolaget', 'Alko']
}
# variantes qui ne se ramènent pas par simple préfixe
ALIAS = {"handlar'n": 'Handlarn', 'coop (sweden)': 'Coop', 'vinmonopol': 'Vinmonopolet',
         'såifa': 'Såifa', 'saifa': 'Såifa', 'din-x': 'Din-X', 'bunker oil': 'Bunker Oil'}
MONOPOLES = {'Vinmonopolet', 'Systembolaget', 'Alko', 'Nordpolet'}
# marqueurs OSM qui ne désignent aucune enseigne
NON_ENSEIGNES = {'independent', 'yes', 'no', 'unknown', 'privat', 'private'}

def norm(s):
    s = unicodedata.normalize('NFD', str(s or '').lower())
    return ''.join(c for c in s if unicodedata.category(c) != 'Mn').replace("'", '').strip()

PREPARE = {c: sorted(l, key=len, reverse=True) for c, l in ENSEIGNES.items()}
NORMES = {c: [(norm(e), e) for e in l] for c, l in PREPARE.items()}

def correspond(n, cat):
    for nn, e in NORMES[cat]:
        if n == nn or n.startswith(nn + ' ') or n.startswith(nn + '!') or n.startswith(nn + ','):
            return e
    return None

def enseigne(brut, cat):
    """Cherche d'abord dans la catégorie de l'objet — « Neste K », commerce, ne
    doit pas être confondu avec « Neste », station-service — puis dans les
    autres, une station pouvant être étiquetée comme un commerce."""
    n = norm(brut)
    if not n or n in NON_ENSEIGNES:
        return None
    if n in ALIAS:
        return ALIAS[n]
    e = correspond(n, cat)
    if e:
        return e
    for autre in NORMES:
        if autre != cat:
            e = correspond(n, autre)
            if e:
                return e
    return None

def categorie(t):
    return ('carburant' if t.get('amenity') == 'fuel'
            else 'alcool' if t.get('shop') == 'alcohol'
            else 'alimentation')

def oui(v):
    return str(v).lower() in ('yes', 'true', '1')

PAYS = {'NO': 'no', 'SE': 'se', 'FI': 'fi'}
feats, vus, hors, sans_ens = [], set(), 0, collections.Counter()

for iso, code in PAYS.items():
    c = os.path.join(IN, 'osm-%s.json' % iso)
    if not os.path.exists(c):
        note('fichier absent : ' + c); continue
    els = json.load(io.open(c, encoding='utf-8')).get('elements', [])
    n0 = len(feats)
    for e in els:
        t = e.get('tags', {}) or {}
        lat = e.get('lat') or (e.get('center') or {}).get('lat')
        lon = e.get('lon') or (e.get('center') or {}).get('lon')
        if lat is None or lon is None:
            continue
        lat, lon = round(float(lat), 5), round(float(lon), 5)
        if not (2 <= lon <= 34 and 53 <= lat <= 73):
            hors += 1; continue
        cat = categorie(t)
        brut = t.get('brand') or t.get('operator') or t.get('name') or ''
        ens = enseigne(brut, cat)
        if brut and not ens:
            sans_ens[brut] += 1
        cle = (cat, lat, lon, norm(brut))
        if cle in vus:
            continue
        vus.add(cle)
        nom = ens or (brut if brut else {'carburant': 'station-service',
                                         'alimentation': 'commerce',
                                         'alcool': 'boisson'}[cat])
        p = {'id': 'osm-%s-%s' % (e.get('type', 'n')[0], e.get('id')),
             'country': code, 'name': nom, 'type': cat,
             'source': 'OSM', 'updated': AUJ,
             'enseigne': ens, 'libelle_source': brut or None,
             'horaires': t.get('opening_hours')}
        if cat == 'carburant':
            p['gazole'] = oui(t.get('fuel:diesel')) or None
            p['gpl'] = oui(t.get('fuel:lpg')) or None
            p['air_comprime'] = oui(t.get('compressed_air')) or None
        if cat == 'alcool':
            p['monopole'] = ens in MONOPOLES
        feats.append({'type': 'Feature',
                      'geometry': {'type': 'Point', 'coordinates': [lon, lat]},
                      'properties': {k: v for k, v in p.items() if v is not None}})
    note('%s : %d éléments -> %d retenus' % (iso, len(els), len(feats) - n0))

note('')
total_lus = 0
for i in PAYS:
    c = os.path.join(IN, 'osm-%s.json' % i)
    if os.path.exists(c):
        total_lus += len(json.load(io.open(c, encoding='utf-8')).get('elements', []))
note('lus : %d | retenus : %d | hors emprise : %d | sans coordonnées ou doublons : %d'
     % (total_lus, len(feats), hors, total_lus - len(feats) - hors))
note('')
note('=== répartition ===')
note('  par catégorie : %s' % dict(collections.Counter(f['properties']['type'] for f in feats)))
note('  par pays      : %s' % dict(collections.Counter(f['properties']['country'] for f in feats)))
ens_ok = sum(1 for f in feats if f['properties'].get('enseigne'))
note('  enseigne reconnue : %d sur %d (%.0f %%)' % (ens_ok, len(feats), 100.0 * ens_ok / max(1, len(feats))))
mono = sum(1 for f in feats if f['properties'].get('monopole'))
note('  points de monopole d\'alcool : %d' % mono)
note('  avec horaires : %d' % sum(1 for f in feats if f['properties'].get('horaires')))
note('  gazole renseigné : %d | GPL : %d | air comprimé : %d' % (
    sum(1 for f in feats if f['properties'].get('gazole')),
    sum(1 for f in feats if f['properties'].get('gpl')),
    sum(1 for f in feats if f['properties'].get('air_comprime'))))

note('')
note('=== libellés non ramenés à une enseigne, les 15 plus fréquents ===')
for n, c2 in sans_ens.most_common(15):
    note('  %-40s %5d' % (n[:40], c2))

json.dump({'type': 'FeatureCollection', 'features': feats},
          io.open(os.path.join(IN, 'services.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
note('')
note('-> services.geojson : %d entités, %d Ko' % (len(feats), os.path.getsize(os.path.join(IN, 'services.geojson')) // 1024))

note('')
note('=== échantillons ===')
for cat in ('carburant', 'alimentation', 'alcool'):
    ex = next((f for f in feats if f['properties']['type'] == cat and f['properties'].get('enseigne')), None)
    if ex:
        note('  ' + json.dumps(ex['properties'], ensure_ascii=False)[:400])

io.open(os.path.join(IN, 'RAPPORT8.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _services/RAPPORT8.txt
echo "=========================================="
echo "À me transmettre : _services/RAPPORT8.txt"
