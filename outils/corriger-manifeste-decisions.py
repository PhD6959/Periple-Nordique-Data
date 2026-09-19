#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
CORRECTIF PONCTUEL — TROIS DÉCISIONS MANQUANTES AU MANIFESTE
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 19 septembre 2026 à 12:58 (heure de Paris)
=============================================================================

POURQUOI
  Les conventions du manifeste (conventions_de_travail, cas « Décision,
  arbitrage, ou renoncement ») veulent que toute décision soit inscrite ici,
  comme question tranchée. Trois décisions prises depuis le 14/09 n'étaient
  écrites que dans le README applicatif et le document de reprise :

    1. bibliotheques-distantes      (14/09) origine unique cdnjs, versions
                                    figées, LIB_FILES ; vendor/ écarté.
    2. disposition-tableau-de-bord  (14/09, complétée le 19/09) quatorze
                                    groupes dans l'ordre islandais, six
                                    colonnes, trois écarts ; puis priorité de
                                    l'Admin Menu sur regrouper-tuiles.py.
    3. reprise-recherche-hors-depot (16/09) reprise-periple-nordique.md
                                    reste dans le seul Contexte du projet.

  Le document de suivi, engendré du manifeste, ne pouvait donc pas les
  montrer.

CE QU'IL FAIT
  - ajoute ces trois questions, toutes avec leur réponse ;
  - ajoute l'Admin Menu à carte_de_la_documentation ;
  - passe le manifeste de 1.40 à 1.41, genere_le au 19/09/2026 12:58.
  Rien d'autre n'est touché : le fichier est relu et réécrit au format exact
  d'origine (indentation 2, UTF-8, saut de ligne final), vérifié octet pour
  octet sur la v1.40.

FORME — contrôle seul par défaut. Arrêt avant toute écriture si le manifeste
n'est pas en 1.40, si l'un des trois identifiants existe déjà, ou si la clé de
la carte existe déjà.

UTILISATION — depuis n'importe où
    python3 outils/corriger-manifeste-decisions.py            # contrôle seul
    python3 outils/corriger-manifeste-decisions.py --ecrire   # applique
    python3 outils/gen-suivi.py                               # puis régénérer
