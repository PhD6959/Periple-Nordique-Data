#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Suède
# ÉTAPE 22 : INVENTAIRE DE SITUATION
# =============================================================================
#
# Schemaversion 1.6, relevée dans le banc d'essai du portail. Mes essais
# s'arrêtaient à 1.5, d'après une documentation tierce périmée. C'est la
# troisième fois aujourd'hui que cette documentation induit en erreur : noms de
# types disparus, espaces de noms omis, versions dépassées. Le banc d'essai du
# portail est la seule référence fiable.
#
# CE QU'ON CHERCHE : les catégories de déviation exposées, et en particulier
#   Bärighetsnedsättning   restriction de portance — le dégel
#   Kolonnkörning          conduite en convoi — les cols l'hiver
#   Avvikande färjetider   horaires de bacs modifiés
#
# On demande 500 enregistrements pour avoir une vue représentative, et on
# dénombre les catégories plutôt que d'afficher les objets.
#
# LA CLÉ EST LUE DANS ~/.trafikverket-key.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape22-situation.sh
# =============================================================================

set -u
OUT="_trv"; mkdir -p "$OUT"
CLE_FICHIER="$HOME/.trafikverket-key"
API="https://api.trafikinfo.trafikverket.se/v2/data.json"

[ -s "$CLE_FICHIER" ] || { echo "Clé absente : $CLE_FICHIER"; exit 1; }
CLE=$(cat "$CLE_FICHIER")

echo "== Situation, 500 enregistrements =="
REQ="<REQUEST><LOGIN authenticationkey=\"$CLE\" /><QUERY objecttype=\"Situation\" namespace=\"road.trafficinfo\" schemaversion=\"1.6\" limit=\"500\"></QUERY></REQUEST>"
curl -sS -X POST -H "Content-Type: text/xml" -d "$REQ" "$API" -o "$OUT/situation.json"
echo "   $(du -h "$OUT/situation.json" | cut -f1)"

python3 - <<'PY' > "$OUT/PROFIL22.txt" 2>&1
import json, io, os, collections, datetime

c = '_trv/situation.json'
try:
    d = json.load(io.open(c, encoding='utf-8'))
except Exception as e:
    print('illisible :', str(e)[:120]); raise SystemExit

res = d['RESPONSE']['RESULT'][0]
if 'ERROR' in res:
    print('REFUS :', res['ERROR'].get('MESSAGE')); raise SystemExit
lot = res.get('Situation', [])
print('=== Situation, schemaversion 1.6 ===')
print('  situations : %d' % len(lot))

devs = [x for s in lot for x in (s.get('Deviation') or [])]
print('  déviations : %d' % len(devs))
print('')

def compter(champ, titre, n=20):
    c = collections.Counter(str(x.get(champ)) for x in devs if x.get(champ) is not None)
    if not c:
        print('  %s : champ absent' % titre); return
    print('  %s — %d valeurs distinctes' % (titre, len(c)))
    for k, v in c.most_common(n):
        print('    %-46s %5d' % (k[:46], v))
    print('')

compter('MessageType', 'MessageType')
compter('MessageCode', 'MessageCode')
compter('SeverityText', 'Gravité')
compter('AffectedDirection', 'Direction affectée')

# ce qui nous intéresse nommément
CIBLES = ['Bärighetsnedsättning', 'Kolonnkörning', 'Avvikande färjetider',
          'Vägarbete', 'Olycka', 'Viktig information', 'Oförutsedda hinder']
print('  === catégories recherchées ===')
for cible in CIBLES:
    n = sum(1 for x in devs
            if cible.lower() in (str(x.get('MessageType', '')) + ' ' +
                                 str(x.get('MessageCode', '')) + ' ' +
                                 str(x.get('Message', ''))).lower())
    print('    %-28s %s' % (cible, n if n else 'absent aujourd\'hui'))
print('')

# champs disponibles sur une déviation, pour une conversion future
if devs:
    ch = collections.Counter()
    for x in devs:
        for k in x:
            ch[k] += 1
    print('  champs d\'une déviation, par fréquence :')
    for k, v in ch.most_common():
        print('    %-34s %4d / %d' % (k, v, len(devs)))
    print('')
    print('  exemple complet :')
    ex = max(devs, key=len)
    for k in sorted(ex):
        print('    %-30s %s' % (k, json.dumps(ex[k], ensure_ascii=False)[:150]))

# fraîcheur : ces données sont-elles vivantes en septembre ?
dates = [s.get('PublicationTime') or s.get('ModifiedTime') for s in lot]
dates = sorted(x for x in dates if x)
if dates:
    print('')
    print('  publication la plus ancienne : %s' % dates[0][:10])
    print('  publication la plus récente  : %s' % dates[-1][:10])
PY

echo
echo "=========================================="
cat "$OUT/PROFIL22.txt"
echo "=========================================="
echo "À me transmettre : $OUT/PROFIL22.txt — la clé n'y figure pas."
