#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
ENGENDRE LE DOCUMENT DE SUIVI À PARTIR DU MANIFESTE
Périple nordique 2027 — dépôt Periple-Nordique-Data
=============================================================================

docs/doc-module-03-nsf-suivi.html est ENGENDRÉ, jamais édité à la main. Toute
correction se porte dans manifest-donnees.json, puis on relance ce script. Le
suivi ne peut donc pas diverger de la source de vérité.

UTILISATION — depuis n'importe où
    python3 outils/gen-suivi.py

Il lit ../manifest-donnees.json par rapport à sa propre position et écrit
../docs/doc-module-03-nsf-suivi.html. La mention de version vient du manifeste :
aucun numéro à tenir ici.

POURQUOI PYTHON ET NON NODE : node n'est pas installé sur le Mac de Philippe,
alors que python3 y fait tourner les trente-sept scripts de collecte. Une
dépendance de moins. Ce script est le portage fidèle du générateur JavaScript
d'origine, vérifié par comparaison des documents produits.
=============================================================================
"""
import io
import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(RACINE, 'manifest-donnees.json')
CIBLE = os.path.join(RACINE, 'docs', 'doc-module-03-nsf-suivi.html')

if not os.path.exists(SOURCE):
    print("Manifeste introuvable : %s" % SOURCE)
    print("Ce script doit vivre dans outils/ à la racine du dépôt de données.")
    sys.exit(1)

M = json.load(io.open(SOURCE, encoding='utf-8'))
man = M['manifest']
rubs = sorted(M['rubriques'], key=lambda r: r['ordre'])
ETAT = {e['id']: e for e in man['etats']}
PAYS = man['pays']

MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
        'août', 'septembre', 'octobre', 'novembre', 'décembre']


def horodatage():
    """On lit l'horodatage du manifeste tel qu'il est écrit : le convertir
    ferait varier l'heure affichée selon la machine qui relance le script."""
    iso = str(man.get('genere_le') or '')
    if len(iso) >= 16 and iso[4] == '-' and iso[10] == 'T':
        an, mo, jo = iso[0:4], int(iso[5:7]), int(iso[8:10])
        return 'Version %s — %d %s %s à %s:%s' % (
            man.get('version', '?'), jo, MOIS[mo - 1], an, iso[11:13], iso[14:16])
    return 'Version %s' % man.get('version', '?')


STAMP = horodatage()


def esc(s):
    if s is None:
        return ''
    return str(s).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def qui(k):
    return {'claude': 'Claude', 'philippe': 'Philippe', 'les-deux': 'Les deux',
            'philippe-et-claude': 'Les deux'}.get(k, k)


def badge(eid):
    e = ETAT[eid]
    return ('<span class="etat" style="border-color:%s;color:%s">%s</span>'
            % (e['couleur'], e['couleur'], esc(e['libelle'])))


def section(ouvert, titre, corps):
    return ('<section%s><button class="toggle"><span class="chev">▶</span>%s</button>'
            '<div class="body">%s</div></section>'
            % (' class="open"' if ouvert else '', titre, corps))


# --------------------------------------------------------------- statistiques
cells = [ETAT[r['etats'][p['code']]] for r in rubs for p in PAYS]
totalCells = len(cells)
doneCells = sum(1 for e in cells if e['terminal'])
rubDone = sum(1 for r in rubs if all(ETAT[r['etats'][p['code']]]['terminal'] for p in PAYS))
saison = [r for r in rubs if r.get('nature') == 'saisonniere']

# ------------------------------------------------------------ feuille de style
PISTES = [os.path.join(RACINE, '..', 'Periple-Nordique', '05-comparateur-previsions',
                       '05-comparateur-modeles-nsf-specs-v1_0_0.html'),
          os.path.join(RACINE, 'docs', 'charte-specs.html')]
CSS = None
for c in PISTES:
    if os.path.exists(c):
        spec = io.open(c, encoding='utf-8', errors='replace').read()
        CSS = spec[spec.find('<style>'):spec.find('</style>') + 8]
        print('charte reprise de : %s' % os.path.normpath(c))
        break
