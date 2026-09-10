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

À compléter au fur et à mesure des collectes. Chaque couche publiée doit voir sa source et
sa licence renseignées dans le manifeste, et l'attribution requise reportée ici.

Les données issues d'OpenStreetMap sont soumises à l'ODbL et imposent la mention
`© les contributeurs OpenStreetMap`. Les portails nationaux — Statens vegvesen,
Trafikverket, Fintraffic, Väylävirasto — ont chacun leurs propres conditions, à vérifier
avant publication et non après.

---

## Conventions

- Format **GeoJSON**, coordonnées en WGS 84, longitude puis latitude.
- Noms de fichiers en minuscules, sans accent ni espace, mots séparés par des tirets.
- Un commit par rubrique publiée, avec le nom de la rubrique dans le résumé.
- Les extractions brutes restent dans `_travail/` et ne sont jamais versionnées.
