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
_travail/                  Extractions brutes et essais — ignoré par Git, jamais publié
```

Chaque entité porte une propriété `country` valant `no`, `se` ou `fi`. Un fichier par
rubrique plutôt qu'un fichier par rubrique et par pays : cela divise par trois le nombre
de requêtes au chargement de l'application.

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

### Transformations appliquées

Les fichiers publiés ne sont pas les données sources telles quelles. Ont été appliqués :
conversion vers le schéma commun décrit dans le manifeste, permutation des axes — la NVDB
renvoie latitude puis longitude en srid 4326 —, retrait de l'altitude, simplification des
tracés à environ 10 mètres pour les couches norvégiennes et 27 mètres pour la couche
finlandaise, filtrage sur le PTAC de 3 500 kg pour les restrictions de dégel, et
composition d'étiquettes pour les entités sans nom de source, signalées par la propriété
`nom_compose`.

### Sources non encore utilisées

**OpenStreetMap** : ODbL, avec mention `© les contributeurs OpenStreetMap`, et propagation
de la licence aux données dérivées. Toute couche en contenant sera publiée en ODbL et
signalée comme telle ici. **Trafikverket, Suède** : conditions de l'Öppet API à lire avant
toute republication.

---

## Conventions

- Format **GeoJSON**, coordonnées en WGS 84, longitude puis latitude.
- Noms de fichiers en minuscules, sans accent ni espace, mots séparés par des tirets.
- Un commit par rubrique publiée, avec le nom de la rubrique dans le résumé.
- Les extractions brutes restent dans `_travail/` et ne sont jamais versionnées.