if not CSS:
    print('charte de secours : document de specs du module 05 introuvable')
    CSS = ('<style>'
           ':root{--bg:#0f172a;--panel:#1e293b;--panel2:#273449;--line:#334155;'
           '--txt:#e2e8f0;--txt2:#94a3b8;--acc:#38bdf8;--warn:#fbbf24;--ok:#4ade80;--ko:#f87171}'
           'body{background:var(--bg);color:var(--txt);font-family:Inter,system-ui,sans-serif;'
           'margin:0;padding:24px;line-height:1.55}.wrap{max-width:1180px;margin:0 auto}'
           'h1,h2,h3,h4{color:var(--txt)}code{background:var(--panel2);padding:1px 5px;border-radius:4px}'
           'table{width:100%;border-collapse:collapse;margin:10px 0}'
           'th,td{border:1px solid var(--line);padding:7px 10px;text-align:left;vertical-align:top}'
           'th{background:var(--panel2)}section{background:var(--panel);border:1px solid var(--line);'
           'border-radius:12px;margin:12px 0;overflow:hidden}'
           'button.toggle{width:100%;text-align:left;background:var(--panel2);color:var(--txt);'
           'border:0;padding:12px 16px;font-size:1.02em;cursor:pointer}'
           'section .body{display:none;padding:4px 16px 16px}section.open .body{display:block}'
           '.box{background:var(--panel2);border-left:3px solid var(--acc);border-radius:8px;'
           'padding:10px 14px;margin:10px 0}.box.warn{border-left-color:var(--warn)}'
           '.box.ok{border-left-color:var(--ok)}.box b{display:block;margin-bottom:4px}'
           '.tablewrap{overflow-x:auto}.top{margin-bottom:18px}.ver{color:var(--acc)}'
           '.sub{color:var(--txt2)}.actions{margin-top:10px}'
           '.actions button{background:var(--panel2);color:var(--txt);border:1px solid var(--line);'
           'border-radius:8px;padding:7px 14px;margin-right:8px;cursor:pointer}'
           'pre.code{background:var(--panel2);padding:10px 14px;border-radius:8px;overflow-x:auto}'
           'footer{color:var(--txt2);font-size:.9em;margin-top:24px}'
           '</style>')

CSS = CSS.replace('</style>', """
.etat{display:inline-block;border:1px solid;border-radius:999px;padding:2px 10px;font-size:.82em;white-space:nowrap}
.mini{color:var(--txt2);font-size:.82em}
.tag{display:inline-block;border:1px solid var(--line);border-radius:999px;padding:1px 9px;font-size:.82em;color:var(--txt2)}
.tag.warn{color:var(--warn);border-color:var(--warn)}
.kpi{display:flex;flex-wrap:wrap;gap:12px;margin:12px 0}
.kpi div{flex:1 1 160px;background:var(--panel2);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
.kpi b{display:block;font-size:1.5em;color:var(--acc)}
.kpi span{color:var(--txt2);font-size:.88em}
table th[scope],tbody th{color:#dceaf7;background:#17324a;width:34%}
@media print{.etat{border-color:#000;color:#000}.kpi div{background:none;border:1px solid #000}.kpi b{color:#000}.kpi span{color:#000}tbody th{background:#eee;color:#000}}
</style>""")

# ------------------------------------------------------------------ synthèse
synth = ('<div class="tablewrap"><table><thead><tr><th>#</th><th>Rubrique</th>'
         '<th>Nature</th><th>Qui</th>'
         + ''.join('<th>%s %s</th>' % (p['drapeau'], esc(p['nom'])) for p in PAYS)
         + '</tr></thead><tbody>')
for r in rubs:
    synth += ('<tr><td>%d</td><td><b>%s</b>%s</td><td>%s</td><td>%s</td>%s</tr>'
              % (r['ordre'], esc(r['libelle']),
                 ('<br><span class="mini">remplace %s</span>' % esc(r['remplace'])) if r.get('remplace') else '',
                 '<span class="tag warn">saisonnière</span>' if r.get('nature') == 'saisonniere'
                 else '<span class="tag">permanente</span>',
                 esc(qui(r.get('qui'))),
                 ''.join('<td>%s</td>' % badge(r['etats'][p['code']]) for p in PAYS)))
synth += '</tbody></table></div>'

