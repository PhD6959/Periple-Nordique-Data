#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 16 : CONVERSION DES COUCHES SUÉDOISES ET FINLANDAISES
# =============================================================================
#
# Ces entités viennent s'ajouter aux couches norvégiennes déjà publiées, dans
# les mêmes fichiers. ATTENTION : cela change la licence de deux d'entre elles.
#   ferries.geojson et tunnels.geojson passent de NLOD seule à NLOD + ODbL,
#   puisqu'elles contiendront des données OpenStreetMap. La propriété « source »
#   de chaque entité dit d'où elle vient — c'est pour cela qu'elle existe.
#
# CE QUE LE PROFIL A MONTRÉ
#   - Les ferries suédois et finlandais sont bien documentés : opérateur, durée
#     de traversée, accès des véhicules. Björköleden, 8 minutes, Färjerederiet.
#   - Les tunnels portent leur hauteur maximale — 183 sur 319 en Suède, 58 sur
#     140 en Finlande. La couche norvégienne ne l'a pas : le type NVDB 581 ne
#     porte pas cet attribut. Les entités suédoises et finlandaises seront donc
#     mieux renseignées que les norvégiennes sur ce point précis.
#   - Les cols sont anecdotiques : 9 en Suède, aucun en Finlande. Ce sont les
#     104 et 88 routes saisonnières qui font l'équivalent local, et elles sont
#     versées dans la couche des cols et fermetures.
#
# FILTRE : les liaisons interdites aux véhicules à moteur sont écartées — canaux
# de plaisance, bacs piétons. « motor_vehicle=no » est explicite.
#
# UTILISATION — depuis le dossier contenant _sefi/
#   bash 03-etape16-conversion-se-fi.sh
# =============================================================================

set -u
python3 - <<'PY'
import json, io, os, collections, datetime

IN = '_sefi'; AUJ = datetime.date.today().isoformat()
rapport = []
def note(s):
    print(s); rapport.append(s)

def categorie(t):
    if t.get('amenity') == 'ferry_terminal': return 'quai'
    if t.get('route') == 'ferry':            return 'liaison'
    if t.get('mountain_pass') == 'yes':      return 'col'
    if t.get('seasonal') or t.get('snowplowing') == 'no': return 'saisonnier'
    if t.get('tunnel') == 'yes':             return 'tunnel'
    return None

def nombre(v):
    try:
        return float(str(v).replace(',', '.').split()[0])
    except (TypeError, ValueError, IndexError):
        return None

PAYS = {'SE': 'se', 'FI': 'fi'}
ferries, tunnels, cols = [], [], []
ecarte = collections.Counter()

