#!/bin/bash
# =============================================================================
# Périple nordique 2027 — Module 3
# ÉTAPE 5 : EXTRACTION COMPLÈTE ET CONVERSION — tunnels, péages, barrières
# =============================================================================
#
# PAGINATION CORRIGÉE POUR DE BON : l'API plafonne les pages à 800 objets,
# pas 1000. Ma condition d'arrêt comparait le nombre reçu à la taille demandée,
# et coupait donc dès la première page. On suit désormais uniquement le lien
# « neste », et on ne s'arrête que lorsqu'il n'y en a plus.
#
# PRODUIT dans _out5/ :
#   tunnels.geojson              filtré (voir critères ci-dessous)
#   peages.geojson               les 463 stations, avec tarifs
#   barrieres.geojson            les barrières, avec la catégorie de voie
#
# UTILISATION
#   bash 03-etape5-extraction-conversion.sh
# =============================================================================

set -u
OUT="_out5"; mkdir -p "$OUT"
CLIENT="PeripleNordique2027"
BASE="https://nvdbapiles.atlas.vegvesen.no/vegobjekter/api/v4/vegobjekter"

extraire () {
  local ID="$1" SLUG="$2" FIC="$OUT/no-$2.json"
  echo "== NVDB $ID =="
  local URL="$BASE/$ID?antall=1000&srid=4326&inkluder=metadata,egenskaper,geometri,lokasjon&inkluderAntall=true"
  local PAGE=0 TOTAL=0
  : > "$OUT/tmp-$SLUG.ndjson"
  while [ -n "$URL" ] && [ "$PAGE" -lt 120 ]; do
    curl -sS -H "Accept: application/json" -H "X-Client: $CLIENT" "$URL" -o "$OUT/tmp-page.json"
    local INFO
    INFO=$(python3 -c "
import json,io
try:
    d=json.load(io.open('$OUT/tmp-page.json',encoding='utf-8'))
except Exception as e:
    print('0||ERREUR'); raise SystemExit
r=d.get('objekter', d.get('vegobjekter', []))
m=d.get('metadata',{}) or {}
suiv=(m.get('neste') or {}).get('href','') if r else ''
with io.open('$OUT/tmp-$SLUG.ndjson','a',encoding='utf-8') as f:
    for o in r: f.write(json.dumps(o,ensure_ascii=False)+'\n')
print('%d|%s|%s' % (len(r), suiv, m.get('antall','?')))")
    local N=${INFO%%|*}; local R=${INFO#*|}; local SUIV=${R%%|*}; local ANN=${R##*|}
    [ "$PAGE" -eq 0 ] && echo "   annoncés : $ANN"
    TOTAL=$((TOTAL+N)); PAGE=$((PAGE+1))
    [ "$N" -eq 0 ] && break
    [ -z "$SUIV" ] && break          # seule condition d'arrêt : plus de page suivante
    URL="$SUIV"
  done
  echo "   récupérés : $TOTAL en $PAGE page(s)"
  python3 -c "
import json,io
o=[json.loads(l) for l in io.open('$OUT/tmp-$SLUG.ndjson',encoding='utf-8') if l.strip()]
json.dump(o, io.open('$FIC','w',encoding='utf-8'), ensure_ascii=False)
print('   ->', len(o), 'objets')"
  rm -f "$OUT/tmp-page.json" "$OUT/tmp-$SLUG.ndjson"
}

extraire 581 "581-tunnel"
extraire 45  "45-bomstasjon"
extraire 607 "607-vegsperring"

python3 - <<'PY'
import json, io, os, collections, datetime
OUT='_out5'; AUJ=datetime.date.today().isoformat(); rapport=[]
def note(s):
    print(s); rapport.append(s)

def wkt(w):
    if not w: return None
    t=w.split('(')[0].strip().upper().replace(' Z','')
    if t!='POINT': return None
    v=w[w.find('(')+1:w.find(')')].split()
    if len(v)<2: return None
    lat,lon=float(v[0]),float(v[1])          # NVDB : latitude puis longitude
    if not (2<=lon<=34 and 53<=lat<=73): return None
    return {'type':'Point','coordinates':[round(lon,5),round(lat,5)]}

def eg(o): return {e.get('navn'):e.get('verdi') for e in (o.get('egenskaper') or [])}
def loc(o): return o.get('lokasjon') or {}
def route(o):
    for v in (loc(o).get('vegsystemreferanser') or []):
        vs=v.get('vegsystem') or {}
        if vs.get('nummer'): return str(vs.get('vegkategori','')) + str(vs['nummer'])
    return None
def categorie(o):
    for v in (loc(o).get('vegsystemreferanser') or []):
        vs=v.get('vegsystem') or {}
        if vs.get('vegkategori'): return vs['vegkategori']
    return None
def kommune(o):
    k=loc(o).get('kommuner') or []
    return k[0] if k else None

CAT={'E':'europaveg','R':'riksveg','F':'fylkesveg','K':'kommunal','P':'privat','S':'skogsveg'}

def lire(n):
    p=os.path.join(OUT,n)
    return json.load(io.open(p,encoding='utf-8')) if os.path.exists(p) else []

# ------------------------------------------------------------------ TUNNELS
note('=== tunnels ===')
objets=lire('no-581-tunnel.json'); feats=[]; motifs=collections.Counter()
for o in objets:
    p=eg(o)
    lg=p.get('Lengde, offisiell') or p.get('Sum lengde alle løp') or 0
    try: lg=int(lg)
    except (TypeError,ValueError): lg=0
    sous=p.get('Undersjøisk')=='Ja'
    dg=p.get('Restriksjoner farlig gods')=='Ja'
    long3=lg>=3000
    if not (sous or dg or long3): continue
    g=wkt((o.get('geometri') or {}).get('wkt'))
    if not g: continue
    m=[]
    if sous: m.append('sous-marin')
    if long3: m.append('long')
    if dg: m.append('marchandises dangereuses')
    for x in m: motifs[x]+=1
    feats.append({'type':'Feature','geometry':g,'properties':{
        'id':'no-tunnel-%s'%o.get('id'),'country':'no','name':p.get('Navn') or 'sans nom',
        'type':'tunnel','source':'NVDB','updated':AUJ,
        'route':route(o),'kommune':kommune(o),
        'longueur_m':lg or None,'sous_marin':sous,
        'restriction_marchandises_dangereuses':dg,
        'note_marchandises':p.get('Merknad restriksjoner farlig gods'),
        'velo_interdit':p.get('Sykkelforbud')=='Ja',
        'annee':p.get('Åpningsår'),'motifs':', '.join(m)}})
note('  tunnels au total : %d | retenus : %d' % (len(objets), len(feats)))
note('  motifs : %s' % dict(motifs))
json.dump({'type':'FeatureCollection','features':feats},
          io.open(os.path.join(OUT,'tunnels.geojson'),'w',encoding='utf-8'),ensure_ascii=False)

# ------------------------------------------------------------------ PÉAGES
note('')
note('=== péages ===')
objets=lire('no-45-bomstasjon.json'); feats=[]
for o in objets:
    p=eg(o); g=wkt((o.get('geometri') or {}).get('wkt'))
    if not g: continue
    feats.append({'type':'Feature','geometry':g,'properties':{
        'id':'no-peage-%s'%o.get('id'),'country':'no',
        'name':p.get('Navn bomstasjon') or p.get('Navn bompengeanlegg') or 'sans nom',
        'type':'peage','source':'NVDB','updated':AUJ,
        'route':route(o),'kommune':kommune(o),
        'categorie_station':p.get('Bomstasjonstype'),
        'exploitant':p.get('Navn bompengeanlegg'),'lien':p.get('Lenke til bomstasjon'),
        'tarif_petit_vehicule':p.get('Takst liten bil'),
        'tarif_gros_vehicule':p.get('Takst stor bil'),
        'tarif_pointe_petit':p.get('Rushtidstakst liten bil'),
        'pointe_matin':'%s-%s'%(p.get('Rushtid morgen, fra'),p.get('Rushtid morgen, til')) if p.get('Rushtid morgen, fra') else None,
        'pointe_soir':'%s-%s'%(p.get('Rushtid ettermiddag, fra'),p.get('Rushtid ettermiddag, til')) if p.get('Rushtid ettermiddag, fra') else None,
        'sens':p.get('Innkrevningsretning'),
        'regle_horaire':p.get('Timesregel'),'regle_horaire_min':p.get('Timesregel, varighet')}})
note('  stations : %d' % len(feats))
note('  types : %s' % dict(collections.Counter(f['properties']['categorie_station'] for f in feats)))
t=[f['properties']['tarif_petit_vehicule'] for f in feats if f['properties']['tarif_petit_vehicule']]
if t: note('  tarif petit véhicule : min %.0f, médian %.0f, max %.0f NOK' % (min(t), sorted(t)[len(t)//2], max(t)))
json.dump({'type':'FeatureCollection','features':feats},
          io.open(os.path.join(OUT,'peages.geojson'),'w',encoding='utf-8'),ensure_ascii=False)

# ------------------------------------------------------------------ BARRIÈRES
note('')
note('=== barrières ===')
objets=lire('no-607-vegsperring.json'); feats=[]
for o in objets:
    p=eg(o); g=wkt((o.get('geometri') or {}).get('wkt'))
    if not g: continue
    cat=categorie(o)
    feats.append({'type':'Feature','geometry':g,'properties':{
        'id':'no-barriere-%s'%o.get('id'),'country':'no',
        'name':p.get('Type') or p.get('Funksjon') or 'barrière','type':'barriere',
        'source':'NVDB','updated':AUJ,
        'route':route(o),'kommune':kommune(o),
        'categorie_voie':CAT.get(cat, cat),'fonction':p.get('Funksjon'),
        'modele':p.get('Type'),'remarque':p.get('Merknad')}})
note('  barrières : %d' % len(feats))
note('  par catégorie de voie : %s' % dict(collections.Counter(f['properties']['categorie_voie'] for f in feats)))
note('  par fonction : %s' % dict(collections.Counter(f['properties']['fonction'] for f in feats).most_common(8)))
json.dump({'type':'FeatureCollection','features':feats},
          io.open(os.path.join(OUT,'barrieres.geojson'),'w',encoding='utf-8'),ensure_ascii=False)

note('')
note('=== tailles ===')
for n in ('tunnels.geojson','peages.geojson','barrieres.geojson'):
    c=os.path.join(OUT,n)
    if os.path.exists(c): note('  %-22s %5d Ko' % (n, os.path.getsize(c)//1024))

note('')
note('=== échantillons ===')
for n in ('tunnels.geojson','peages.geojson','barrieres.geojson'):
    d=json.load(io.open(os.path.join(OUT,n),encoding='utf-8'))
    if d['features']:
        note('  ' + json.dumps(d['features'][0]['properties'], ensure_ascii=False)[:520])

io.open(os.path.join(OUT,'RAPPORT5.txt'),'w',encoding='utf-8').write('\n'.join(rapport))
PY

echo
echo "=========================================="
cat "$OUT/RAPPORT5.txt"
echo "=========================================="
echo "À me transmettre : $OUT/RAPPORT5.txt"
