#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
ENGENDRE LE REGISTRE DES SOURCES ET DES LICENCES
Périple nordique 2027 — dépôt Periple-Nordique-Data
Version 1.0 — 10 octobre 2026 à 15:15 (heure de Paris)
=============================================================================

docs/doc-sources-licences.html est ENGENDRÉ, jamais édité à la main. Toute
correction se porte dans manifest-donnees.json, champs « source » et
« licence » de chaque rubrique, puis on relance ce script. Le registre ne peut
donc pas diverger de la source de vérité — même principe que gen-suivi.py,
dont il est le frère et dont il reprend la charte.

POURQUOI CE DOCUMENT. Les vingt couches viennent de sources publiques
officielles, et trois des quatre familles de licences en jeu EXIGENT UNE
ATTRIBUTION : ODbL, CC BY 4.0 et NLOD. Les données elles-mêmes portent
l'information, rubrique par rubrique, mais nulle part on ne pouvait lire d'un
coup d'œil ce qu'il faut créditer, ni vérifier que l'application le fait.

CE QUE LE REGISTRE A RÉVÉLÉ EN ÉTANT ÉCRIT. L'attribution affichée dans
l'onglet Doc du module 03 dit, en six langues : « La couche des services est
dérivée d'OpenStreetMap, ODbL ; les autres relèvent de la NLOD norvégienne ou
de la CC BY 4.0 finlandaise. » Le manifeste en dit autrement :

    ODbL       SIX rubriques, pas une — services, aires-camping-car, pois,
               et les volets suédois et finlandais de cols-fermetures,
               ferries et tunnels
    NLOD       sept rubriques
    CC BY 4.0  quatre rubriques
    CC0        trois rubriques, les données suédoises — non mentionnées du tout

CC0 n'impose rien, son omission est sans conséquence. Les cinq rubriques ODbL
non citées, en revanche, sont une attribution incomplète. Le registre affiche
l'écart et propose le texte à afficher ; la correction du module reste à
décider — elle touche six langues et impose une révision.

UTILISATION — depuis n'importe où
    python3 outils/gen-licences.py

APRÈS COUP : commiter le document engendré avec le manifeste qui l'a produit.
=============================================================================
"""

import io
import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(RACINE, 'manifest-donnees.json')
CIBLE = os.path.join(RACINE, 'docs', 'doc-sources-licences.html')

MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
        'août', 'septembre', 'octobre', 'novembre', 'décembre']

# Ce que chaque famille de licence impose. CE BLOC EST DE LA CONNAISSANCE,
# pas une lecture du manifeste : il est écrit ici, en clair, pour qu'on sache
# d'où il vient et qu'on puisse le contester. Les adresses sont celles des
# textes de référence.
OBLIGATIONS = [
    ('ODbL', 'Open Database License 1.0',
     'https://opendatacommons.org/licenses/odbl/1-0/',
     "Attribution obligatoire, ET partage à l'identique : une base dérivée "
     "doit être publiée sous la même licence. C'est la plus contraignante des "
     "quatre, et celle qui couvre le plus de rubriques ici."),
    ('CC BY 4.0', 'Creative Commons Attribution 4.0',
     'https://creativecommons.org/licenses/by/4.0/deed.fr',
     "Attribution obligatoire : nommer l'auteur, la licence, et signaler si "
     "la donnée a été modifiée — ce qui est le cas de toutes nos couches, "
     "filtrées et reprojetées."),
    ('NLOD', 'Norsk lisens for offentlige data 2.0',
     'https://data.norge.no/nlod/no/2.0',
     "Attribution obligatoire, réutilisation libre par ailleurs. C'est la "
     "licence des données publiques norvégiennes."),
    ('CC0', 'Creative Commons Zero 1.0',
     'https://creativecommons.org/publicdomain/zero/1.0/deed.fr',
     "Aucune obligation : renonciation au droit d'auteur. Citer la source "
     "reste une courtoisie, et un service rendu à qui voudra vérifier."),
]

# Ce que l'application affiche aujourd'hui, pour mesurer l'écart. Relevé le
# 10/10/2026 dans 03-carte-routiere-nsf-v1_8_0.html, clé de traduction
# doc.odbl_text, version française.
AFFICHE = ("La couche des services est dérivée d'OpenStreetMap : © les "
           "contributeurs OpenStreetMap, sous licence ODbL. Les autres couches "
           "relèvent de la NLOD norvégienne ou de la CC BY 4.0 finlandaise.")


def esc(s):
    if s is None:
        return ''
    return str(s).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def main():
    if not os.path.exists(SOURCE):
        print('ARRÊT — manifest-donnees.json introuvable.')
        print('  Ce script vit dans le dépôt DE DONNÉES.')
        return 1

    M = json.load(io.open(SOURCE, encoding='utf-8'))
    man = M['manifest']
    rubs = M['rubriques']

    iso = str(man.get('genere_le') or '')
    if len(iso) >= 16 and iso[4] == '-' and iso[10] == 'T':
        stamp = ('Version %s — %d %s %s à %s:%s'
                 % (man.get('version', '?'), int(iso[8:10]), MOIS[int(iso[5:7]) - 1],
                    iso[0:4], iso[11:13], iso[14:16]))
    else:
        stamp = 'Version %s' % man.get('version', '?')

    # --- la charte, reprise du document de specs du module 05
    pistes = [os.path.join(RACINE, '..', 'Periple-Nordique',
                           '05-comparateur-previsions',
                           '05-comparateur-modeles-nsf-specs-v1_0_0.html'),
              os.path.join(RACINE, 'docs', 'charte-specs.html')]
    css = None
    for c in pistes:
        if os.path.exists(c):
            spec = io.open(c, encoding='utf-8', errors='replace').read()
            css = spec[spec.find('<style>'):spec.find('</style>') + 8]
            print('charte reprise de : %s' % os.path.normpath(c))
            break
    if not css:
        print('ARRÊT — charte introuvable : le document serait illisible.')
        print('  Attendue dans le module 05 du dépôt applicatif, à côté.')
        return 1

    css = css.replace('</style>', """
