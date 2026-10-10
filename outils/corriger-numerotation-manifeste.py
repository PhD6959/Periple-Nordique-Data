#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
ARBITRAGE DE NUMÉROTATION — LES NUMÉROS DITS LIBRES NE LE SONT PLUS
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 10 octobre 2026 à 14:55 (heure de Paris)
=============================================================================

POURQUOI. La question « numerotation-modules », arbitrée le 14/09, porte dans
son champ « a_creuser » :

    « les numéros islandais correspondants sont libres côté nordique :
      11, 12, 14, 16, 17, 18, 19, 21, 22, 89 »

TROIS DE CES NUMÉROS SONT PRIS depuis, et le manifeste est la source de vérité
du projet : une reprise qui s'y fie poserait un module sur un numéro occupé.

    11  fichiers GPS, trois documents et trois tuiles
    12  livres et cartes, depuis le 26/09 — c'est ce numéro que l'arbitrage
        réservait au drone islandais. Philippe a tranché le 10/10 : on oublie
        le drone, le 12 reste aux livres et cartes.
    21  documentations de voyage

Et 13 est pris aussi — itinéraires par bloc, seize documents — sans figurer à
la liste, le 13 islandais n'ayant pas d'équivalent.

DEUX AUTRES ÉNONCÉS DE LA MÊME QUESTION ONT VIEILLI

    « L'alignement est tenu partout ailleurs : 08 vidéos, 10 faune, 20
      devises, 90 pratique. » Le module 90 a été retiré le 21/09, repris sans
      réécriture dans le guide du 07.

    « un tableau de bord qui compte déjà vingt-neuf tuiles ». Il en compte
      trente-cinq. Celui-ci est daté du 14/09 et reste juste comme tel : il
      est laissé, le constat portant la date de son arbitrage.

CE QUI EST FAIT. Le champ « a_creuser » est refait sur l'état réel, avec la
date à laquelle chaque numéro a été pris — pour qu'on voie non seulement ce
qui est libre, mais à quelle vitesse ça se referme. Le champ « reponse »
reçoit une note datée du 10/10. Le manifeste passe en 1.49.

LE FORMAT EST PRÉSERVÉ. Le script vérifie d'abord qu'un aller-retour JSON sans
modification rend le fichier à l'identique. Si ce n'est pas le cas, il
s'arrête : écrire reformaterait 114 Ko et noierait la correction dans le diff.
C'est le garde-fou des autres correctifs du manifeste, repris ici.

PRUDENCE. Lecture seule par défaut.

UTILISATION — depuis la racine du dépôt DE DONNÉES
    python3 outils/corriger-numerotation-manifeste.py            # contrôle
    python3 outils/corriger-numerotation-manifeste.py --ecrire   # applique

APRÈS COUP, obligatoire — le suivi est engendré depuis le manifeste :
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

VERSION_ATTENDUE = '1.48'
VERSION_NOUVELLE = '1.49'
HORODATAGE_ISO = '2026-10-10T14:55:00+02:00'

A_CREUSER_NOUVEAU = (
    "ÉTAT AU 10/10/2026 — trois des numéros déclarés libres le 14/09 ont été "
    "pris depuis : 11 (fichiers GPS), 12 (livres et cartes, 26/09), 21 "
    "(documentations de voyage). Le 13 l'est aussi (itinéraires par bloc, "
    "seize documents), sans avoir figuré à la liste faute d'équivalent "
    "islandais. RESTENT LIBRES CÔTÉ NORDIQUE : 14, 16, 17, 18, 19, 22, 89. "
    "Le 22 est libre comme NUMÉRO DE MODULE, mais son sujet est couvert — "
    "Google Earth est posé en tuile de lien sortant depuis le 16/09, sans "
    "dossier. Si un jour le 07 ou le 09 devait être éclaté, reprendre la "
    "numérotation islandaise plutôt que d'en inventer une — la règle du 14/09 "
    "tient, c'est seulement la liste qui se referme."
)

