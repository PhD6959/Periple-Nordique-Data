#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
CORRECTIF PONCTUEL — reprise du chat de recherche, désormais versionnée
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 26 septembre 2026 à 15:03 (heure de Paris)
=============================================================================

La question « reprise-recherche-hors-depot » disait ce document hors dépôt,
arbitrage du 16/09 à l'appui. Il est versionné depuis le 21/09 sous
Periple-Nordique/docs/reprise-periple-nordique.md : la question est close et
sa conséquence n'a plus lieu d'être.

Substitutions EXACTES sur le texte du manifeste, pour n'en pas réordonner les
clés : contrôle seul par défaut, arrêt avant toute écriture si un motif manque.

UTILISATION — depuis la racine du dépôt de données
    python3 outils/corriger-manifeste-26-09.py            contrôle seul
    python3 outils/corriger-manifeste-26-09.py --ecrire   applique
=============================================================================
"""
import datetime
import io
import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CIBLE = os.path.join(RACINE, 'manifest-donnees.json')
ECRIRE = '--ecrire' in sys.argv
try:
    from zoneinfo import ZoneInfo
    N = datetime.datetime.now(ZoneInfo('Europe/Paris'))
except Exception:
    N = datetime.datetime.now()

SUBS = [
 ('statut de la question',
  '"statut": "arbitrée le 16/09/2026",\n      "constat": "Deux chats travaillent sur le périple',
  '"statut": "close le 21/09/2026",\n      "constat": "Deux chats travaillent sur le périple'),
 ('réponse',
  '"reponse": "ARBITRÉ : on le laisse dans le Contexte du projet, le chat de recherche le porte aussi."',
  '"reponse": "CLOS : le document est versionné depuis le 21/09/2026 sous Periple-Nordique/docs/reprise-periple-nordique.md. L\'arbitrage du 16/09 — le laisser dans le seul Contexte — est caduc : le Contexte en garde l\'original, le dépôt une copie sauvegardée."'),
 ('conséquence',
  '"consequence": "Une perte du Contexte du projet emporterait ce document : il n\'a pas de copie dans les dépôts."',
  '"consequence": "Plus de conséquence : le document a une copie versionnée. Reste que son contenu décrit l\'état du 11 septembre — neuf ou dix modules, vingt-huit tuiles — et sera à rafraîchir à la prochaine session de recherche."'),
 ('version du manifeste',
  '"version": "1.46"',
  '"version": "1.47"'),
]

print('=== manifest-donnees.json')
if not os.path.exists(CIBLE):
    print('  INTROUVABLE : %s' % CIBLE)
    sys.exit(1)
s = io.open(CIBLE, encoding='utf-8').read()
avant, ok = s, True
for nom, a, b in SUBS:
    if b in s:
        print('  %-24s déjà fait' % nom)
        continue
    n = s.count(a)
    if n == 1:
        s = s.replace(a, b)
        print('  %-24s à corriger' % nom)
    else:
        ok = False
        print('  %-24s MOTIF %s — rien ne sera écrit'
              % (nom, 'INTROUVABLE' if n == 0 else 'AMBIGU (%d)' % n))

if not ok:
    print("\nARRÊT : un motif au moins manque ou est ambigu. Rien n'a été écrit.")
    sys.exit(1)
if s == avant:
    print('\nTout est déjà fait.')
    sys.exit(0)
try:
    json.loads(s)
except Exception as e:
    print("\nARRÊT : le résultat n'est pas un JSON valide (%s). Rien n'a été écrit." % e)
    sys.exit(1)
print('  JSON relu et valide')
if not ECRIRE:
    print('\nCONTRÔLE SEUL — relancer avec --ecrire pour appliquer.')
    sys.exit(0)
io.open(CIBLE, 'w', encoding='utf-8').write(s)
print('écrit : manifest-donnees.json — version 1.47, %02d/%02d/%d %02d:%02d'
      % (N.day, N.month, N.year, N.hour, N.minute))
