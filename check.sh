#!/usr/bin/env bash
# Mission 05 — mettre le détecteur de fraude en boîte.
# Il dit ce qui ne va pas, jamais comment le réparer.
set -uo pipefail

VERT=$'\033[32m'; ROUGE=$'\033[31m'; GRIS=$'\033[90m'; RAZ=$'\033[0m'
ECHECS=0

titre() { printf '\n%s%s%s\n' "$GRIS" "$1" "$RAZ"; }
ok()    { printf '%s✅%s %s\n' "$VERT" "$RAZ" "$1"; }
ko()    { printf '%s❌%s %s\n' "$ROUGE" "$RAZ" "$1"; ECHECS=$((ECHECS + 1)); }
info()  { printf '%s   %s%s\n' "$GRIS" "$1" "$RAZ"; }

# Le moteur répond-il ? Sans ce contrôle, chaque docker échoue pour la même
# raison et le script conclut « image introuvable » — un diagnostic faux.
moteur_pret() {
  if ! command -v docker >/dev/null 2>&1; then
    printf "\n%s❌%s la commande docker est introuvable sur ce poste.\n" "$ROUGE" "$RAZ"
    info "C'est la mission 00 qui installe Docker : commence par elle."
    return 1
  fi
  if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
    printf "\n%s❌%s docker est installé, mais son moteur ne répond pas.\n" "$ROUGE" "$RAZ"
    info "Démarre Docker Desktop (ou colima start), attends qu'il soit prêt, puis relance."
    return 1
  fi
  return 0
}
moteur_pret || exit 2

IMAGE="fraud-api:1.0"
DEPS='pandas|scikit-learn|joblib|fastapi|uvicorn'

# Un fichier encore troué : le ___ hors des lignes de commentaire.
reste_des_trous() { grep -vE '^\s*#' "$1" 2>/dev/null | grep -q '___'; }

# La taille de l'image, EN MÉGAOCTETS SUR DISQUE — celle que `docker images`
# affiche, donc celle que l'apprenant a sous les yeux.
# ⚠ Ne PAS utiliser `docker image inspect --format '{{.Size}}'` : depuis Docker
# 29, il renvoie le CONTENT SIZE (l'image compressée) là où `docker images`
# montre le DISK USAGE. Un check bâti sur inspect validerait le plafond sur un
# chiffre deux à cinq fois plus petit que celui qu'on demande de lire.
taille_mo() {
  local t n u; t="$(docker images --format '{{.Size}}' "$1" 2>/dev/null | head -1)"
  [ -z "$t" ] && return
  n="$(printf '%s' "$t" | sed -E 's/^([0-9.]+).*/\1/')"
  u="$(printf '%s' "$t" | sed -E 's/^[0-9.]+//' | tr -d ' ')"
  case "$u" in
    GB|GiB)    awk -v n="$n" 'BEGIN{printf "%d", n * 1000}' ;;
    kB|KB|KiB) awk -v n="$n" 'BEGIN{printf "%d", n / 1000}' ;;
    *)         awk -v n="$n" 'BEGIN{printf "%d", n}' ;;
  esac
}

# Le conteneur du service api, quel que soit le nom que Compose lui donne.
c_api() { docker compose ps -q api 2>/dev/null | head -1; }

# L'API répond-elle depuis l'extérieur ? Le guichet d'accueil est « / ».
repond() { curl -s -o /dev/null -w '%{http_code}' -m 5 localhost:8000/ 2>/dev/null; }