for iso, code in PAYS.items():
    c = os.path.join(IN, 'osm-%s.json' % iso)
    if not os.path.exists(c):
        note('fichier absent : ' + c); continue
    els = json.load(io.open(c, encoding='utf-8')).get('elements', [])
    n0 = len(ferries) + len(tunnels) + len(cols)
    for e in els:
        t = e.get('tags', {}) or {}
        cat = categorie(t)
        if not cat:
            ecarte['type non retenu'] += 1; continue
        lat = e.get('lat') or (e.get('center') or {}).get('lat')
        lon = e.get('lon') or (e.get('center') or {}).get('lon')
        if lat is None or lon is None:
            ecarte['sans coordonnées'] += 1; continue
        lat, lon = round(float(lat), 5), round(float(lon), 5)
        if not (2 <= lon <= 34 and 53 <= lat <= 73):
            ecarte['hors emprise'] += 1; continue
        nom = t.get('name')
        geom = {'type': 'Point', 'coordinates': [lon, lat]}
        base = {'id': 'osm-%s-%s' % (e.get('type', 'n')[0], e.get('id')),
                'country': code, 'source': 'OSM', 'updated': AUJ}

        if cat in ('liaison', 'quai'):
            # un canal de plaisance ou un bac piéton n'intéresse pas un fourgon
            if cat == 'liaison' and str(t.get('motor_vehicle', '')).lower() == 'no':
                ecarte['liaison sans véhicules'] += 1; continue
            p = dict(base)
            p.update({'name': nom or ('liaison' if cat == 'liaison' else 'embarcadère'),
                      'type': cat, 'exploitation': t.get('seasonal') and 'saisonnier' or None,
                      'categorie': t.get('route') and 'ferry' or None,
                      'operateur': t.get('operator'), 'duree': t.get('duration'),
                      'vehicules': t.get('motor_vehicle'), 'payant': t.get('fee'),
                      'horaires': t.get('opening_hours'), 'route': t.get('ref')})
            ferries.append({'type': 'Feature', 'geometry': geom,
                            'properties': {k: v for k, v in p.items() if v is not None}})

        elif cat == 'tunnel':
            p = dict(base)
            p.update({'name': nom or 'tunnel', 'type': 'tunnel',
                      'route': t.get('ref'),
                      'longueur_m': nombre(t.get('length')),
                      'hauteur_max_m': nombre(t.get('maxheight')),
                      'poids_max_t': nombre(t.get('maxweight')),
                      'motifs': 'hauteur limitée' if t.get('maxheight') else None})
            tunnels.append({'type': 'Feature', 'geometry': geom,
                            'properties': {k: v for k, v in p.items() if v is not None}})

        else:   # col ou route saisonnière
            p = dict(base)
            p.update({'name': nom or ('col' if cat == 'col' else 'route saisonnière'),
                      'type': 'fjellovergang' if cat == 'col' else 'vinterstengt',
                      'route': t.get('ref'), 'altitude_m': nombre(t.get('ele')),
                      'saison': t.get('seasonal'),
                      'non_deneigee': True if t.get('snowplowing') == 'no' else None,
                      'acces': t.get('access')})
            cols.append({'type': 'Feature', 'geometry': geom,
                         'properties': {k: v for k, v in p.items() if v is not None}})
    note('%s : %d éléments -> %d retenus' % (iso, len(els), len(ferries) + len(tunnels) + len(cols) - n0))

note('')
note('=== écartés ===')
for k, v in ecarte.most_common():
    note('  %-28s %5d' % (k, v))

# ---------------------------------------------------------------- fusion
note('')
note('=== fusion avec les couches norvégiennes ===')
BASE = 'https://raw.githubusercontent.com/PhD6959/Periple-Nordique-Data/main/sources/'
import urllib.request

def fusionner(fichier, nouvelles):
    try:
        with urllib.request.urlopen(BASE + fichier, timeout=60) as r:
            d = json.loads(r.read().decode('utf-8'))
        anciennes = d['features']
    except Exception as e:
        note('  %s : téléchargement impossible (%s) — fusion abandonnée' % (fichier, str(e)[:50]))
        return None
    ids = {f['properties']['id'] for f in anciennes}
    ajout = [f for f in nouvelles if f['properties']['id'] not in ids]
    total = anciennes + ajout
    json.dump({'type': 'FeatureCollection', 'features': total},
              io.open(os.path.join(IN, fichier), 'w', encoding='utf-8'), ensure_ascii=False)
    par_pays = collections.Counter(f['properties']['country'] for f in total)
    par_source = collections.Counter(f['properties']['source'] for f in total)
    note('  %-26s %5d + %5d = %5d entités, %d Ko' % (
        fichier, len(anciennes), len(ajout), len(total),
        os.path.getsize(os.path.join(IN, fichier)) // 1024))
    note('       par pays : %s | par source : %s' % (dict(par_pays), dict(par_source)))
    return total

fusionner('ferries.geojson', ferries)
fusionner('tunnels.geojson', tunnels)
fusionner('cols-fermetures.geojson', cols)

note('')
note('=== échantillons des nouvelles entités ===')
for lot, lib in ((ferries, 'ferry'), (tunnels, 'tunnel'), (cols, 'col ou route saisonnière')):
    ex = next((f for f in lot if len(f['properties']) > 6), lot[0] if lot else None)
    if ex:
        note('  %-24s %s' % (lib, json.dumps(ex['properties'], ensure_ascii=False)[:300]))

io.open(os.path.join(IN, 'RAPPORT16.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _sefi/RAPPORT16.txt
echo "=========================================="
echo "À me transmettre : _sefi/RAPPORT16.txt"