.tag{display:inline-block;border:1px solid var(--line);border-radius:999px;padding:1px 9px;font-size:.82em;color:var(--txt2)}
.tag.ko{color:var(--ko);border-color:var(--ko)}
.tag.ok{color:var(--ok);border-color:var(--ok)}
.tag.warn{color:var(--warn);border-color:var(--warn)}
.kpi{display:flex;flex-wrap:wrap;gap:12px;margin:12px 0}
.kpi div{flex:1 1 150px;background:var(--panel2);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
.kpi b{display:block;font-size:1.5em;color:var(--acc)}
.kpi span{color:var(--txt2);font-size:.88em}
@media print{.kpi div{background:none;border:1px solid #000}.kpi b{color:#000}.kpi span{color:#000}.tag{border-color:#000;color:#000}}
</style>""")

    # --- répartition par famille de licence
    familles = {}
    sans = []
    a_etablir = []
    for r in rubs:
        lic = (r.get('licence') or '').strip()
        if not lic:
            sans.append(r)
            continue
        if 'à établir' in lic.lower():
            a_etablir.append(r)
        touche = False
        for code, _, _, _ in OBLIGATIONS:
            if code.lower() in lic.lower():
                familles.setdefault(code, []).append(r)
                touche = True
        if not touche and ('interne' in lic.lower() or 'sans objet' in lic.lower()):
            familles.setdefault('interne', []).append(r)

    attribuables = sorted({r['id'] for code in ('ODbL', 'CC BY 4.0', 'NLOD')
                           for r in familles.get(code, [])})

    def section(ouvert, titre, corps):
        return ('<section%s><button class="toggle"><span class="chev">▶</span>%s'
                '</button><div class="body">%s</div></section>'
                % (' class="open"' if ouvert else '', titre, corps))

    # --- 1. ce qu'il faut créditer
    lignes = []
    for code, nom, url, obligation in OBLIGATIONS:
        rs = familles.get(code, [])
        lignes.append(
            '<tr><td><b>%s</b><br><span class="mini">%s</span></td>'
            '<td>%d<br><span class="mini">%s</span></td><td>%s<br>'
            '<span class="mini"><a href="%s">%s</a></span></td></tr>'
            % (esc(code), esc(nom), len(rs),
               esc(', '.join(r['id'] for r in rs)) or '—',
               esc(obligation), esc(url), esc(url)))
    credit = ('<p>Trois des quatre familles exigent une attribution. Le nombre de '
              'rubriques concernées est compté sur le manifeste, pas recopié.</p>'
              '<div class="tablewrap"><table><thead><tr><th>Licence</th>'
              '<th>Rubriques</th><th>Ce qu\'elle impose</th></tr></thead><tbody>'
              + ''.join(lignes) + '</tbody></table></div>'
              '<div class="box warn"><b>Le partage à l\'identique de l\'ODbL</b>'
              'Une base dérivée d\'OpenStreetMap doit être publiée sous ODbL. '
              'C\'est l\'une des raisons pour lesquelles le dépôt de données reste '
              'public — l\'autre étant que l\'application lit ses couches par '
              'raw.githubusercontent.com, qui ne sait pas s\'authentifier.</div>')

    # --- 2. l'écart avec ce que l'application affiche
    odbl = [r['id'] for r in familles.get('ODbL', [])]
    ecart = (
        '<p>Relevé le 10/10/2026 dans l\'onglet Doc du module 03, en six '
        'langues :</p><div class="box"><b>Texte affiché</b>%s</div>'
        '<p>Le manifeste en dit autrement :</p><ul>'
        '<li><b>ODbL : %d rubriques</b>, et non la seule couche des services — '
        '%s.</li>'
        '<li><b>CC0 : %d rubriques</b>, les données suédoises, non mentionnées. '
        'Sans conséquence : CC0 n\'impose rien.</li>'
        '<li>NLOD et CC BY 4.0 sont nommées, mais sans leurs producteurs — '
        'or ces deux licences demandent de nommer l\'auteur.</li></ul>'
        '<div class="box warn"><b>Ce qui reste à décider</b>'
        'Corriger ce texte touche six langues et impose une révision du module '
        '03. Le registre dit l\'écart ; il ne le corrige pas de lui-même.</div>'
        '<div class="box ok"><b>Texte proposé, à vérifier avant emploi</b>'
        'Données routières et géographiques : © les contributeurs OpenStreetMap '
        '(ODbL) ; Statens vegvesen et Miljødirektoratet, Norvège (NLOD) ; '
        'Trafikverket et Lantmäteriet, Suède (CC0) ; Väylävirasto et SYKE, '
        'Finlande (CC BY 4.0). Couches filtrées et reprojetées pour cette '
        'application.</div>'
        % (esc(AFFICHE), len(odbl), esc(', '.join(odbl)),
           len(familles.get('CC0', []))))

    # --- 3. le registre, rubrique par rubrique
    lignes = []
    for r in sorted(rubs, key=lambda x: x.get('ordre', 99)):
        lic = (r.get('licence') or '').strip()
        tag = ''
        if not lic:
            tag = ' <span class="tag ko">licence absente</span>'
        elif 'à établir' in lic.lower():
            tag = ' <span class="tag warn">incomplète</span>'
        lignes.append(
            '<tr><td><b>%s</b>%s<br><span class="mini">%s</span></td>'
            '<td><code>%s</code></td><td>%s</td><td>%s</td></tr>'
            % (esc(r['id']), tag, esc(r.get('libelle')),
               esc(r.get('fichier') or '—'),
               esc(r.get('source') or '<i>(vide)</i>'),
               esc(lic) or '<i>(vide)</i>'))
    registre = ('<div class="tablewrap"><table><thead><tr><th>Rubrique</th>'
                '<th>Fichier</th><th>Source</th><th>Licence</th></tr></thead>'
                '<tbody>' + ''.join(lignes) + '</tbody></table></div>')

    # --- 4. ce qui manque
    trous = []
    for r in sans:
        trous.append('<li><b>%s</b> — ni source ni licence. %s</li>'
                     % (esc(r['id']), esc(r.get('prochaine_action') or '')))
    for r in a_etablir:
        trous.append('<li><b>%s</b> — licence partielle : %s</li>'
                     % (esc(r['id']), esc(r.get('licence'))))
    manques = ('<ul>%s</ul>' % ''.join(trous) if trous
               else '<div class="box ok"><b>Rien à signaler</b>Toutes les '
                    'rubriques portent une source et une licence complètes.</div>')

    corps = (
        section(True, 'Ce qu\'il faut créditer, et pourquoi', credit)
        + section(True, 'L\'écart avec ce que l\'application affiche', ecart)
        + section(True, 'Le registre, rubrique par rubrique', registre)
        + section(True, 'Ce qui manque encore', manques))

    page = """<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Sources et licences — Périple nordique 2027</title>
%(css)s
</head>
<body>
<div class="wrap">
<div class="top">
<h1>Sources et licences des couches de données</h1>
<p class="sub">Périple nordique 2027 — Norvège, Suède, Finlande</p>
<p class="ver">%(stamp)s</p>
<div class="box"><b>Ce document est engendré</b>Il est produit par
<code>outils/gen-licences.py</code> depuis <code>manifest-donnees.json</code>,
et ne doit jamais être édité à la main : toute correction se porte au manifeste,
champs <code>source</code> et <code>licence</code> de la rubrique, puis on
relance le script. Il ne peut donc pas diverger de la source de vérité.</div>
<div class="kpi">
<div><b>%(nr)d</b><span>rubriques</span></div>
<div><b>%(na)d</b><span>exigeant une attribution</span></div>
<div><b>%(nf)d</b><span>familles de licences</span></div>
<div><b>%(nt)d</b><span>à compléter</span></div>
</div>
<div class="actions">
<button onclick="document.querySelectorAll('section').forEach(s=>s.classList.add('open'))">Tout déplier</button>
<button onclick="document.querySelectorAll('section').forEach(s=>s.classList.remove('open'))">Tout replier</button>
</div>
</div>
%(corps)s
<footer>%(stamp)s — engendré par outils/gen-licences.py depuis le manifeste.
<br>Philippe Destiné</footer>
</div>
<script>
document.querySelectorAll('button.toggle').forEach(function(b){
  b.addEventListener('click', function(){ b.parentElement.classList.toggle('open'); });
});
</script>
</body>
</html>
""" % {'css': css, 'stamp': esc(stamp), 'corps': corps,
       'nr': len(rubs), 'na': len(attribuables),
       'nf': len([c for c in familles if c != 'interne']),
       'nt': len(sans) + len(a_etablir)}

    io.open(CIBLE, 'w', encoding='utf-8').write(page)
    print('rubriques : %d | attribution obligatoire : %d | à compléter : %d'
          % (len(rubs), len(attribuables), len(sans) + len(a_etablir)))
    print('-> %s' % CIBLE)
    return 0


if __name__ == '__main__':
    sys.exit(main())
