#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
CORRECTIF PONCTUEL — VIDANGE DES EAUX NOIRES : PAS DE COLONNE, ET POURQUOI
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 19 septembre 2026 à 20:23 (heure de Paris)
=============================================================================

POURQUOI
  Question de Philippe, 19/09 : la couche « Aires et vidange » peut-elle
  distinguer les points où l'on peut vider les eaux noires (cassette de WC) ?
  Étudiée, puis écartée par décision de Philippe. Les conventions du manifeste
  veulent qu'un renoncement soit inscrit, pour ne pas refaire la recherche.

CE QU'IL FAIT
  - ajoute la question tranchée « vidange-eaux-noires » ;
  - passe le manifeste de 1.45 à 1.46, genere_le au 19/09/2026 20:23.
  Réécriture au format exact d'origine, contrôlé avant toute écriture.

FORME — contrôle seul par défaut ; arrêt avant toute écriture si le manifeste
n'est pas en 1.45 ou si la question existe déjà.

UTILISATION — depuis n'importe où
    python3 outils/corriger-manifeste-eaux-noires.py
    python3 outils/corriger-manifeste-eaux-noires.py --ecrire
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

AVANT, APRES = '1.45', '1.46'
GENERE_LE = '2026-09-19T20:23:00+02:00'

QUESTION = {
 "id": "vidange-eaux-noires",
 "titre": "Vidange des eaux noires — pas de colonne dans la couche des aires",
 "priorite": "basse",
 "pour": "les-deux",
 "statut": "arbitrée le 19/09/2026",
 "constat": "La couche aires-camping-car.geojson ne garde qu'un booléen « vidange », sans dire ce qu'on peut y vider. OpenStreetMap porte deux sous-étiquettes pour cela : sanitary_dump_station:chemical_toilet (cassette de WC, eaux noires) et sanitary_dump_station:grey_water (eaux grises), plus une forme sanitary_dump_station:accepted. Le wiki OSM définit amenity=sanitary_dump_station comme réservé aux réservoirs d'eaux de toilettes, mais sa page de discussion relève que le sens des sous-étiquettes n'a jamais été clairement défini. Comptage du 19/09 sur les extraits OSM du 10/09 : Norvège 487 points de vidange, dont 24 eaux noires déclarées et 4 refusées ; Suède 550, dont 33 et 4 ; Finlande 230, dont 11 et 0 — environ 5 % de couverture, totaux maximaux, un point pouvant porter deux étiquettes. La sous-étiquette basin, sans définition officielle, figure sur 66 points ; ses valeurs n'ont pas été relevées.",
 "reponse": "ARBITRÉ PAR PHILIPPE : pas de colonne « eaux noires ». MOTIF PRINCIPAL, constat de terrain en Islande : les indications de vidange sont parfois fausses sur place, au point que même les eaux grises n'y peuvent pas être vidées ; une indication « eaux noires », plus exigeante, serait moins fiable encore et donnerait une fausse assurance. Motif secondaire : environ 5 % de couverture dans les trois pays.",
 "a_creuser": "La même réserve vaut pour la colonne « vidange » existante : elle signale un point, elle ne garantit pas qu'il accepte ce qu'on veut y vider. Piste non explorée : les valeurs de sanitary_dump_station:basin.",
 "consequence": "Sur place, seuls le panneau et l'exploitant font foi. À reconsidérer seulement si la recollecte de mars 2027 montrait des données à la fois plus nombreuses et vérifiées sur le terrain."
}


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
    except Arret as e:
        print("\nARRÊT — rien n'a été écrit.\n  %s" % e)
        return 1

    qo.append(QUESTION)
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
