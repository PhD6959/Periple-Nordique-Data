#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 11 : BLOCS D'ITINÉRAIRE
# =============================================================================
#
# Source : doc-periple-nordique-2027-itineraire.html, version 3.19 du
# 9 septembre 2026. Document interne, pas de licence externe.
#
# Les seize blocs, leurs dates, leur contenu et leurs étapes sont repris du
# tableau du document. Il leur manque des coordonnées : la carte du document est
# en projection Lambert conforme conique, et l'inverser introduirait une erreur
# évitable. On géocode donc un point d'ancrage par bloc.
#
# LES POINTS D'ANCRAGE SONT UN CHOIX, PAS UNE DONNÉE. Ils sont listés en clair
# ci-dessous pour que tu puisses les corriger. Un bloc est une région traversée
# sur plusieurs jours ; le point marque son centre de gravité, pas son parcours.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape11-blocs.sh
# =============================================================================

set -u
OUT="_blocs"; mkdir -p "$OUT"

python3 - <<'PY'
import json, io, os, urllib.request, urllib.parse, time, datetime

AUJ = datetime.date.today().isoformat()
OUT = '_blocs'
rapport = []
def note(s):
    print(s); rapport.append(s)

# n, nom, dates, contenu, étape, ancrage, pays
BLOCS = [
 (1,  "Corridor d'accès", "15–18 avril · 4 jours",
  "Lyon → Allemagne → Danemark → Øresund. Transit assumé.", None, "Malmö", "SE"),
 (2,  "Suède du Sud", "19–25 avril · 7 jours",
  "Österlen, la côte de Scanie, le Glasriket dans les forêts du Småland.", "2.1 Österlen et Glasriket", "Simrishamn", "SE"),
 (3,  "Stockholm et son archipel", "26 avril – 2 mai · 7 jours",
  "La capitale, la vieille ville, puis l'archipel encore endormi.", "3.1 Stockholm", "Stockholm", "SE"),
 (4,  "La Dalécarlie", "3–7 mai · 5 jours",
  "Le lac, la mine de cuivre, la maison du peintre, le rouge de Falun.", "4.1 Dalécarlie", "Falun", "SE"),
 (5,  "La Höga Kusten", "8–14 mai · 7 jours",
  "Remontée par Sundsvall, puis la Haute Côte et son relèvement du sol.", "5.1 Höga Kusten", "Örnsköldsvik", "SE"),
 (6,  "Barreau E14 — d'est en ouest", "15–20 mai · 6 jours",
  "Östersund, le Jämtland, Åre, Storlien, et descente sur Trondheim.", "6.1 Jämtland et Åre", "Östersund", "SE"),
 (7,  "Kystriksveien — la côte de l'Helgeland", "21 mai – 1er juin · 12 jours",
  "630 km et six ferries de Steinkjer à Bodø : Torghatten, les Sept Sœurs.", "7.1 Kystriksveien", "Brønnøysund", "NO"),
 (8,  "Narvik et antenne de Laponie suédoise", "2–8 juin · 7 jours",
  "Remontée sur Narvik, puis aller-retour sur l'E10 vers Abisko.", "8.1 Laponie suédoise", "Narvik", "NO"),
 (9,  "Lofoten et Vesterålen", "9–19 juin · 11 jours",
  "Antenne depuis Narvik. Solstice : soleil de minuit au maximum.", "9.1 Lofoten", "Svolvær", "NO"),
 (10, "Senja et Tromsø", "20–28 juin · 9 jours",
  "La côte des grandes îles, puis le sas logistique avant le Finnmark.", "10.1 Senja et Tromsø", "Tromsø", "NO"),
 (11, "Alta et le Cap Nord", "29 juin – 3 juillet · 5 jours",
  "Gravures rupestres, canyon, plateau nu, falaise arctique.", "11.1 Alta et Cap Nord", "Alta", "NO"),
 (12, "Varanger et Hornøya", "4–13 juillet · 10 jours",
  "Le bloc que tout le calendrier sert : toundra, Ekkerøy, Vardø, Hornøya.", "12.1 Varanger", "Vardø", "NO"),
 (13, "Laponie finlandaise", "14 juillet – 2 août · 20 jours",
  "Bascule par Neiden ou Utsjoki : Inari, Lemmenjoki, l'Utsjoki.", "13.1 Inari", "Inari", "FI"),
 (14, "Finlande des forêts et des lacs", "3–30 août · 28 jours",
  "Oulanka et Kuusamo, Koli, le Saimaa et la région des lacs.", "14.1 Oulanka", "Kuusamo", "FI"),
 (15, "Finlande du Sud", "31 août – 20 septembre · 21 jours",
  "Archipel de Turku, Porvoo, Helsinki. Fin de la partie nordique.", "15.1 Turku et Helsinki", "Turku", "FI"),
 (16, "Corridor de retour", "21–30 septembre · 10 jours",
  "Ferry Helsinki–Tallinn, puis Via Baltica en corridor : Riga, Vilnius.", None, "Tallinn", "EE"),
]

