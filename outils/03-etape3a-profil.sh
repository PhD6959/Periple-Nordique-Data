#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 3a : PROFILAGE DES PROPRIÉTÉS
# =============================================================================
#
# Les fichiers de l'étape 2 sont trop volumineux pour transiter par le fil.
# Ce script n'en extrait qu'un profil : la liste des propriétés présentes,
# avec un exemple de valeur, et deux objets complets en échantillon.
#
# Sortie attendue : quelques kilo-octets, à recoller dans le fil. C'est ce
# qui me permettra d'écrire la conversion sans deviner un seul nom de champ.
#
# UTILISATION — depuis le dossier contenant _extract/
#   bash 03-etape3a-profil.sh
# =============================================================================

set -u
IN="_extract"
OUT="$IN/PROFIL.txt"
: > "$OUT"

python3 - <<'PY' >> "$OUT" 2>&1
import json, io, os, collections

FICHIERS = [
    ('no-107-vaerutsatt-veg.json',  'NO 107 Værutsatt veg'),
    ('no-883-skredutsatt-veg.json', 'NO 883 Skredutsatt veg'),
    ('no-770-ferjesamband.json',    'NO 770 Ferjesamband'),
    ('no-64-ferjekai.json',         'NO 64 Ferjekai'),
]

def apercu(v, n=60):
    s = str(v).replace('\n', ' ')
    return s[:n] + ('…' if len(s) > n else '')

for nom_fichier, titre in FICHIERS:
    chemin = os.path.join('_extract', nom_fichier)
    print('=' * 70)
    print(titre, '—', nom_fichier)
    if not os.path.exists(chemin):
        print('  fichier absent')
        continue
    try:
        objets = json.load(io.open(chemin, encoding='utf-8'))
    except Exception as e:
        print('  illisible :', str(e)[:120]); continue
    print('  objets :', len(objets))
    if not objets:
        continue

    # 1. clés de premier niveau
    cles = collections.Counter()
    for o in objets[:500]:
        cles.update(o.keys())
    print('  clés de premier niveau :', ', '.join(sorted(cles)))

    # 2. propriétés métier (egenskaper), avec fréquence et exemple
    props = collections.OrderedDict()
    for o in objets:
        for e in (o.get('egenskaper') or []):
            k = (e.get('id'), e.get('navn'), e.get('egenskapstype'))
            if k not in props:
                props[k] = [0, e.get('verdi')]
            props[k][0] += 1
    print('  propriétés (id | nom | type | présence | exemple) :')
    for (eid, navn, etype), (n, ex) in sorted(props.items(), key=lambda x: -x[1][0]):
        print('    %-6s | %-38s | %-12s | %5d | %s' % (eid, apercu(navn, 38), apercu(etype, 12), n, apercu(ex)))

    # 3. type de géométrie
    geoms = collections.Counter()
    srids = collections.Counter()
    for o in objets:
        g = o.get('geometri') or {}
        w = str(g.get('wkt', ''))
        geoms[w.split('(')[0].strip()[:20]] += 1
        srids[g.get('srid')] += 1
    print('  géométries :', dict(geoms))
    print('  srid :', dict(srids))

    # 4. un objet complet, géométrie tronquée
    o = dict(objets[0])
    g = dict(o.get('geometri') or {})
    if 'wkt' in g:
        g['wkt'] = apercu(g['wkt'], 120)
    o['geometri'] = g
    print('  échantillon :')
    print('   ', json.dumps(o, ensure_ascii=False)[:1400])
    print()

# ---- Finlande : profil de la couche kelirikko
print('=' * 70)
print('FI kelirikko — fi-kelirikko.geojson')
try:
    d = json.load(io.open('_extract/fi-kelirikko.geojson', encoding='utf-8'))
    fs = d.get('features', [])
    print('  entités récupérées :', len(fs))
    print('  ATTENTION : 5000 est exactement le plafond demandé — le jeu est peut-être tronqué.')
    if fs:
        p = fs[0].get('properties', {})
        for k in sorted(p):
            print('    %-14s = %s' % (k, apercu(p[k])))
        print('  géométrie du premier :', apercu(json.dumps(fs[0].get('geometry', {}), ensure_ascii=False), 160))
        vals = collections.Counter(str(f['properties'].get('arvo')) for f in fs)
        print('  valeurs distinctes de « arvo » :', dict(vals.most_common(10)))
        rep = collections.Counter(str(f['properties'].get('toistuva')) for f in fs)
        print('  valeurs distinctes de « toistuva » :', dict(rep.most_common(5)))
except Exception as e:
    print('  illisible :', str(e)[:150])
PY

# ---- Finlande : nombre réel d'entités, pour savoir si 5000 tronque
echo >> "$OUT"
echo "== FI kelirikko : comptage réel ==" >> "$OUT"
curl -sS "https://avoinapi.vaylapilvi.fi/vaylatiedot/digiroad/wfs?service=WFS&version=2.0.0&request=GetFeature&typeNames=digiroad:dr_kelirikko&resultType=hits" \
  -o "$IN/fi-kelirikko-hits.xml"
grep -o 'numberMatched="[0-9]*"' "$IN/fi-kelirikko-hits.xml" >> "$OUT" 2>/dev/null || \
  head -c 300 "$IN/fi-kelirikko-hits.xml" >> "$OUT"

echo
echo "=========================================="
cat "$OUT"
echo "=========================================="
echo "Taille du profil : $(du -h "$OUT" | cut -f1) — à recoller dans le fil"