corpsSynthese = (
    '<div class="kpi">'
    '<div><b>%d / %d</b><span>rubriques terminées sur les trois pays</span></div>'
    '<div><b>%d / %d</b><span>cases terminales (rubrique × pays)</span></div>'
    '<div><b>%d</b><span>rubriques saisonnières à rafraîchir avant le départ</span></div>'
    '</div>%s'
    '<div class="box warn"><b>Rubriques saisonnières</b>%s'
    ' — une donnée collectée aujourd\'hui sera fausse au départ du 15 avril 2027. Ces '
    'rubriques ne sont jamais « acquises » : elles doivent être revérifiées dans les '
    'semaines précédant le départ, même affichées comme terminées.</div>'
    % (rubDone, len(rubs), doneCells, totalCells, len(saison), synth,
       ' · '.join(esc(r['libelle']) for r in saison)))

# ------------------------------------------------------------------- légende
SENS = {
    'a-faire': "Rien n'a encore été entrepris.",
    'source-identifiee': "On sait où trouver la donnée et sous quelle licence. Rien n'est collecté.",
    'donnees-collectees': "Le fichier existe et a été contrôlé, mais n'est pas publié.",
    'publiee-github': "Le fichier est en ligne dans le dépôt, lisible par l'application.",
    'integree-app': "La couche est branchée dans le module et s'affiche.",
    'recette-faite': "Vérifiée à l'écran par Philippe. État terminal.",
    'traite-par-lien': "Aucune donnée ouverte exploitable : on renvoie vers le service officiel. État terminal, ce n'est pas un échec.",
    'sans-objet': "La rubrique n'a pas de sens pour ce pays. État terminal.",
}
legende = ('<div class="tablewrap"><table><thead><tr><th>État</th><th>Signification</th>'
           '</tr></thead><tbody>'
           + ''.join('<tr><td>%s</td><td>%s</td></tr>' % (badge(e['id']), SENS.get(e['id'], ''))
                     for e in man['etats'])
           + '</tbody></table></div>')

# ------------------------------------------------------------------- méthode
corpsMethode = """
<h3>Comment ce document est produit</h3>
<p>Il est engendré à partir de <code>manifest-donnees.json</code>, qui décrit chaque rubrique : source,
licence, fichier, date de collecte, nature, responsable et état par pays. Le tableau ne peut donc pas
diverger du manifeste. <b>Toute correction se porte dans le JSON</b>, puis le document est régénéré
par <code>python3 outils/gen-suivi.py</code>.</p>
<div class="box ok"><b>Pourquoi un manifeste plutôt qu'un tableau tenu à la main</b>
Le tableau de traductions du module 05 islandais, saisi à la main, portait un numéro de version
décalé d'un cran par rapport à l'application. Un document tenu à la main diverge. Le manifeste
supprime cette classe d'erreur — et il pourra en outre être lu par l'application elle-même, pour
afficher la fraîcheur de chaque couche, voire masquer une couche non publiée.</div>

<h3>Enchaînement des états</h3>
<p>Les états sont séquentiels : la publication sur GitHub précède l'intégration dans l'application,
puisque le module lit ses couches depuis le dépôt. Deux états terminaux ne sont pas des échecs :
<b>traité par lien</b>, quand aucune donnée ouverte n'existe et qu'on renvoie vers le service
officiel, et <b>sans objet</b>, quand la rubrique n'a pas de sens pour un pays.</p>

<h3>Structure des fichiers de données</h3>
<p>Un fichier GeoJSON par rubrique, les trois pays confondus, avec une propriété <code>country</code>
sur chaque entité. Un fichier par rubrique et par pays multiplierait par trois le nombre de requêtes
au chargement sans rien apporter.</p>

<h3>Hébergement</h3>
<p>Les données vivent dans le dépôt public <code>Periple-Nordique-Data</code> : manifeste et README à
la racine, couches dans <code>sources/</code>, scripts de collecte dans <code>outils/</code>,
documents engendrés dans <code>docs/</code>. L'application vit dans un dépôt distinct,
<code>Periple-Nordique</code>, privé mais servi publiquement par GitHub Pages. La séparation tient à
la licence : les données portent des obligations d'attribution, l'application non.</p>

<h3>Répartition</h3>
<div class="tablewrap"><table><tbody>"""
corpsMethode += ''.join('<tr><th>%s</th><td>%s</td></tr>' % (esc(qui(k)), esc(v))
                        for k, v in man['acteurs'].items())
corpsMethode += """</tbody></table></div>
<p>La colonne « Qui » existe pour éviter qu'une rubrique reste en attente parce que chacun croit que
l'autre s'en occupe. Les rubriques marquées « Les deux » demandent un arbitrage de périmètre ou un
jugement de terrain avant que la collecte puisse commencer.</p>"""