PAYS = {'SE': 'se', 'NO': 'no', 'FI': 'fi', 'EE': 'ee'}

def geocoder(nom, iso):
    url = ('https://geocoding-api.open-meteo.com/v1/search?name=%s&count=5&language=fr&countryCode=%s'
           % (urllib.parse.quote(nom), iso))
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            d = json.loads(r.read().decode('utf-8'))
    except Exception as e:
        return None, 'échec : ' + str(e)[:60]
    res = d.get('results') or []
    # on garde le premier résultat du bon pays
    for x in res:
        if str(x.get('country_code', '')).upper() == iso:
            return (x['latitude'], x['longitude']), '%s, %s' % (x.get('name'), x.get('admin1') or x.get('country'))
    if res:
        x = res[0]
        return (x['latitude'], x['longitude']), 'PAYS DIFFÉRENT : %s (%s)' % (x.get('name'), x.get('country_code'))
    return None, 'aucun résultat'

feats, echecs = [], []
note('=== géocodage des points d\'ancrage ===')
for n, nom, dates, contenu, etape, ancrage, iso in BLOCS:
    coord, detail = geocoder(ancrage, iso)
    if not coord:
        echecs.append((n, ancrage, detail))
        note('  %2d %-38s %-16s ÉCHEC : %s' % (n, nom[:38], ancrage, detail))
        continue
    lat, lon = coord
    note('  %2d %-38s %-16s %.4f, %.4f — %s' % (n, nom[:38], ancrage, lat, lon, detail))
    p = {'id': 'bloc-%02d' % n, 'country': PAYS.get(iso, iso.lower()),
         'name': '%d · %s' % (n, nom), 'type': 'bloc',
         'source': 'interne', 'updated': AUJ,
         'numero': n, 'dates': dates, 'contenu': contenu,
         'etape': etape, 'ancrage': ancrage}
    feats.append({'type': 'Feature',
                  'geometry': {'type': 'Point', 'coordinates': [round(lon, 5), round(lat, 5)]},
                  'properties': {k: v for k, v in p.items() if v is not None}})
    time.sleep(1.2)   # le service de géocodage est public

json.dump({'type': 'FeatureCollection', 'features': feats},
          io.open(os.path.join(OUT, 'blocs-itineraire.geojson'), 'w', encoding='utf-8'), ensure_ascii=False)
note('')
note('-> blocs-itineraire.geojson : %d blocs sur 16, %d octets'
     % (len(feats), os.path.getsize(os.path.join(OUT, 'blocs-itineraire.geojson'))))
if echecs:
    note('ÉCHECS À REPRENDRE : %s' % ', '.join('%d %s' % (n, a) for n, a, _ in echecs))

# contrôle : les blocs doivent se suivre du sud au nord jusqu'au 12, puis redescendre
note('')
note('=== contrôle de cohérence géographique ===')
lat = {f['properties']['numero']: f['geometry']['coordinates'][1] for f in feats}
for n in sorted(lat):
    barre = '#' * int((lat[n] - 54) * 1.6)
    note('  %2d  %5.2f°N %s' % (n, lat[n], barre))

io.open(os.path.join(OUT, 'RAPPORT11.txt'), 'w', encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat _blocs/RAPPORT11.txt
echo "=========================================="
echo "À me transmettre : _blocs/RAPPORT11.txt"
