# Scripts de collecte et de conversion

Trente-sept scripts, numérotés dans l'ordre où ils ont été écrits. Chacun produit un
**rapport** qui dit les volumes obtenus, les écarts et les anomalies — c'est ce rapport
qui décide de publier ou non, jamais l'absence de message d'erreur.

**Ils sont rejouables.** C'est leur raison d'être : le protocole de vérification avant
départ, au manifeste, consiste à les relancer et à comparer les volumes.

---

## Comment les lancer

Depuis le dossier de travail, hors dépôt, où vivent les extractions brutes :

```bash
cd ~/Documents/Projets/_travail-module-03
bash /chemin/vers/outils/03-etapeNN-….sh
```

Les scripts écrivent leurs données brutes dans des sous-dossiers du répertoire courant
(`_extract`, `_services`, `_aires`, `_pois`, `_vagdata`, `_hauteurs`, `_parcs`, `_trv`,
`_blocs`, `_sefi`). Ces dossiers **ne sont pas sauvegardés** : ils se refont en
relançant le script. Les scripts, eux, le sont.

**La clé de l'API suédoise** est lue dans `~/.trafikverket-key`, jamais écrite dans un
script. Pour la reconstituer :

```bash
printf '%s' 'LA_CLE' > ~/.trafikverket-key && chmod 600 ~/.trafikverket-key
```

---

## Norvège — base NVDB

| Script | Ce qu'il fait |
|---|---|
| `03-etape1-reconnaissance.sh` | Explore le catalogue d'objets de la NVDB, liste les types disponibles |
| `03-etape2-extraction.sh` | Extrait les cols et fermetures, types 107 et 883 |
| `03-etape3a-profil.sh` | Profile les attributs obtenus avant conversion |
| `03-etape3b-conversion.sh` | Convertit vers le schéma commun |
| `03-etape3c-correction.sh` | Corrige la permutation latitude/longitude du WKT NVDB |
| `03-etape3d-finition.sh` | Noms composés, propriété `nom_compose` |
| `03-etape4-tunnels-peages-barrieres.sh` | Extrait les types 581, 45 et 607 |
| `03-etape6-filtrage-barrieres.sh` | Filtre les barrières sur la catégorie de voie |
| `03-etape30-hauteurs-no-fi.sh` | Profile le type 591 « Høydebegrensning » et la couche finlandaise |
| `03-etape31-conversion-hauteurs.sh` | Convertit et fusionne les hauteurs des trois pays |

**Pièges de la NVDB, constatés :** le WKT en srid 4326 donne **latitude puis longitude**,
il faut permuter. Le plafond de pagination est de **800 objets par page**, pas 1 000 ; on
suit le lien `neste`. Le type 581 (tunnels) **ne porte pas** la hauteur : elle est sur le
type 591, qui est un objet distinct.

---

## Finlande — Digiroad et SYKE

| Script | Ce qu'il fait |
|---|---|
| `03-etape5-extraction-conversion.sh` | Restrictions de dégel, couche `dr_kelirikko` |
| `03-etape30-hauteurs-no-fi.sh` | Couche `dr_max_korkeus` (voir Norvège) |
| `03-etape33-parcs-fi-no.sh` | Zones protégées d'État, GeoServer SYKE |
| `03-etape34-parcs-simplification.sh` | Première simplification, tolérance unique |
| `03-etape35-tolerance-adaptee.sh` | Tolérance proportionnelle à la taille |
| `03-etape36-contours-approches.sh` | Marquage des contours approchés |
| `03-etape37-marquage-corrige.sh` | Marquage corrigé : contour principal seul |

**Pièges :** le champ `arvo` des hauteurs est en **centimètres** ; une détection d'unité
fondée sur le maximum conclut à tort aux millimètres à cause d'une valeur isolée à 3 000.
**Se fonder sur la médiane.** Le filtrage du dégel se fait en local, l'API refusant un
filtre CQL sur un champ texte.

---

## Suède — Öppet API de Trafikverket