NOTE_REPONSE = (
    " — NOTE DU 10/10/2026 : le module 90 cité ici a été retiré le 21/09, "
    "repris sans réécriture dans le guide pratique du 07 ; l'alignement se lit "
    "donc désormais sur 08 vidéos, 10 faune, 20 devises. Le décompte de "
    "vingt-neuf tuiles est celui du 14/09 et reste juste à cette date ; il y "
    "en a trente-cinq au 10/10. Le 12 que cet arbitrage réservait au drone est "
    "allé aux livres et cartes : arbitré le 10/10, on abandonne le drone."
)


def main():
    print('Dépôt : %s' % RACINE)
    print('Mode  : %s\n' % ('ÉCRITURE' if ECRIRE else 'contrôle seul'))

    if not os.path.exists(MANIFESTE):
        print('ARRÊT — manifest-donnees.json introuvable.')
        print('  Ce script se lance depuis la racine du dépôt DE DONNÉES.')
        return 1

    texte = io.open(MANIFESTE, encoding='utf-8').read()
    m = json.loads(texte)

    def dump(obj):
        return json.dumps(obj, ensure_ascii=False, indent=2) + '\n'

    # garde-fou de format : un aller-retour sans modification doit rendre
    # le fichier à l'identique, sans quoi l'écriture reformaterait 114 Ko
    if dump(m) != texte:
        print("ARRÊT — rien n'a été écrit.")
        print('  un aller-retour JSON ne rend pas le fichier à l\'identique :')
        print('  écrire le reformaterait en entier et noierait la correction.')
        return 1
    print('  format : aller-retour JSON stable')

    v = m.get('manifest', {}).get('version')
    if v != VERSION_ATTENDUE:
        print("ARRÊT — rien n'a été écrit.")
        print('  manifeste en %s, %s attendu' % (v, VERSION_ATTENDUE))
        return 1
    print('  version : %s' % v)

    questions = m.get('questions_ouvertes') or []
    cibles = [q for q in questions
              if isinstance(q, dict) and q.get('id') == 'numerotation-modules']
    if len(cibles) != 1:
        print("ARRÊT — rien n'a été écrit.")
        print('  question « numerotation-modules » : %d trouvée(s), une attendue'
              % len(cibles))
        return 1
    q = cibles[0]

    if '10/10/2026' in str(q.get('a_creuser', '')):
        print('\nRien à faire : la question porte déjà l\'état du 10/10.')
        return 0

    ancien = q.get('a_creuser', '')
    if '11, 12, 14' not in ancien:
        print("ARRÊT — rien n'a été écrit.")
        print('  le champ « a_creuser » ne porte pas la liste attendue :')
        print('  %s' % ancien[:160])
        return 1

    print('\n=== ce qui change ===')
    print('  a_creuser — liste des numéros libres, refaite sur l\'état réel')
    print('      avant : …%s' % ancien[ancien.find('libres'):][:90])
    print('      après : %s…' % A_CREUSER_NOUVEAU[:90])
    print('  reponse   — note datée du 10/10 (module 90 retiré, décomptes)')
    print('  version   — %s -> %s' % (VERSION_ATTENDUE, VERSION_NOUVELLE))

    if not ECRIRE:
        print('\nContrôle seul : aucun fichier touché.')
        print('Relancer avec --ecrire pour appliquer.')
        return 0

    q['a_creuser'] = A_CREUSER_NOUVEAU
    q['reponse'] = (q.get('reponse') or '') + NOTE_REPONSE
    m['manifest']['version'] = VERSION_NOUVELLE
    m['manifest']['genere_le'] = HORODATAGE_ISO

    io.open(MANIFESTE, 'w', encoding='utf-8').write(dump(m))
    print('\nécrit : manifest-donnees.json')
    print('\nMaintenant, sans quoi le suivi reste en arrière :')
    print('    python3 outils/gen-suivi.py')
    return 0


if __name__ == '__main__':
    sys.exit(main())
