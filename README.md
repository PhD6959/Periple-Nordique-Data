# Periple-Nordique-Data

Couches de données cartographiques du périple nordique 2027 — Norvège, Suède, Finlande.

Ce dépôt alimente le **module 3** de l'application (routes, ferries, tunnels, points
d'intérêt et services). Les couches sont lues directement par l'application via
`raw.githubusercontent.com`, ce qui impose que **le dépôt reste public**.

Il est **indépendant de l'environnement Islande / Îles Féroé**, qui garde son propre dépôt
`Meteo-Islande-Feroe-Data`. Aucun fichier n'est partagé entre les deux.

---

## Organisation

```
manifest-donnees.json      Manifeste des rubriques : source, licence, état, fraîcheur
sources/                   Couches publiées, une par rubrique, les trois pays confondus
sources/blocs/             Tracés des blocs d'itinéraire, un fichier par bloc
outils/                    Scripts de collecte et de conversion, un par étape
docs/                      Documents engendrés depuis le manifeste
```

Chaque entité porte une propriété `country` valant `no`, `se` ou `fi`. Un fichier par
rubrique plutôt qu'un fichier par rubrique et par pays : cela divise par trois le nombre
de requêtes au chargement de l'application.

### Ce qui va où, et pourquoi

**`sources/`** — uniquement les couches publiées, prêtes à être lues par l'application.
Rien d'intermédiaire, rien d'expérimental : ce répertoire est l'interface avec le module 3.

**`outils/`** — les scripts qui produisent ces couches, numérotés dans l'ordre où ils
s'exécutent. Ils vivent ici et non ailleurs parce que quatre rubriques sont saisonnières
et devront être recollectées avant le départ. Un script perdu, c'est une collecte à
réinventer.

**`docs/`** — les documents engendrés depuis `manifest-donnees.json`. Ils vivent à côté
de leur source, faute de quoi ils divergeraient. Le document de suivi est régénéré à
chaque avancement, jamais modifié à la main.

**Racine** — le manifeste, le README, la configuration Git. Rien d'autre.

**Hors du dépôt** — les extractions brutes, les fichiers intermédiaires et les essais.
Ils représentent des dizaines de mégaoctets sans valeur de publication, et sont conservés
dans un dossier de travail voisin du dépôt. Le `.gitignore` couvre `_travail/` pour le cas
où l'on en créerait un ici, mais la règle reste : ce qui n'est pas destiné à être lu par
l'application ou par un humain ne franchit pas la limite du dépôt.

---

## Le manifeste

`manifest-donnees.json` est la **source de vérité** de ce dépôt. Il décrit, pour chaque
rubrique : la source, sa licence, le fichier cible, la date de collecte, la nature —
permanente ou saisonnière —, le responsable et l'état d'avancement par pays.

Le document de suivi `doc-module-03-nsf-suivi.html` en est engendré et ne peut donc pas
diverger. **Toute correction se porte dans le manifeste**, puis le document est régénéré.

À ne pas confondre avec le `manifest.json` de l'application, qui est un manifeste de PWA
et vit dans l'autre dépôt.

---

## Rubriques saisonnières

Quatre rubriques portent des données qui se périment : **cols et fermetures**,
**péages**, **restrictions de dégel**, **routes de glace**.

Une donnée collectée en 2026 sera fausse au départ du 15 avril 2027. Ces rubriques ne sont
jamais acquises : elles doivent être revérifiées dans les semaines précédant le départ,
même affichées comme terminées dans le suivi. Le manifeste porte pour chacune un champ
`rafraichir_avant_depart`.

---

## Sources et attributions

Chaque couche publiée voit sa source et sa licence renseignées dans le manifeste. Les
attributions requises sont reportées ci-dessous, couche par couche.

### `sources/cols-fermetures.geojson`

Données dérivées de la **Nasjonal vegdatabank (NVDB)**, Statens vegvesen, Norvège.
Vegobjekttyper 107 « Værutsatt veg » et 883 « Skredutsatt veg », extraites le
10 septembre 2026 via l'API Les V4.

> Contient des données de Statens vegvesen, mises à disposition sous
> **Norsk lisens for offentlige data (NLOD)**.

