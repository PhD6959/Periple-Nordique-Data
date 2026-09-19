#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
CORRECTIF PONCTUEL — CLASSEURS ÉCRITS PAR SCRIPT : UTF-8 DIRECT
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 19 septembre 2026 à 16:26 (heure de Paris)
=============================================================================

POURQUOI
  Constat du 19/09 : les icônes du classeur du module 06 étaient cassées
  depuis le 14/09. openpyxl écrit les emojis en références numériques
  (&#129413; pour l'aigle) ; SheetJS 0.18.5, qui lit les classeurs dans les
  modules, les tronque à seize bits — l'aigle U+1F985 devenait U+F985.
  Reproduit avec la même version de SheetJS, corrigé en réécrivant les
  feuilles XML en UTF-8 direct.

CE QU'IL FAIT
  - ajoute la question tranchée « classeurs-utf8 » ;
  - ajoute la règle à conventions_de_travail, clé
    « classeurs_ecrits_par_script », placée avant « sauvegarde » ;
  - passe le manifeste de 1.43 à 1.44, genere_le au 19/09/2026 16:26.
  Réécriture au format exact d'origine, contrôlé avant toute écriture.

UTILISATION — depuis n'importe où
    python3 outils/corriger-manifeste-classeurs.py
    python3 outils/corriger-manifeste-classeurs.py --ecrire
    python3 outils/gen-suivi.py
=============================================================================
"""

import io
import json
import os
import sys

ECRIRE = '--ecrire' in sys.argv
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFESTE = os.path.join(RACINE, 'manifest-donnees.json')

AVANT, APRES = '1.43', '1.44'
GENERE_LE = '2026-09-19T16:26:00+02:00'

QUESTION = {
 "id": "classeurs-utf8",
 "titre": "Classeurs écrits par script — UTF-8 direct, sinon les emojis cassent",
 "priorite": "basse",
 "pour": "claude",
 "statut": "arbitrée le 19/09/2026",
 "constat": "Les icônes du classeur 06-liens-internet-nsf-data.xlsx s'affichaient cassées dans le module depuis le 14/09 : pictogramme rayé à la place de 🌦️, 🛣️, 🆘, 📷, et un idéogramme chinois à la place de 🦅. Seul ⚠️, hors du plan astral, passait. openpyxl écrit les caractères non ASCII en références numériques (&#129413;) ; SheetJS 0.18.5 les décode sur seize bits, U+1F985 devenant U+F985. Reproduit avec SheetJS 0.18.5 sur le classeur du 14/09 et sur celui du 19/09.",
 "reponse": "ARBITRÉ : tout classeur écrit ou modifié par un script est réécrit en UTF-8 direct avant d'être déposé — les références numériques des feuilles XML sont décodées. Classeur 06 corrigé le 19/09, commit 569d587 du dépôt applicatif ; affichage constaté juste par Philippe. Un classeur enregistré depuis Excel n'a pas ce défaut.",
 "a_creuser": "Les classeurs 08 (vide) et 12 n'ont pas été contrôlés. Le script outils/enrichir-livres-isbn.py écrit par openpyxl : ses copies sont concernées si un titre, un auteur ou un éditeur porte un caractère hors du plan de base. Le comportement de l'openpyxl du Mac de Philippe n'a pas été vérifié.",
 "consequence": "Règle inscrite à conventions_de_travail, clé classeurs_ecrits_par_script."
}

CLE = 'classeurs_ecrits_par_script'
REGLE = ("Tout classeur .xlsx écrit ou modifié par un script — openpyxl compris — est réécrit en "
         "UTF-8 direct avant d'être déposé : les références numériques des feuilles XML sont "
         "décodées. Sinon SheetJS 0.18.5, qui lit les classeurs dans les modules, tronque les "
         "emojis. Un classeur enregistré depuis Excel n'est pas concerné. Décidé le 19/09/2026 — "
         "voir la question classeurs-utf8.")


class Arret(Exception):
    pass


def main():
    print('Manifeste : %s' % MANIFESTE)
    print('Mode      : %s\n' % ('ÉCRITURE' if ECRIRE else 'contrôle seul'))
    if not os.path.exists(MANIFESTE):
        print('ARRÊT — manifeste introuvable.')
        return 1
    texte = io.open(MANIFESTE, encoding='utf-8').read()
    m = json.loads(texte)

    def dump(obj):
        return json.dumps(obj, ensure_ascii=False, indent=2) + '\n'

    try:
        if dump(m) != texte:
            raise Arret('format du fichier inattendu')
        v = m.get('manifest', {}).get('version')
        print('  version du manifeste             %s (attendue %s)' % (v, AVANT))
        if v != AVANT:
            raise Arret('manifeste en %s, pas en %s' % (v, AVANT))
        qo = m.get('questions_ouvertes')
        if not isinstance(qo, list):
            raise Arret('questions_ouvertes absente ou mal formée')
        present = any(q.get('id') == QUESTION['id'] for q in qo)
        print('  question %-32s %s' % (QUESTION['id'], 'DÉJÀ PRÉSENTE' if present else 'à ajouter'))
        if present:
            raise Arret('la question existe déjà')
        conv = m.get('conventions_de_travail')
        if not isinstance(conv, dict) or 'sauvegarde' not in conv:
            raise Arret('conventions_de_travail absente, ou sans clé « sauvegarde »')
        print('  convention %-30s %s' % (CLE, 'DÉJÀ PRÉSENTE' if CLE in conv else 'à ajouter'))
        if CLE in conv:
            raise Arret('la clé %s existe déjà' % CLE)
    except Arret as e:
        print("\nARRÊT — rien n'a été écrit.\n  %s" % e)
        return 1

    qo.append(QUESTION)
    nouvelle = {}
    for k, val in conv.items():
        if k == 'sauvegarde':
            nouvelle[CLE] = REGLE
        nouvelle[k] = val
    m['conventions_de_travail'] = nouvelle
    m['manifest']['version'] = APRES
    m['manifest']['genere_le'] = GENERE_LE
    print('\n  questions : %d au total, dont %d sans réponse'
          % (len(qo), sum(1 for q in qo if not q.get('reponse'))))
    print('  version   : %s -> %s' % (AVANT, APRES))
    if not ECRIRE:
        print("\nContrôle seul : rien n'est touché. Relancer avec --ecrire.")
        return 0
    io.open(MANIFESTE, 'w', encoding='utf-8').write(dump(m))
    print('\nécrit : manifest-donnees.json')
    print('Ensuite : python3 outils/gen-suivi.py')
    return 0


if __name__ == '__main__':
    sys.exit(main())
