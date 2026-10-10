#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
ADRESSES EN LIGNE — VOLET DÉPÔT DE DONNÉES
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 10 octobre 2026 à 11:30 (heure de Paris)
=============================================================================

POURQUOI. Jumeau de adresses-cloudflare-app.py, pour la seule mention
d'hébergement que porte ce dépôt. GitHub Pages a été désactivé le 10/10/2026 ;
l'application est servie par Cloudflare Pages derrière Cloudflare Access.

UNE SEULE LIGNE, DANS LE GÉNÉRATEUR. La phrase vit dans outils/gen-suivi.py,
qui engendre docs/doc-module-03-nsf-suivi.html. On corrige le générateur, puis
on régénère. Corriger le HTML directement le ferait diverger de sa source au
premier rejeu.

CE QUI N'EST PAS TOUCHÉ

  manifest-donnees.json, entrées « module-3-app » et « service-worker » : leur
  champ « a_creuser » parle d'activer GitHub Pages, mais toutes deux portent
  « statut : traitée le 10/09/2026 ». Ce sont des questions closes, un relevé
  de ce qui se demandait alors. Les réécrire falsifierait le manifeste.

  docs/legacy/doc-module-03-nsf-suivi.html : copie d'archive, par définition
  datée.

PRUDENCE. Lecture seule par défaut. Assertion d'unicité sur l'ancre.

UTILISATION — depuis la racine du dépôt de données
    python3 outils/adresses-cloudflare-data.py            # contrôle seul
    python3 outils/adresses-cloudflare-data.py --ecrire   # applique

APRÈS COUP, obligatoire — sinon le document reste en arrière :
    python3 outils/gen-suivi.py
=============================================================================
"""

import io
import os
import sys

ECRIRE = '--ecrire' in sys.argv
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

AVANT = ('<code>Periple-Nordique</code>, privé mais servi publiquement par '
         'GitHub Pages. La séparation tient à')

APRES = ('<code>Periple-Nordique</code>, privé et servi par Cloudflare Pages '
         'derrière Cloudflare Access. La séparation tient à')


def main():
    print('Dépôt : %s' % RACINE)
    print('Mode  : %s\n' % ('ÉCRITURE' if ECRIRE else 'contrôle seul'))

    chemin = os.path.join(RACINE, 'outils', 'gen-suivi.py')
    if not os.path.exists(chemin):
        print('ARRÊT — introuvable : outils/gen-suivi.py')
        return 1

    s = io.open(chemin, encoding='utf-8').read()

    if 'Cloudflare Pages' in s:
        print('Rien à faire : la mention est déjà à jour.')
        return 0

    n = s.count(AVANT)
    if n != 1:
        print("ARRÊT — rien n'a été écrit.")
        print('  gen-suivi.py — mention d\'hébergement : %d occurrence(s), '
              'il en faut une' % n)
        return 1

    s = s.replace(AVANT, APRES)

    print('=== opération reconnue ===')
    print("  gen-suivi.py — mention d'hébergement")
    print('\n=== laissé intact, volontairement ===')
    print('  manifest-donnees.json — deux « a_creuser » de questions closes')
    print('  docs/legacy/ — copie d\'archive')

    if not ECRIRE:
        print('\nContrôle seul : aucun fichier touché.')
        print('Relancer avec --ecrire pour appliquer.')
        return 0

    io.open(chemin, 'w', encoding='utf-8').write(s)
    print('\nécrit : outils/gen-suivi.py')
    print('\nMaintenant, sans quoi le document reste en arrière :')
    print('    python3 outils/gen-suivi.py')
    return 0


if __name__ == '__main__':
    sys.exit(main())
