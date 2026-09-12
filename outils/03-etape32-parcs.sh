#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 32 : SERVICES DE ZONES PROTÉGÉES — RECONNAISSANCE
# =============================================================================
#
# Deux tentatives par Overpass ont échoué à récupérer les contours de parcs
# nationaux. On passe par les portails nationaux, comme prévu au manifeste.
#
# CE QUI EST ÉTABLI
#   FINLANDE  SYKE publie ses données par un GeoServer dont le motif d'adresse
#             est connu : paikkatiedot.ymparisto.fi/geoserver/<espace>/wfs.
#             Coordonnées en ETRS-TM35FIN.
#   NORVÈGE   Miljødirektoratet publie un service « vern » contenant les zones
#             protégées, mais je n'ai pas son adresse de rajapinta.
#   SUÈDE     Naturvårdsverket annonce des services ouverts WMS, WFS et REST
#             sur le registre de protection de la nature. Le GeoServer que
#             j'avais repéré répond « Service WFS is disabled » : ce n'est pas
#             la bonne porte.
#
# CE SCRIPT NE DEVINE PAS : il éprouve une dizaine d'adresses plausibles et
# rend compte de celles qui répondent, avec les couches qu'elles exposent.
# Une adresse qui échoue n'est pas une conclusion, seulement une piste fermée.
#
# UTILISATION — depuis le dossier de travail
#   bash 03-etape32-parcs.sh
# =============================================================================

set -u
OUT="_parcs"; mkdir -p "$OUT"

sonder () {
  local NOM="$1" URL="$2" FIC="$OUT/$1.xml"
  printf '  %-38s ' "$NOM"
  local CODE
  CODE=$(curl -sS -m 45 -o "$FIC" -w '%{http_code}' "$URL" 2>/dev/null || echo '000')
  if [ "$CODE" != "200" ]; then
    echo "http $CODE"
    rm -f "$FIC"; return 1
  fi
  python3 - "$FIC" "$NOM" <<'PY'
import sys, re, io
fic, nom = sys.argv[1], sys.argv[2]
s = io.open(fic, encoding='utf-8', errors='replace').read()
if 'ServiceException' in s or 'is disabled' in s:
    m = re.search(r'>([^<]{5,90})<', s)
    print('refusé — %s' % (m.group(1).strip() if m else 'service indisponible')); raise SystemExit
if s.lstrip().startswith('{'):
    print('réponse JSON, %d octets' % len(s)); raise SystemExit
noms = re.findall(r'<(?:wfs:)?Name>([^<]+)</(?:wfs:)?Name>', s)
titres = re.findall(r'<(?:wfs:)?Title>([^<]+)</(?:wfs:)?Title>', s)
if not noms:
    print('réponse sans couches, %d octets' % len(s)); raise SystemExit
motifs = ('park', 'vern', 'suojelu', 'nationalpark', 'kansallispuisto', 'skydd', 'naturreservat')
inter = [(n, t) for n, t in zip(noms, titres) if any(m in (n + ' ' + t).lower() for m in motifs)]
print('%d couche(s), dont %d en rapport' % (len(noms), len(inter)))
for n, t in inter[:8]:
    print('      %-46s %s' % (n[:46], t[:50]))
PY
}

echo "=== FINLANDE — SYKE ==="
sonder fi-suojelualueet "https://paikkatiedot.ymparisto.fi/geoserver/suojelualueet/wfs?request=GetCapabilities&service=WFS&version=2.0.0"
sonder fi-muusuojelu    "https://paikkatiedot.ymparisto.fi/geoserver/muusuojelu/wfs?request=GetCapabilities&service=WFS&version=2.0.0"
sonder fi-inspire-ps    "https://paikkatiedot.ymparisto.fi/geoserver/inspire_ps/wfs?request=GetCapabilities&service=WFS&version=2.0.0"
sonder fi-global        "https://paikkatiedot.ymparisto.fi/geoserver/wfs?request=GetCapabilities&service=WFS&version=2.0.0"

echo
echo "=== NORVÈGE — Miljødirektoratet et Geonorge ==="
sonder no-geonorge-vern "https://wfs.geonorge.no/skwms1/wfs.vern?request=GetCapabilities&service=WFS&version=2.0.0"
sonder no-mdir-vern     "https://kart.miljodirektoratet.no/arcgis/services/vern/MapServer/WFSServer?request=GetCapabilities&service=WFS"
sonder no-mdir-rest     "https://kart.miljodirektoratet.no/arcgis/rest/services/vern/MapServer?f=json"
sonder no-geonorge-nat  "https://wfs.geonorge.no/skwms1/wfs.naturvernomrader?request=GetCapabilities&service=WFS&version=2.0.0"

echo
echo "=== SUÈDE — Naturvårdsverket ==="
sonder se-geodata-ows   "https://geodata.naturvardsverket.se/geoserver/ows?request=GetCapabilities&service=WFS&version=2.0.0"
sonder se-inspire       "https://geodata.naturvardsverket.se/inspire/wfs?request=GetCapabilities&service=WFS&version=2.0.0"
sonder se-arcgis        "https://geodata.naturvardsverket.se/arcgis/rest/services?f=json"
sonder se-skyddadnatur  "https://skyddadnatur.naturvardsverket.se/arcgis/rest/services?f=json"

echo
echo "=========================================="
echo "Fichiers conservés dans $OUT/ pour les services ayant répondu :"
ls -la "$OUT" 2>/dev/null | awk 'NR>3 {printf "  %8s  %s\n", $5, $9}'
echo
echo "Me transmettre la sortie ci-dessus."