# ── étape 2 · les versions figées ────────────────────────────────────────────
etape_2() {
  titre "Étape 2 — les cinq dépendances, figées"
  if [ ! -f requirements.txt ]; then
    ko "requirements.txt a disparu du dossier"
    return
  fi
  if reste_des_trous requirements.txt; then
    ko "requirements.txt porte encore des ___"
    return
  fi
  local lignes; lignes="$(grep -vE '^\s*#|^\s*$' requirements.txt | wc -l | tr -d ' ')"
  [ "$lignes" = "5" ] && ok "cinq lignes, comme le projet en demande" \
                      || ko "$lignes ligne(s) au lieu de cinq"

  local manquant=""
  for p in pandas scikit-learn joblib fastapi uvicorn; do
    grep -qiE "^${p}([=<>[]|$)" requirements.txt || manquant="$manquant $p"
  done
  [ -z "$manquant" ] && ok "les cinq bibliothèques sont là" \
                     || ko "il manque :$manquant — sans elles l'image ne démarre pas"

  local libres; libres="$(grep -vE '^\s*#|^\s*$' requirements.txt | grep -cvE '==')"
  if [ "$libres" = "0" ]; then
    ok "toutes les versions sont figées"
  else
    ko "$libres ligne(s) sans version figée — l'image ne se reconstruira pas à l'identique"
  fi
}

# ── étape 3 · le Dockerfile construit ────────────────────────────────────────
etape_3() {
  titre "Étape 3 — l'image se construit"
  if reste_des_trous Dockerfile; then
    ko "le Dockerfile porte encore des ___"
    return
  fi
  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    ok "l'image $IMAGE existe"
  else
    ko "l'image $IMAGE est introuvable — construis-la avec le tag exact demandé"
    return
  fi
  local mo; mo="$(taille_mo "$IMAGE")"
  [ -n "$mo" ] && info "elle pèse $mo Mo (on y revient à l'étape 6)"

  # Le modèle DANS l'image : sans lui l'API démarre puis meurt au chargement.
  if docker run --rm --entrypoint sh "$IMAGE" -c 'ls model.pkl' >/dev/null 2>&1; then
    ok "model.pkl est dans l'image"
  else
    ko "model.pkl n'est pas dans l'image — l'API le charge au démarrage, elle ne le trouvera pas"
  fi
  if docker run --rm --entrypoint sh "$IMAGE" -c 'ls api.py' >/dev/null 2>&1; then
    ok "api.py est dans l'image"
  else
    ko "api.py n'est pas dans l'image"
  fi
}

# ── étape 4 · le contexte ────────────────────────────────────────────────────
etape_4() {
  titre "Étape 4 — ce qui n'entre jamais"
  if [ ! -f .dockerignore ]; then
    ko ".dockerignore n'existe pas"
    return
  fi
  if reste_des_trous .dockerignore; then
    ko ".dockerignore porte encore des ___"
    return
  fi
  local manquant=""
  grep -qE '^\s*(data/|data)'   .dockerignore || manquant="$manquant data/"
  grep -qE '^\s*\.git/?'        .dockerignore || manquant="$manquant .git/"
  grep -qE '^\s*\.?(venv)/?'    .dockerignore || manquant="$manquant .venv/"
  [ -z "$manquant" ] && ok "les familles attendues sont écartées" \
                     || ko "rien n'écarte :$manquant"

  if grep -qE '^\s*\*\*/__pycache__' .dockerignore; then
    ok "le cache de Python est filtré à tous les niveaux"
  else
    ko "__pycache__ n'est pas filtré récursivement — sans **/, seul celui de la racine tombe"
  fi

  # La preuve par l'image, et non par le fichier : le jeu de données ne doit
  # s'y trouver sous aucune forme.
  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    if docker run --rm --entrypoint sh "$IMAGE" -c 'ls data' >/dev/null 2>&1; then
      ko "data/ est dans l'image : le .dockerignore ne l'a pas arrêté (as-tu reconstruit ?)"
    else
      ok "le jeu de données n'a pas atterri dans l'image"
    fi
  fi
}

