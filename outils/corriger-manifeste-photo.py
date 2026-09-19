#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
CORRECTIF PONCTUEL — RESSOURCES PHOTO ET POINTS D'INTÉRÊT, VOLET NORVÈGE
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 19 septembre 2026 à 15:06 (heure de Paris)
=============================================================================

POURQUOI
  La fiche du chat de recherche (fiches-poi-photo-norvege.md, passe du 16/09,
  complétée depuis) n'avait laissé de trace durable que dans le menu : ses
  écartés, ses ressources jamais ouvertes, son reste à faire et ses réserves
  n'étaient écrits que dans un message de commit et des commentaires de
  script. Le 19/09, ses ressources sont passées au module 06.

CE QU'IL FAIT
  - ajoute la question « ressources-photo-norvege », SANS réponse : le volet
    norvégien reste ouvert, la Suède et la Finlande ne sont pas commencées ;
  - passe le manifeste de 1.42 à 1.43, genere_le au 19/09/2026 15:06.
  Réécriture au format exact d'origine, contrôlé avant toute écriture.

FORME — contrôle seul par défaut ; arrêt avant toute écriture si le manifeste
n'est pas en 1.42 ou si la question existe déjà.

UTILISATION — depuis n'importe où
    python3 outils/corriger-manifeste-photo.py
    python3 outils/corriger-manifeste-photo.py --ecrire
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

AVANT, APRES = '1.42', '1.43'
GENERE_LE = '2026-09-19T15:06:00+02:00'

QUESTION = {
 "id": "ressources-photo-norvege",
 "titre": "Ressources photo et points d'intérêt — Norvège en cours, Suède et Finlande à faire",
 "priorite": "basse",
 "pour": "les-deux",
 "statut": "",
 "constat": "Passe du chat de recherche du 16/09 sur les lignes « Points d'intérêt » et « Ressources photo » de l'inventaire, volet Norvège seul, consignée dans fiches-poi-photo-norvege.md. SEPT RESSOURCES VÉRIFIÉES par lecture le 16/09 : routes touristiques nationales (nasjonaleturistveger.no, six des dix-huit routes sur le tracé), guides Max Rive Norvège et Senja, carte Rexby de Vanita Safaniuk aux Lofoten, The Wandering Lens aux Lofoten, parc national du Varanger, itinéraire Photo Tours Norway au Varanger. ÉCARTÉS : explorewithjohan.com (domaine en pendingDelete, confirmé en source primaire le 16/09) ; stianklo.com (portail bloquant, contenu de 2017) ; Rexby JurisAdventure, Rachel Pohl et Charles Post, Ása Steinars (critère de résidence) ; ScandiHikes (catalogue non chargé, primo-visiteurs). CONSTATS : le critère « chaîne YouTube plus site » n'a pas d'équivalent nordique, les créateurs sont sur Instagram ; trois sites personnels sur trois étaient défaillants ; le Varanger est un territoire d'ornithologie, pas de photo de paysage ; pour la Suède, aucun guide de spots comparable aux cartes Rexby n'a été trouvé.",
 "reponse": "",
 "a_creuser": "NORVÈGE, À OUVRIR : visitnorway.com, page ornithologique du Varanger (adresse exacte à retrouver) ; 68north.com (Cody Duncan, Lofoten, plus Kungsleden et Padjelantaleden côté suédois) ; l'article de lifeinnorway.net sur le Varanger (adresse à retrouver). NORVÈGE, À FAIRE : tester lofotentours.com ; explorer les sections faune et points d'accès de varangerhalvoya.no ; vérifier en source primaire norvégienne la réglementation drone énoncée par Max Rive ; Nordkapp et la Kystriksveien restent sans ressource éditoriale propre ; trancher le calendrier ornithologique — lek des combattants et nidification fin mai à début juin selon Photo Tours Norway, passage prévu début juillet ; divergence sur l'effectif de Hornøya, 80 000 couples chez Photo Tours Norway, jusqu'à 100 000 ailleurs. SUÈDE ET FINLANDE : non commencées.",
 "consequence": "DÉCISION DU 19/09 : les ressources vont au module 06, rubrique Photo, v2.1.0 — le 06 est la bibliothèque complète, une tuile du menu ne double une entrée que si l'usage en route le justifie. Les trois tuiles du groupe Photo ont été retirées du menu ; la tuile du parc du Varanger reste auprès de la faune, pour le calage du 4 juillet. Les RÉSERVES sont écrites à la fin du descriptif, dans les six langues : Max Rive, deux régions sur cinq sur le tracé ; Vanita Safaniuk, payant ; The Wandering Lens, guide de 2017-2018 ; Photo Tours Norway, séjour payant lu comme repérage. Check_PhD à Non pour les sept : lues par le chat de recherche, pas encore par Philippe. Les trois ressources non ouvertes ne sont pas au classeur."
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
