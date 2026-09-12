#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 10 : CONVERSION DES AIRES DE CAMPING-CAR
# =============================================================================
#
# Produit _aires/aires-camping-car.geojson à partir des trois extractions OSM.
# LICENCE ODbL, comme la couche des services.
#
# CE QUE LE PROFIL A MONTRÉ
#   - « sanitary_dump_station » vaut aussi « no » et « customers » : la présence
#     de l'étiquette ne signifie pas la présence du service. On lit la valeur.
#   - « fee » porte parfois un montant plutôt que oui ou non : « 260 Kr »,
#     « 150 SEK », « 40 SEK/person ». Ces valeurs sont traitées comme payantes
#     et le montant est conservé.
#   - « drinking_water » vaut aussi « boil » en Finlande : eau à faire bouillir,
#     ce qui n'est pas de l'eau potable. Classée à part.
#
# PROPRIÉTÉ CALCULÉE : « equipee » vaut vrai si le point offre au moins l'un des
# trois services décisifs pour un fourgon — vidange, eau potable, électricité.
# C'est elle qui permettra de filtrer à l'affichage.
#
# UTILISATION — depuis le dossier contenant _aires/
#   bash 03-etape10-conversion-aires.sh
# =============================================================================

set -u
python3 - <<'PY'
import json, io, os, collections, datetime

IN = '_aires'; AUJ = datetime.date.today().isoformat()
rapport = []
def note(s):
    print(s); rapport.append(s)

def categorie(t):
    if t.get('amenity') == 'sanitary_dump_station': return 'vidange'
    if t.get('tourism') == 'caravan_site':          return 'aire'
    if t.get('tourism') == 'camp_site':             return 'camping'
    if t.get('amenity') == 'drinking_water':        return 'eau'
    return 'laverie'

GENERIQUE = {'vidange': 'point de vidange', 'aire': 'aire', 'camping': 'camping',
             'eau': 'eau potable', 'laverie': 'laverie'}

def oui(v):
    """Vrai seulement sur une valeur affirmative. « no », « customers » et les
    valeurs conditionnelles ne comptent pas comme un service disponible."""
    return str(v).strip().lower() in ('yes', 'true', '1', 'designated', 'public')

def reserve(v):
    return str(v).strip().lower() in ('customers', 'conditional', 'limited')

def payant(v):
    """« fee » vaut oui, non, ou un montant. Un montant vaut payant."""
    if v is None: return None, None
    s = str(v).strip().lower()
    if s in ('no', 'false', '0'): return False, None
    if s in ('yes', 'true', '1'): return True, None
    return True, str(v).strip()          # montant conservé tel quel

PAYS = {'NO': 'no', 'SE': 'se', 'FI': 'fi'}
feats, vus, hors, lus = [], set(), 0, 0

for iso, code in PAYS.items():
    c = os.path.join(IN, 'osm-%s.json' % iso)
    if not os.path.exists(c):
        note('fichier absent : ' + c); continue
    els = json.load(io.open(c, encoding='utf-8')).get('elements', [])
    lus += len(els); n0 = len(feats)
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
        cle = (cat, lat, lon)
        if cle in vus:
            continue
        vus.add(cle)

        vid = t.get('sanitary_dump_station')
        eau = t.get('drinking_water')
        elec = t.get('power_supply')
        pay, montant = payant(t.get('fee'))

        p = {'id': 'osm-%s-%s' % (e.get('type', 'n')[0], e.get('id')),
             'country': code, 'name': t.get('name') or GENERIQUE[cat],
             'type': cat, 'source': 'OSM', 'updated': AUJ,
             'exploitant': t.get('operator') or t.get('brand'),
             'vidange': True if (cat == 'vidange' or oui(vid)) else (False if vid is not None else None),
             'vidange_reservee': True if reserve(vid) else None,
             'eau_potable': True if (cat == 'eau' and eau is None) or oui(eau) else (False if eau is not None else None),
             'eau_a_bouillir': True if str(eau).lower() == 'boil' else None,
             'electricite': True if oui(elec) else (False if elec is not None else None),
             'douche': True if oui(t.get('shower')) else None,
             'toilettes': True if oui(t.get('toilets')) else None,
             'machine_a_laver': True if oui(t.get('washing_machine')) else None,
             'caravanes': True if oui(t.get('caravans')) else None,
             'payant': pay, 'montant': montant,
             'horaires': t.get('opening_hours')}
        p['equipee'] = bool(p['vidange'] or p['eau_potable'] or p['electricite'])
        feats.append({'type': 'Feature',
                      'geometry': {'type': 'Point', 'coordinates': [lon, lat]},
                      'properties': {k: v for k, v in p.items() if v is not None}})
    note('%s : %d éléments -> %d retenus' % (iso, len(els), len(feats) - n0))

note('')
note('lus : %d | retenus : %d | hors emprise : %d | doublons ou sans coordonnées : %d'
     % (lus, len(feats), hors, lus - len(feats) - hors))
note('')
note('=== répartition ===')
note('  par catégorie : %s' % dict(collections.Counter(f['properties']['type'] for f in feats)))
note('  par pays      : %s' % dict(collections.Counter(f['properties']['country'] for f in feats)))
eq = [f for f in feats if f['properties'].get('equipee')]
note('  équipées (vidange, eau ou électricité) : %d sur %d' % (len(eq), len(feats)))
note('  dont par catégorie : %s' % dict(collections.Counter(f['properties']['type'] for f in eq)))
for cle, lib in (('vidange', 'vidange disponible'), ('eau_potable', 'eau potable'),
                 ('electricite', 'électricité'), ('douche', 'douche'),
                 ('machine_a_laver', 'machine à laver'), ('caravanes', 'caravanes admises')):
    note('  %-22s %5d' % (lib, sum(1 for f in feats if f['properties'].get(cle) is True)))
note('  payant : %d | gratuit : %d | non renseigné : %d' % (
    sum(1 for f in feats if f['properties'].get('payant') is True),
    sum(1 for f in feats if f['properties'].get('payant') is False),
    sum(1 for f in feats if 'payant' not in f['properties'])))
note('  vidange réservée aux clients : %d' % sum(1 for f in feats if f['properties'].get('vidange_reservee')))
note('  eau à faire bouillir : %d' % sum(1 for f in feats if f['properties'].get('eau_a_bouillir')))
note('  avec un nom propre : %d' % sum(1 for f in feats if f['properties']['name'] not in GENERIQUE.values()))

ops = collections.Counter(f['properties'].get('exploitant') for f in feats if f['properties'].get('exploitant'))
note('')
note('=== exploitants les plus fréquents ===')
for n, c2 in ops.most_common(8):
    note('  %-38s %5d' % (n[:38], c2))

json.dump({'type': 'FeatureCollection', 'features': feats},
          io.open(os.path.join(IN, 'aires-camping-car.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
note('')
note('-> aires-camping-car.geojson : %d entités, %d Ko'
     % (len(feats), os.path.getsize(os.path.join(IN, 'aires-camping-car.geojson')) // 1024))

note('')
note('=== échantillons ===')
for cat in ('aire', 'vidange', 'camping'):
    ex = next((f for f in feats if f['properties']['type'] == cat and f['properties'].get('equipee')), None)
    if ex:
        note('  ' + json.dumps(ex['properties'], ensure_ascii=False)[:420])

io.open(os.path.join(IN, 'RAPPORT10.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _aires/RAPPORT10.txt
echo "=========================================="
echo "À me transmettre : _aires/RAPPORT10.txt"