# ── étape 5 · elle répond depuis l'extérieur ─────────────────────────────────
etape_5() {
  titre "Étape 5 — elle répond depuis l'extérieur"
  local code; code="$(repond)"
  if [ "$code" != "200" ]; then
    ko "l'API ne répond pas sur localhost:8000 (code '$code')"
    local mort; mort="$(docker ps -a --filter status=exited --format '{{.Names}}' | head -1)"
    if [ -n "$mort" ]; then
      info "un conteneur s'est arrêté ($mort) : docker logs $mort dira pourquoi"
    fi
    # Le diagnostic qui vaut la mission : le service écoute-t-il « moi-même » ?
    if grep -qE 'CMD.*127\.0\.0\.1' Dockerfile 2>/dev/null; then
      info "ton CMD contient 127.0.0.1 — relis l'étape 5 du README"
    elif grep -qE 'CMD.*\[.*"python".*"api\.py"' Dockerfile 2>/dev/null; then
      info "ton CMD lance api.py, dont la dernière ligne choisit l'adresse d'écoute — relis-la"
    fi
    return
  fi
  ok "l'API répond depuis l'extérieur"

  curl -s -m 5 localhost:8000/ 2>/dev/null | grep -q '"model_loaded":true' \
    && ok "le modèle est chargé" \
    || ko "l'API répond mais le modèle n'est pas chargé"

  if [ ! -f fraud_example.json ] || [ ! -f normal_example.json ]; then
    ko "les deux transactions d'exemple ont disparu du dossier"
    return
  fi
  local f n
  f="$(curl -s -m 5 -X POST localhost:8000/predict -H 'Content-Type: application/json' \
       -d @fraud_example.json 2>/dev/null)"
  n="$(curl -s -m 5 -X POST localhost:8000/predict -H 'Content-Type: application/json' \
       -d @normal_example.json 2>/dev/null)"
  if printf '%s' "$f" | grep -q '"fraud":true'; then
    ok "la fraude est reconnue : $(printf '%s' "$f" | head -c 50)"
  else
    ko "la fraude n'est pas reconnue — réponse : $(printf '%s' "$f" | head -c 70)"
  fi
  if printf '%s' "$n" | grep -q '"fraud":false'; then
    ok "la transaction normale passe : $(printf '%s' "$n" | head -c 50)"
  else
    ko "la transaction normale est classée en fraude — réponse : $(printf '%s' "$n" | head -c 70)"
  fi
}

# ── étape 6 · les deux étages ────────────────────────────────────────────────
etape_6() {
  titre "Étape 6 — la construction à deux étages"
  local n_from; n_from="$(grep -cE '^\s*FROM ' Dockerfile 2>/dev/null)"
  if [ "$n_from" -ge 2 ]; then
    ok "le Dockerfile a $n_from étages"
  else
    ko "un seul FROM : le Dockerfile n'a pas d'étage atelier"
    return
  fi
  grep -qE '^\s*COPY\s+--from=' Dockerfile \
    && ok "l'image finale récupère le résultat de l'atelier" \
    || ko "aucun COPY --from= : le second étage n'emporte rien du premier"

  # pip ne doit s'exécuter QUE dans le premier étage.
  if awk '/^\s*FROM /{n++} n>1 && /pip install/{trouve=1} END{exit !trouve}' Dockerfile; then
    ko "pip s'exécute encore dans l'image livrée — l'atelier n'a pas été isolé"
  else
    ok "pip ne tourne que dans l'atelier"
  fi
  local mo; mo="$(taille_mo "$IMAGE")"
  [ -n "$mo" ] && info "$IMAGE pèse $mo Mo — compare avec l'image d'avant (docker images fraud-api)"
}

# ── étape 7 · une seule commande ─────────────────────────────────────────────
etape_7() {
  titre "Étape 7 — une seule commande"
  if [ ! -f docker-compose.yml ]; then
    ko "docker-compose.yml a disparu du dossier"
    return
  fi
  if reste_des_trous docker-compose.yml; then
    ko "docker-compose.yml porte encore des ___"
    return
  fi
  if [ -z "$(c_api)" ]; then
    ko "aucun service api ne tourne — lance : docker compose up -d --build"
    return
  fi
  ok "le service api tourne, levé par Compose"
  [ "$(repond)" = "200" ] && ok "et il répond sur localhost:8000" \
                          || ko "le service tourne mais ne répond pas — le port est-il publié ?"

  # Sans état : le détruire et le relancer doit rendre le même service.
  printf '\n%sLa suite DÉTRUIT puis relance ton service (docker compose down, puis up).%s\n' "$GRIS" "$RAZ"
  printf 'Continuer ? [o/N] '
  read -r reponse
  case "$reponse" in o|O|y|Y) ;; *) printf "Interrompu, rien n'a été touché.\n"; return ;; esac
  docker compose down >/dev/null 2>&1
  docker compose up -d >/dev/null 2>&1
  local i
  for i in $(seq 1 30); do [ "$(repond)" = "200" ] && break; sleep 1; done
  [ "$(repond)" = "200" ] && ok "détruit puis relancé, le service est identique" \
                          || ko "le service n'est pas revenu — docker compose logs api"
}