=============================================================================
"""

import io
import json
import os
import sys

ECRIRE = '--ecrire' in sys.argv
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFESTE = os.path.join(RACINE, 'manifest-donnees.json')

AVANT, APRES = '1.40', '1.41'
GENERE_LE = '2026-09-19T12:58:00+02:00'

QUESTIONS = [
 {
  "id": "bibliotheques-distantes",
  "titre": "Bibliothèques distantes — une seule origine, versions figées, mise au cache",
  "priorite": "basse",
  "pour": "claude",
  "statut": "arbitrée le 14/09/2026",
  "constat": "Les modules chargent React, ReactDOM, Babel, Tailwind, Chart.js, SheetJS et Leaflet depuis des CDN, et aucune de ces ressources n'était dans le cache du service worker : sans réseau, ces pages s'ouvraient vides. Les origines divergeaient : quatre modules — 03, 06, 08, 10 — tiraient d'unpkg, les autres de cdnjs, et trois adresses unpkg ne portaient aucun numéro de version précis, le serveur choisissait.",
  "reponse": "ARBITRÉ : tout est ramené sur cdnjs, aux versions figées déjà en usage — React 18.2.0, ReactDOM 18.2.0, Babel 7.23.5, Chart.js 4.4.0, SheetJS 0.18.5, Leaflet 1.9.4 — et le service worker porte une troisième liste, LIB_FILES, qui les met au cache à l'installation. Le versement local sous vendor/ a été examiné puis écarté : Starlink fonctionne en continu pendant les voyages, et l'environnement islandais a servi tout un voyage dans cette configuration.",
  "a_creuser": "Reste à éprouver : iPad en mode avion, chaque tuile ouverte une fois — aucun contrôle par lecture n'établit qu'une page s'ouvre sans réseau. La police Inter du module 06 vient de Google Fonts et n'est pas au cache : sans réseau, le texte s'affiche dans une autre police, cosmétique et voulu.",
  "consequence": "LIB_FILES est la seule liste du service worker tenue à la main : toute bibliothèque ajoutée à un module doit y être inscrite, sans quoi la page s'ouvre vide hors ligne. Aucun outil ne le fait."
 },
 {
  "id": "disposition-tableau-de-bord",
  "titre": "Disposition du tableau de bord — ordre islandais, puis priorité de l'Admin Menu",
  "priorite": "basse",
  "pour": "les-deux",
  "statut": "arbitrée le 14/09/2026, complétée le 19/09/2026",
  "constat": "Le tableau de bord nordique comptait sept groupes, dont un fourre-tout de treize tuiles nommé « liens » où cohabitaient documents, suivi de trajet, tourisme et devises. Trois versions de outils/regrouper-tuiles.py ont fixé les rangées à la main et ont échoué sur des mesures fausses. Le 19/09, un éditeur visuel du menu, admin-menu-nsf.html, a été dérivé de l'outil islandais : ses dispositions et celles de regrouper-tuiles.py pouvaient s'écraser mutuellement.",
  "reponse": "ARBITRÉ LE 14/09 : quatorze groupes, dans l'ordre du tableau de bord islandais, tenu comme une donnée (table ORDRE de regrouper-tuiles.py) ; rangées calculées jusqu'à six colonnes, un groupe compact occupant une colonne par tranche de deux tuiles. Trois écarts assumés avec l'islandais : actualité routière et alertes réunies ; « urgences et démarches » et « SOS véhicule » fondus ; groupes islandais sans équivalent nordique marqués à leur rang en commentaire. COMPLÉTÉ LE 19/09, décision de Philippe : la disposition faite dans l'Admin Menu a PRIORITÉ. L'export pose à la racine de config-menu.json la marque dispositionManuelle {date, outil} dès que la disposition est touchée ; regrouper-tuiles.py v1.4 n'écrit alors plus rien, même avec --ecrire. Éprouvé en ligne le 19/09 : marque posée à 12:40, tableau de bord affiché normalement, regrouper-tuiles.py sans écriture.",
  "a_creuser": "Revenir à la disposition calculée se demande explicitement : regrouper-tuiles.py --reprendre --ecrire, qui écrit, retire la marque et réécrit aussi les noms de groupes depuis sa table LIBELLES.",
  "consequence": "Depuis le 19/09, la table ORDRE de regrouper-tuiles.py ne décrit plus la disposition en place. Sans effet tant qu'on n'utilise pas --reprendre ; après un ajouter-tuile.py, --reprendre s'arrêtera sur « modules déclarés mais non placés » jusqu'à ce que la tuile soit inscrite dans ORDRE."
 },
 {
  "id": "reprise-recherche-hors-depot",
  "titre": "Document de reprise du chat de recherche — laissé hors dépôt",
  "priorite": "basse",
  "pour": "les-deux",
  "statut": "arbitrée le 16/09/2026",
  "constat": "Deux chats travaillent sur le périple : l'un sur la structure de l'application, qui écrit dans les dépôts, l'autre sur la recherche de contenu. Le document de reprise du second, reprise-periple-nordique.md, ne vit que dans le Contexte du projet : ni sauvegardé, ni versionné, ni poussé. Lui et docs/consigne-chat-recherche.md annoncent neuf ou dix modules et vingt-huit tuiles, l'état du 11 septembre.",
  "reponse": "ARBITRÉ : on le laisse dans le Contexte du projet, le chat de recherche le porte aussi.",
  "a_creuser": "À reverser dans docs/ du dépôt applicatif si ce n'était plus le cas. Les deux documents du chat de recherche raisonnent sur un état périmé : sans conséquence sur le code, mais à rafraîchir à la prochaine session de recherche.",
  "consequence": "Une perte du Contexte du projet emporterait ce document : il n'a pas de copie dans les dépôts."
 },
]

CARTE_CLE = 'Periple-Nordique/admin-menu-nsf.html'
CARTE_VAL = ("Éditeur visuel de config-menu.json, à la racine du dépôt applicatif, avec son "
             "mode d'emploi doc-admin-menu-nsf.html. A priorité sur outils/regrouper-tuiles.py "
             "par la marque dispositionManuelle — voir la question disposition-tableau-de-bord.")


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

    try:
        def dump(obj):
            return json.dumps(obj, ensure_ascii=False, indent=2) + '\n'
        if dump(m) != texte:
            raise Arret("le format du fichier n'est pas celui attendu (indentation 2, "
                        "saut de ligne final) : une réécriture changerait des lignes "
                        "hors du correctif")
        v = m.get('manifest', {}).get('version')
        print('  version du manifeste         %s (attendue %s)' % (v, AVANT))
        if v != AVANT:
            raise Arret('manifeste en %s, pas en %s' % (v, AVANT))
        qo = m.get('questions_ouvertes')
        if not isinstance(qo, list):
            raise Arret('questions_ouvertes absente ou mal formée')
        existants = {q.get('id') for q in qo}
        for q in QUESTIONS:
            present = q['id'] in existants
            print('  question %-28s %s' % (q['id'], 'DÉJÀ PRÉSENTE' if present else 'à ajouter'))
            if present:
                raise Arret('la question %s existe déjà' % q['id'])
        carte = m.get('conventions_de_travail', {}).get('carte_de_la_documentation')
        if not isinstance(carte, dict):
            raise Arret('carte_de_la_documentation absente ou mal formée')
        print('  carte : %-33s %s' % ('admin-menu-nsf.html',
                                     'DÉJÀ PRÉSENTE' if CARTE_CLE in carte else 'à ajouter'))
        if CARTE_CLE in carte:
            raise Arret('la carte nomme déjà %s' % CARTE_CLE)
    except Arret as e:
        print("\nARRÊT — rien n'a été écrit.\n  %s" % e)
        return 1

    qo.extend(QUESTIONS)
    carte[CARTE_CLE] = CARTE_VAL
    m['manifest']['version'] = APRES
    m['manifest']['genere_le'] = GENERE_LE
    ouvertes = sum(1 for q in qo if not q.get('reponse'))
    print('\n  questions : %d au total, dont %d sans réponse' % (len(qo), ouvertes))
    print('  version   : %s -> %s' % (AVANT, APRES))

    if not ECRIRE:
        print("\nContrôle seul : rien n'est touché. Relancer avec --ecrire.")
        return 0
    io.open(MANIFESTE, 'w', encoding='utf-8').write(
        json.dumps(m, ensure_ascii=False, indent=2) + '\n')
    print('\nécrit : manifest-donnees.json')
    print('Ensuite : python3 outils/gen-suivi.py')
    return 0


if __name__ == '__main__':
    sys.exit(main())