| Script | Ce qu'il fait |
|---|---|
| `03-etape19-trafikverket.sh` | Éprouve la clé, inventorie six types |
| `03-etape20-versions.sh` | Cherche les versions de schéma acceptées |
| `03-etape21-namespaces.sh` | Reprend avec l'attribut `namespace` |
| `03-etape22-situation.sh` | Inventorie les catégories de déviation |
| `03-etape23-vagdata.sh` | Reconnaissance de la base routière |
| `03-etape24-vagdata-extraction.sh` | Extraction filtrée : hauteurs, poids, largeurs, barrières, bacs, aires |
| `03-etape25-obstacles-conversion.sh` | Première conversion, pagination trop grossière |
| `03-etape26-obstacles-fin.sh` | Pagination fine par tranches d'identifiant |
| `03-etape27-identifiants.sh` | Identifiants composés, filtrage des obstacles |
| `03-etape28-identifiants-complets.sh` | Identifiants incluant la position sur le tronçon |
| `03-etape29-doublons.sh` | Départage les derniers doublons sur la distance |

**Pièges, et ils ont coûté cher :** l'élément `QUERY` exige **trois** attributs,
`objecttype`, `namespace` et `schemaversion`. L'omission du namespace fait répondre
« ObjectType does not exists » — littéralement vrai, et trompeur. **Le banc d'essai du
portail** (Data and API:s → API Open Data → Testbench) donne pour chaque type son
namespace et sa version exacts : c'est la seule référence fiable, la documentation tierce
ayant induit en erreur trois fois.

La base est à **positionnement linéaire** : l'identité d'une entité tient à `Feature_Oid`,
`Element_Id` **et** la position sur le tronçon. Trois passes ont été nécessaires pour
l'établir.

---

## OpenStreetMap — les trois pays

| Script | Ce qu'il fait |
|---|---|
| `03-etape7-services.sh` | Carburant, alimentation, alcool |
| `03-etape8-conversion-services.sh` | Conversion et normalisation des enseignes |
| `03-etape9-aires.sh` | Aires, vidange, campings, eau, laveries |
| `03-etape10-conversion-aires.sh` | Conversion, lecture des valeurs et non de la présence |
| `03-etape12-pois.sh` | Vingt-six types d'objets, six catégories |
| `03-etape13-conversion-pois.sh` | Filtrage et conversion |
| `03-etape14-decoupage-pois.sh` | Découpage en trois fichiers par usage |
| `03-etape15-se-fi.sh` | Ferries, tunnels, fermetures suédois et finlandais |
| `03-etape16-conversion-se-fi.sh` | Conversion et fusion avec les couches norvégiennes |
| `03-etape17-nettoyage.sh` | Doublons, regroupement des tronçons de tunnel |
| `03-etape18-hauteur.sh` | Franchissabilité des tunnels selon la hauteur du fourgon |

**Pièges :** Overpass plafonne à 20 000 objets par requête ; au-delà il faut paginer.
La table de normalisation des enseignes doit être **établie depuis le profil**, jamais de
mémoire. Sur les aires, lire la **valeur** de `sanitary_dump_station` et non sa présence :
elle vaut aussi `no` et `customers`.

---

## Autres

| Script | Ce qu'il fait |
|---|---|
| `03-etape11-blocs.sh` | Géocode un point d'ancrage par bloc d'itinéraire |
| `03-etape32-parcs.sh` | Éprouve douze adresses de services de zones protégées |

---

## Ce qui a échoué, et pourquoi

Consigné ici pour qu'une reprise ne recommence pas les mêmes tentatives.

**Contours de parcs par Overpass** — deux passes, deux échecs. La géométrie des relations
multipolygones ne revient pas, et le filtre de zone n'opère pas : des parcs norvégiens
apparaissaient dans le lot suédois. Abandonné au profit des portails nationaux.

**Zones protégées norvégiennes** — le service de Miljødirektoratet répond
« Could not access any server machines » sur les deux couches qui portent les zones,
alors que les autres couches du même service fonctionnent. Panne partielle et
persistante, constatée deux fois. Le repli examiné, la couche 3 `naturvern_grense`,
donne 27 735 lignes de limite **sans nom ni rattachement** : écarté.

**Zones protégées suédoises** — quatre adresses éprouvées, quatre refus. Leur GeoServer
répond « Service WFS is disabled ».

**Longueurs limitées suédoises** — extraites puis abandonnées : un seul objet sous 7 m sur
20 000, et 18 687 à 12 m, la limite des camions. Rien qui concerne un fourgon.

---

## Règle

**Tout développement nouveau se documente de la même façon** : un bandeau en tête du
script disant ce qu'il fait, d'où viennent les données, ce qui a été constaté et ce qui
reste incertain ; une entrée dans ce catalogue ; et, si le script produit une couche, une
rubrique au manifeste avec son protocole de vérification.

Ce qui n'est pas écrit est perdu.