### `sources/ferries.geojson`

Données dérivées de la **Nasjonal vegdatabank (NVDB)**, Statens vegvesen, Norvège.
Vegobjekttyper 770 « Ferjesamband » et 64 « Ferjekai », extraites le 10 septembre 2026.

> Contient des données de Statens vegvesen, mises à disposition sous
> **Norsk lisens for offentlige data (NLOD)**.

### `sources/restrictions-degel.geojson`

Données dérivées de **Digiroad**, Väylävirasto (Agence finlandaise des infrastructures
de transport). Couche `dr_kelirikko`, extraite le 10 septembre 2026 via l'interface WFS
ouverte.

> Lähde: Väylävirasto / latauspalvelu, lisenssi **CC 4.0 BY**.
> Source : Väylävirasto / service de téléchargement, licence **CC BY 4.0**.

### `sources/tunnels.geojson`, `sources/peages.geojson`, `sources/barrieres.geojson`

Données dérivées de la **Nasjonal vegdatabank (NVDB)**, Statens vegvesen, Norvège.
Vegobjekttyper 581 « Tunnel », 45 « Bomstasjon » et 607 « Vegsperring », extraites le
10 septembre 2026 via l'API Les V4.

> Contient des données de Statens vegvesen, mises à disposition sous
> **Norsk lisens for offentlige data (NLOD)**.

### `sources/services.geojson`

Données dérivées d'**OpenStreetMap**, extraites le 10 septembre 2026 via l'API Overpass
(`amenity=fuel`, `shop=supermarket`, `shop=convenience`, `shop=alcohol`).

> © les contributeurs OpenStreetMap, sous licence **ODbL**.

**Cette couche est publiée sous ODbL**, la licence se propageant aux données dérivées.
Elle et la couche des aires de camping-car sont les seules du dépôt dans ce cas : les autres restent sous NLOD ou CC BY 4.0. Toute
réutilisation de ce fichier est donc soumise à l'ODbL, y compris l'obligation de partager
à l'identique les travaux qui en dériveraient.

### `sources/aires-camping-car.geojson`

Données dérivées d'**OpenStreetMap**, extraites le 10 septembre 2026 via l'API Overpass
(`tourism=caravan_site`, `amenity=sanitary_dump_station`, `tourism=camp_site`,
`amenity=drinking_water`, `shop`/`amenity=laundry`).

> © les contributeurs OpenStreetMap, sous licence **ODbL**.

Publiée sous ODbL, comme la couche des services.

### Transformations appliquées

Les fichiers publiés ne sont pas les données sources telles quelles. Ont été appliqués :
conversion vers le schéma commun décrit dans le manifeste, permutation des axes — la NVDB
renvoie latitude puis longitude en srid 4326 —, retrait de l'altitude, simplification des
tracés à environ 10 mètres pour les couches norvégiennes et 27 mètres pour la couche
finlandaise, filtrage sur le PTAC de 3 500 kg pour les restrictions de dégel, et
composition d'étiquettes pour les entités sans nom de source, signalées par la propriété
`nom_compose`, normalisation des enseignes pour la couche des services — établie à partir des libellés observés, le libellé d'origine restant conservé sur chaque entité —, et sélection thématique pour trois couches : les tunnels sont filtrés sur la
longueur, le caractère sous-marin et les restrictions sur les marchandises dangereuses ; les
barrières sont restreintes aux voies privées, forestières et communales et aux fonctions de
fermeture véritable. Ces filtres sont documentés rubrique par rubrique dans le manifeste.

### Sources non encore utilisées

**Trafikverket, Suède** : l'Öppet API est publié sous
**Creative Commons CC0** — aucune restriction, pas même l'obligation d'attribution. La
source sera néanmoins mentionnée ici lors de la première publication d'une couche
suédoise, par correction.

---

## Conventions

- Format **GeoJSON**, coordonnées en WGS 84, longitude puis latitude.
- Noms de fichiers en minuscules, sans accent ni espace, mots séparés par des tirets.
- Un commit par rubrique publiée, avec le nom de la rubrique dans le résumé.
- Les extractions brutes restent dans `_travail/` et ne sont jamais versionnées.