# ----------------------------------------------------------- ordre de travail
ordreTravail = """
<p>L'ordre initial était établi par utilité décroissante rapportée à l'effort. Il a été suivi, et la
plupart des rubriques sont désormais publiées : le tableau de synthèse donne l'état réel.</p>
<div class="box"><b>Ce qui reste, et dans quel ordre</b>
Voir la section « Questions ouvertes », triée par priorité et par responsable. Les rubriques
saisonnières ne sont pas un reste : elles sont terminées pour cette saison et devront être
recollectées au printemps 2027, comme le dit la section « Vérification avant le départ ».</div>
<div class="box warn"><b>Ce qui décide encore d'un itinéraire</b>
Les hauteurs limitées — 2 634 obstacles infranchissables à 3,20 m sur les trois pays — et les cols
et fermetures saisonnières, dont les dates 2027 ne seront connues qu'au printemps. Ce sont les deux
rubriques à ne pas prendre pour acquises.</div>"""

# ------------------------------------------------------------------ document
html = ('<!DOCTYPE html>\n<html lang="fr">\n<head>\n<meta charset="UTF-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n'
        '<title>Module 03 NSF — Suivi des rubriques de données</title>\n'
        + CSS + '\n</head>\n<body>\n<div class="wrap">\n')

html += ('<header class="top">\n<h1>Module 03 — Suivi des rubriques de données · '
         'Norvège / Suède / Finlande</h1>\n'
         '<div class="sub">%s</div>\n<div class="ver">%s</div>\n'
         '<div class="actions"><button onclick="allOpen(true)">Tout déplier</button>'
         '<button onclick="allOpen(false)">Tout replier</button></div>\n</header>\n'
         % (esc(man['libelle']), STAMP))

html += section(True, 'Synthèse', corpsSynthese)
html += section(False, 'Méthode et conventions', corpsMethode)
html += section(False, 'Ordre de travail', ordreTravail)
html += section(False, 'Légende des états', legende)

# --------------------------------------------------------------- conventions
CV = M.get('conventions_de_travail')
if CV:
    c = '<div class="box warn"><b>Règle</b>%s</div>' % esc(CV.get('regle'))
    c += '<div class="box"><b>Pourquoi</b>%s</div>' % esc(CV.get('raison'))
    c += "<h3>Ce qu'il faut écrire, selon le cas</h3>"
    for x in CV.get('a_documenter_selon_le_cas', []):
        c += '<h4>%s</h4><ul>%s</ul>' % (
            esc(x.get('cas')), ''.join('<li>%s</li>' % esc(o) for o in x.get('ou', [])))
    c += ('<h3>Où se trouve quoi</h3><div class="tablewrap"><table><thead><tr>'
          '<th>Emplacement</th><th>Contenu</th></tr></thead><tbody>'
          + ''.join('<tr><td><code>%s</code></td><td>%s</td></tr>' % (esc(k), esc(v))
                    for k, v in CV.get('carte_de_la_documentation', {}).items())
          + '</tbody></table></div>')
    c += ('<h3>Ce qui ne doit jamais entrer dans un dépôt</h3><ul>'
          + ''.join('<li>%s</li>' % esc(x) for x in CV.get('ce_qui_ne_doit_jamais_entrer_dans_un_depot', []))
          + '</ul>')
    sv = CV.get('sauvegarde')
    if sv:
        c += ('<h3>Sauvegarde</h3><pre class="code">%s</pre><p class="mini">%s</p>'
              '<div class="box warn"><b>Attention</b>%s</div>'
              % (esc(sv.get('commande')), esc(sv.get('portee')), esc(sv.get('attention'))))
    html += section(False, 'Conventions de travail', c)

