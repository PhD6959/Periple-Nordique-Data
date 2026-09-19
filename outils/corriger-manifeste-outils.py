#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
CORRECTIF PONCTUEL — EMPLACEMENT DES OUTILS DE PRÉPARATION
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 19 septembre 2026 à 13:11 (heure de Paris)
=============================================================================

POURQUOI
  Décision de Philippe, 19/09/2026 : un script de préparation vit dans
  outils/ de son dépôt, versionné, jamais dans un dossier de module. Motif :
  enrichir-livres-isbn.py, rangé dans 12-livres-cartes/, faisait mentir le
  contrôle croisé de generer-listes.sh, et son bandeau le disait « hors dépôt »
  alors qu'il était commité.

CE QU'IL FAIT
  - ajoute la question tranchée « emplacement-outils-preparation » ;
  - ajoute la règle à conventions_de_travail, clé « emplacement_des_outils »,
    placée avant « sauvegarde » ;
  - passe le manifeste de 1.41 à 1.42, genere_le au 19/09/2026 13:11.
  Réécriture au format exact d'origine, contrôlé avant toute écriture.

FORME — contrôle seul par défaut ; arrêt avant toute écriture si le manifeste
n'est pas en 1.41, ou si la question ou la clé existent déjà.

UTILISATION — depuis n'importe où
    python3 outils/corriger-manifeste-outils.py            # contrôle seul
    python3 outils/corriger-manifeste-outils.py --ecrire   # applique
    python3 outils/gen-suivi.py                            # puis régénérer
=============================================================================
"""

import io
import json
import os
import sys

ECRIRE = '--ecrire' in sys.argv
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFESTE = os.path.join(RACINE, 'manifest-donnees.json')

AVANT, APRES = '1.41', '1.42'
GENERE_LE = '2026-09-19T13:11:00+02:00'

QUESTION = {
 "id": "emplacement-outils-preparation",
 "titre": "Emplacement des outils de préparation — outils/, jamais un dossier de module",
 "priorite": "basse",
 "pour": "les-deux",
 "statut": "arbitrée le 19/09/2026",
 "constat": "enrichir-livres-isbn.py, qui remplit le classeur du module 12 depuis l'ISBN, vivait dans 12-livres-cartes/. Le contrôle croisé de generer-listes.sh le signalait « présent mais cité nulle part », alors que la règle veut ce compteur à zéro, l'extracteur YouTube excepté. Son bandeau le disait « HORS DÉPÔT » alors qu'il était commité. Un correctif du 16/09 (tuile-google-earth.py) jugeait ce signalement « le comportement juste », en passant, à propos d'un fichier KML abandonné depuis ; ce jugement n'avait été inscrit nulle part.",
 "reponse": "ARBITRÉ : un script de préparation vit dans outils/ de son dépôt, versionné, jamais dans un dossier de module. enrichir-livres-isbn.py y a été déplacé par git mv et passe en 1.0.1 : mode d'emploi depuis la racine, « HORS DÉPÔT » corrigé en « HORS APPLICATION ». Il ne porte aucune clé. Seule exception maintenue : l'extracteur YouTube du module 08, hors dépôt parce qu'il porte une clé d'API en clair.",
 "a_creuser": "Élargir le motif EST_OUTIL de generer-listes.sh aux .py a été écarté : ce motif classe aussi les fichiers comme « hors dépôt », ce qui aurait été faux pour un script versionné.",
 "consequence": "Le contrôle croisé de generer-listes.sh redevient un signal : tout fichier non cité dans un dossier de module est une anomalie, pas un outil toléré."
}

CLE = 'emplacement_des_outils'
REGLE = ("Un script de préparation — collecte, conversion, enrichissement d'un classeur — vit "
         "dans outils/ de son dépôt, versionné, jamais dans un dossier de module : ceux-ci ne "
         "contiennent que ce que l'application sert. Seule exception, hors dépôt : un outil "
         "portant une clé en clair, comme l'extracteur YouTube du module 08, exclu par .gitignore. "
         "Décidé le 19/09/2026 — voir la question emplacement-outils-preparation.")


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
            raise Arret("format du fichier inattendu : une réécriture changerait des "
                        "lignes hors du correctif")
        v = m.get('manifest', {}).get('version')
        print('  version du manifeste             %s (attendue %s)' % (v, AVANT))
        if v != AVANT:
            raise Arret('manifeste en %s, pas en %s' % (v, AVANT))
        qo = m.get('questions_ouvertes')
        if not isinstance(qo, list):
            raise Arret('questions_ouvertes absente ou mal formée')
        present = any(q.get('id') == QUESTION['id'] for q in qo)
        print('  question %-32s %s' % (QUESTION['id'][:32], 'DÉJÀ PRÉSENTE' if present else 'à ajouter'))
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