# ── la relecture finale · les sept critères ──────────────────────────────────
mission() {
  titre "Ça marche"
  if [ -z "$(c_api)" ]; then
    ko "01 · aucun service api ne tourne — une seule commande doit suffire : docker compose up -d"
    info "les critères 02 à 07 ont besoin du service levé"
    return
  fi
  ok "01 · une seule commande met le système debout"

  local code; code="$(repond)"
  if [ "$code" = "200" ] && curl -s -m 5 localhost:8000/ | grep -q '"model_loaded":true'; then
    ok "02 · l'API répond depuis l'extérieur, modèle chargé"
  else
    ko "02 · l'API ne répond pas depuis l'extérieur (code '$code')"
  fi

  local f n
  f="$(curl -s -m 5 -X POST localhost:8000/predict -H 'Content-Type: application/json' \
       -d @fraud_example.json 2>/dev/null)"
  n="$(curl -s -m 5 -X POST localhost:8000/predict -H 'Content-Type: application/json' \
       -d @normal_example.json 2>/dev/null)"
  if printf '%s' "$f" | grep -q '"fraud":true' && printf '%s' "$n" | grep -q '"fraud":false'; then
    ok "03 · la prédiction distingue la fraude de la transaction normale"
  else
    ko "03 · la prédiction ne distingue pas les deux exemples"
  fi

  titre "C'est propre"
  local libres; libres="$(grep -vE '^\s*#|^\s*$' requirements.txt 2>/dev/null | grep -cvE '==')"
  [ "$libres" = "0" ] && ok "04 · toutes les dépendances sont figées" \
                      || ko "04 · $libres dépendance(s) sans version figée"

  local qui; qui="$(docker compose exec -T api whoami 2>/dev/null | tr -d '\r\n')"
  if [ -n "$qui" ] && [ "$qui" != "root" ]; then
    ok "05 · le programme tourne en '$qui', pas en administrateur"
  elif [ "$qui" = "root" ]; then
    ko "05 · le programme tourne en root : qui sort du conteneur hérite de root"
  else
    ko "05 · impossible de lire l'utilisateur du conteneur"
  fi

  local image; image="$(docker compose config --images 2>/dev/null | head -1)"
  [ -z "$image" ] && image="$IMAGE"
  if docker image inspect "$image" >/dev/null 2>&1; then
    if docker run --rm --entrypoint sh "$image" -c 'ls data' >/dev/null 2>&1; then
      ko "06 · le jeu de données est dans l'image"
    else
      ok "06 · le jeu de données n'est pas dans l'image"
    fi
    local mo; mo="$(taille_mo "$image")"
    if [ -n "$mo" ] && [ "$mo" -gt 0 ] 2>/dev/null; then
      [ "$mo" -lt 900 ] && ok "07 · l'image pèse $mo Mo, sous le plafond de 900" \
                        || ko "07 · l'image pèse $mo Mo, au-dessus du plafond de 900 — repasse l'étape 6"
    else
      ko "07 · taille de l'image illisible"
    fi
  else
    ko "06 et 07 · image du service api introuvable"
  fi
}

CIBLE="${1:-all}"
case "$CIBLE" in
  2) etape_2 ;;
  3) etape_3 ;;
  4) etape_4 ;;
  5) etape_5 ;;
  6) etape_6 ;;
  7) etape_7 ;;
  all) mission ;;
  *) echo "usage: ./check.sh [2|3|4|5|6|7|all]"; exit 2 ;;
esac

printf '\n'
if [ "$ECHECS" -eq 0 ]; then
  printf '%s✅ tout est vert.%s\n' "$VERT" "$RAZ"
  exit 0
fi
printf '%s❌ %d point(s) à reprendre.%s\n' "$ROUGE" "$ECHECS" "$RAZ"
exit 1