# ------------------------------------------------------------------ protocole
PV = M.get('protocole_verification')
if PV:
    corps = '<div class="box warn"><b>Principe</b>%s</div>' % esc(PV.get('principe'))
    corps += ('<h3>Calendrier</h3><div class="tablewrap"><table><thead><tr>'
              '<th>Quand</th><th>Quoi</th><th>Pourquoi</th></tr></thead><tbody>'
              + ''.join('<tr><td><b>%s</b></td><td>%s</td><td class="mini">%s</td></tr>'
                        % (esc(c2.get('quand')), esc(c2.get('quoi')), esc(c2.get('pourquoi')))
                        for c2 in PV.get('calendrier', []))
              + '</tbody></table></div>')
    corps += ("<h3>Signes qu'une source a changé</h3><ul>"
              + ''.join('<li>%s</li>' % esc(x) for x in PV.get('signes_qu_une_source_a_change', []))
              + '</ul>')
    corps += '<div class="box"><b>Règle</b>%s</div>' % esc(PV.get('regle'))
    lignes = ''
    for r in M.get('rubriques', []):
        v = r.get('verification')
        if not v:
            continue
        s = str(v.get('saisonnier', '')).upper().startswith('OUI')
        lignes += ('<tr><td><b>%s</b>%s</td><td class="mini"><code>%s</code></td>'
                   '<td class="mini">%s</td><td class="mini">%s</td></tr>'
                   % (esc(r['libelle']),
                      '<br><span class="tag">saisonnière</span>' if s else '',
                      esc(v.get('scripts')), esc(v.get('attendu')), esc(v.get('a_verifier'))))
    corps += ('<h3>Par rubrique</h3><div class="tablewrap"><table><thead><tr>'
              '<th>Rubrique</th><th>Scripts à rejouer</th><th>Volume attendu</th>'
              '<th>À vérifier</th></tr></thead><tbody>' + lignes + '</tbody></table></div>')
    html += section(False, 'Vérification avant le départ', corps)

# ---------------------------------------------------------------- sources API
API = M.get('sources_api') or {}
if API:
    corpsAPI = ''
    for a in API.values():
        corpsAPI += ('<h3>%s</h3><div class="tablewrap"><table><tbody>'
                     '<tr><th>Établi le</th><td>%s</td></tr>'
                     '<tr><th>Point d\'accès</th><td><code>%s</code></td></tr>'
                     '<tr><th>Licence</th><td>%s</td></tr>'
                     '<tr><th>Forme</th><td>%s</td></tr>'
                     '<tr><th>Clé</th><td>%s</td></tr>'
                     '<tr><th>Connexion</th><td>%s</td></tr>'
                     '</tbody></table></div>'
                     '<div class="box warn"><b>Référence</b>%s</div>'
                     % (esc(a.get('libelle')), esc(a.get('etabli_le')), esc(a.get('point_acces')),
                        esc(a.get('licence')), esc(a.get('forme')), esc(a.get('cle')),
                        esc(a.get('connexion')), esc(a.get('reference'))))
        corpsAPI += ('<div class="tablewrap"><table><thead><tr><th>Type</th>'
                     '<th>Espace de noms</th><th>Version</th><th>Contenu</th></tr></thead><tbody>')
        for t in a.get('types_verifies', []):
            corpsAPI += ('<tr><td><b>%s</b></td><td><code>%s</code></td><td>%s</td><td>%s%s</td></tr>'
                         % (esc(t.get('type')), esc(t.get('namespace')), esc(t.get('schemaversion')),
                            esc(t.get('contenu')),
                            ('<br><span class="mini" style="color:var(--warn)">%s</span>'
                             % esc(t['reserve'])) if t.get('reserve') else ''))
        corpsAPI += ('</tbody></table></div><div class="box"><b>À explorer</b>%s</div>'
                     % esc(a.get('a_explorer')))
    html += section(False, 'Sources API vérifiées', corpsAPI)

# ----------------------------------------------------------- questions ouvertes
QO = M.get('questions_ouvertes') or []
RANG = {'haute': 0, 'moyenne': 1, 'basse': 2}
qoTries = sorted(QO, key=lambda q: RANG.get(q.get('priorite'), 9))
corpsQO = '<div class="kpi">'
for pr in ('haute', 'moyenne', 'basse'):
    n = sum(1 for q in QO if q.get('priorite') == pr)
    corpsQO += '<div><b>%d</b><span>priorité %s</span></div>' % (n, pr)
corpsQO += ('</div><div class="tablewrap"><table><thead><tr><th>Sujet</th>'
            '<th>Priorité</th><th>Qui</th></tr></thead><tbody>')
for q in qoTries:
    cls = 'warn' if q.get('priorite') == 'haute' else ''
    fait = (' <span class="tag" style="color:var(--ok);border-color:var(--ok)">traitée</span>'
            if q.get('reponse') else '')
    corpsQO += ('<tr><td><b>%s</b>%s</td><td><span class="tag %s">%s</span></td><td>%s</td></tr>'
                % (esc(q.get('titre')), fait, cls, esc(q.get('priorite')), esc(qui(q.get('pour')))))
