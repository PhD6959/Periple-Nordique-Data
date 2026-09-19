#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
CORRECTIF PONCTUEL — LA FICHE POI ET PHOTO NORVÈGE ENTRE À LA CARTE
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 19 septembre 2026 à 16:34 (heure de Paris)
=============================================================================

POURQUOI
  fiches-poi-photo-norvege.md, produite par le chat de recherche le 16/09 et
  complétée depuis, est la source du classeur du module 06 (rubrique Photo)
  et de la question ressources-photo-norvege. Elle seule porte le détail de
  vérification de chaque ressource, les motifs des rejets, les chiffres de
  Hornøya et le calendrier ornithologique. Versionnée le 19/09 dans docs/,
  elle doit figurer à carte_de_la_documentation pour être trouvée.

CE QU'IL FAIT
  - ajoute Periple-Nordique-Data/docs/fiches-poi-photo-norvege.md à la carte,
    après le document de suivi ;
  - passe le manifeste de 1.44 à 1.45, genere_le au 19/09/2026 16:34.
  Réécriture au format exact d'origine, contrôlé avant toute écriture.

FORME — contrôle seul par défaut ; arrêt si le manifeste n'est pas en 1.44,
si la fiche n'est pas dans docs/, ou si la carte la nomme déjà.

UTILISATION — depuis n'importe où
    python3 outils/corriger-manifeste-carte-fiche.py
    python3 outils/corriger-manifeste-carte-fiche.py --ecrire
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
FICHE = os.path.join(RACINE, 'docs', 'fiches-poi-photo-norvege.md')

AVANT, APRES = '1.44', '1.45'
GENERE_LE = '2026-09-19T16:34:00+02:00'
APRES_CLE = 'Periple-Nordique-Data/docs/doc-module-03-nsf-suivi.html'
CLE = 'Periple-Nordique-Data/docs/fiches-poi-photo-norvege.md'
VAL = ("Fiche du chat de recherche, volet Norvège : ressources photo et points d'intérêt "
       "vérifiées, écartés et leurs motifs, ressources à ouvrir, reste à faire. Source du "
       "classeur du module 06, rubrique Photo, et de la question ressources-photo-norvege. "
       "Seule à porter le détail de vérification de chaque ressource.")


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
        print('  version du manifeste      %s (attendue %s)' % (v, AVANT))
        if v != AVANT:
            raise Arret('manifeste en %s, pas en %s' % (v, AVANT))
        print('  fiche dans docs/          %s' % ('oui' if os.path.exists(FICHE) else 'NON'))
        if not os.path.exists(FICHE):
            raise Arret('docs/fiches-poi-photo-norvege.md absente : la déposer d\'abord')
        carte = m.get('conventions_de_travail', {}).get('carte_de_la_documentation')
        if not isinstance(carte, dict) or APRES_CLE not in carte:
            raise Arret('carte_de_la_documentation absente, ou sans le document de suivi')
        print('  entrée de la carte        %s' % ('DÉJÀ PRÉSENTE' if CLE in carte else 'à ajouter'))
        if CLE in carte:
            raise Arret('la carte nomme déjà la fiche')
    except Arret as e:
        print("\nARRÊT — rien n'a été écrit.\n  %s" % e)
        return 1

    nouvelle = {}
    for k, val in carte.items():
        nouvelle[k] = val
        if k == APRES_CLE:
            nouvelle[CLE] = VAL
    m['conventions_de_travail']['carte_de_la_documentation'] = nouvelle
    m['manifest']['version'] = APRES
    m['manifest']['genere_le'] = GENERE_LE
    print('\n  version   : %s -> %s' % (AVANT, APRES))
    if not ECRIRE:
        print("\nContrôle seul : rien n'est touché. Relancer avec --ecrire.")
        return 0
    io.open(MANIFESTE, 'w', encoding='utf-8').write(dump(m))
    print('\nécrit : manifest-donnees.json')
    print('Ensuite : python3 outils/gen-suivi.py')
    return 0


if __name__ == '__main__':
    sys.exit(main())
