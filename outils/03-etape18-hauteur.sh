#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 18 : FRANCHISSABILITÉ DES TUNNELS
# =============================================================================
#
# Le fourgon mesure 3,20 m hors tout. Chaque tunnel dont la hauteur maximale est
# connue reçoit deux propriétés :
#   franchissable  faux si la hauteur annoncée est inférieure ou égale à 3,20 m
#   marge_cm       écart entre la hauteur annoncée et 3,20 m
#
# Les tunnels sans hauteur renseignée ne reçoivent rien : une absence de donnée
# n'est pas une autorisation de passer. Ils restent à traiter à la vue.
#
# SEUIL DE VIGILANCE : en dessous de 30 cm de marge, la propriété « vigilance »
# est posée. Une galerie, une antenne ou un affaissement de chaussée mangent
# vite vingt centimètres, et la hauteur annoncée sur un panneau intègre déjà une
# réserve variable selon les pays.
#
# UTILISATION — depuis le dossier contenant _sefi/
#   bash 03-etape18-hauteur.sh
# =============================================================================

set -u
HAUTEUR=3.20

python3 - "$HAUTEUR" <<'PY'
import json, io, os, sys, collections

H = float(sys.argv[1])
VIGILANCE = 0.30
IN = '_sefi'
c = os.path.join(IN, 'tunnels.geojson')
rapport = []
def note(s):
    print(s); rapport.append(s)

d = json.load(io.open(c, encoding='utf-8'))
fs = d['features']

bloquants, serres, inconnus = [], [], 0
for f in fs:
    p = f['properties']
    h = p.get('hauteur_max_m')
    if h is None:
        inconnus += 1
        continue
    marge = round(h - H, 2)
    p['franchissable'] = marge > 0
    p['marge_cm'] = int(round(marge * 100))
    if marge <= 0:
        bloquants.append(p)
    elif marge < VIGILANCE:
        p['vigilance'] = True
        serres.append(p)

json.dump(d, io.open(c, 'w', encoding='utf-8'), ensure_ascii=False)

note('=== franchissabilité, fourgon de %.2f m hors tout ===' % H)
note('  tunnels : %d | hauteur connue : %d | hauteur inconnue : %d'
     % (len(fs), len(fs) - inconnus, inconnus))
note('')
note('  INFRANCHISSABLES : %d' % len(bloquants))
for p in sorted(bloquants, key=lambda x: x['hauteur_max_m']):
    note('    %-34s %s  %.2f m  manque %d cm' % (p['name'][:34], p['country'],
                                                 p['hauteur_max_m'], -p['marge_cm']))
note('')
note('  MARGE INFÉRIEURE À %d cm : %d' % (int(VIGILANCE * 100), len(serres)))
for p in sorted(serres, key=lambda x: x['marge_cm']):
    note('    %-34s %s  %.2f m  marge %d cm' % (p['name'][:34], p['country'],
                                                p['hauteur_max_m'], p['marge_cm']))
note('')
note('  par pays, tunnels à hauteur connue : %s'
     % dict(collections.Counter(f['properties']['country'] for f in fs
                                if f['properties'].get('hauteur_max_m'))))
note('  taille : %d Ko' % (os.path.getsize(c) // 1024))
note('')
note('  RAPPEL : %d tunnels sur %d ne renseignent pas leur hauteur. Une absence' % (inconnus, len(fs)))
note('  de donnée n\'est pas une autorisation de passer.')

io.open(os.path.join(IN, 'RAPPORT18.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _sefi/RAPPORT18.txt
echo "=========================================="
echo "À me transmettre : _sefi/RAPPORT18.txt"