corpsQO += '</tbody></table></div>'
for q in qoTries:
    corpsQO += ('<h3>%s</h3><p>%s</p>%s<div class="box"><b>À creuser</b>%s</div>'
                '<p class="mini">Conséquence : %s</p>'
                % (esc(q.get('titre')), esc(q.get('constat')),
                   ('<div class="box ok"><b>Réponse — %s</b>%s</div>'
                    % (esc(q.get('statut', 'traitée')), esc(q.get('reponse')))) if q.get('reponse') else '',
                   esc(q.get('a_creuser')), esc(q.get('consequence'))))
html += section(False, 'Questions ouvertes <span class="tag warn" style="margin-left:8px">%d</span>'
                % len(QO), corpsQO)

# ------------------------------------------------------------ fiches rubriques
def fiche(r):
    h = '<p>%s</p>' % esc(r.get('description'))
    h += ('<div class="tablewrap"><table><tbody>'
          '<tr><th>Fichier</th><td><code>%s</code></td></tr>'
          '<tr><th>Source</th><td>%s</td></tr>'
          '<tr><th>Licence</th><td>%s</td></tr>'
          '<tr><th>Collectée le</th><td>%s</td></tr>'
          '<tr><th>Nature</th><td>%s</td></tr>'
          '<tr><th>Qui</th><td>%s</td></tr>%s</tbody></table></div>'
          % (esc(r.get('fichier')),
             esc(r['source']) if r.get('source') else '<span class="tag warn">à identifier</span>',
             esc(r['licence']) if r.get('licence') else '<span class="tag warn">à identifier</span>',
             esc(r['collecte_le']) if r.get('collecte_le') else '—',
             'saisonnière — <b>à rafraîchir avant le départ</b>' if r.get('nature') == 'saisonniere' else 'permanente',
             esc(qui(r.get('qui'))),
             ''.join('<tr><th>%s %s</th><td>%s</td></tr>'
                     % (p['drapeau'], esc(p['nom']), badge(r['etats'][p['code']])) for p in PAYS)))
    h += '<div class="box"><b>Prochaine action</b>%s</div>' % esc(r.get('prochaine_action'))
    if r.get('notes'):
        h += '<div class="box warn"><b>À savoir</b>%s</div>' % esc(r['notes'])
    v = r.get('verification')
    if v:
        h += ('<div class="box"><b>Vérification avant le départ</b>'
              'Scripts : <code>%s</code><br>Volume attendu : %s<br>Saisonnière : %s<br>'
              'À vérifier : %s</div>'
              % (esc(v.get('scripts')), esc(v.get('attendu')),
                 esc(v.get('saisonnier')), esc(v.get('a_verifier'))))
    return h


for r in rubs:
    done = all(ETAT[r['etats'][p['code']]]['terminal'] for p in PAYS)
    titre = '%d. %s%s%s' % (
        r['ordre'], esc(r['libelle']),
        ' <span class="tag warn" style="margin-left:8px">saisonnière</span>' if r.get('nature') == 'saisonniere' else '',
        ' <span class="tag" style="margin-left:8px;color:var(--ok);border-color:var(--ok)">terminée</span>' if done else '')
    html += section(False, titre, fiche(r))

html += ('<footer>\n<p><span class="ver">%s</span></p>\n'
         '<p>Module 03 NSF · Périple nordique 2027 · Engendré depuis '
         '<code>manifest-donnees.json</code> par <code>outils/gen-suivi.py</code></p>\n'
         '<p>Philippe Destiné</p>\n</footer>\n' % STAMP)

html += ('</div>\n<script>\n'
         'function allOpen(v){ document.querySelectorAll("section").forEach(function(s){ '
         's.classList.toggle("open", v); }); }\n'
         'document.querySelectorAll("button.toggle").forEach(function(b){ '
         'b.addEventListener("click", function(){ b.closest("section").classList.toggle("open"); }); });\n'
         '</script>\n</body>\n</html>\n')

if not os.path.isdir(os.path.dirname(CIBLE)):
    os.makedirs(os.path.dirname(CIBLE))
io.open(CIBLE, 'w', encoding='utf-8').write(html)

print('rubriques : %d | cases : %d | terminales : %d | saisonnières : %d | document : %d caractères'
      % (len(rubs), totalCells, doneCells, len(saison), len(html)))
print('-> %s' % CIBLE)
