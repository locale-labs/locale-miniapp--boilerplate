#!/usr/bin/env bash
#
# sync-branch.sh — promové (y/o sincronizá) dev↔main de ESTE repo.
#
# Versión single-repo del sync-branches.sh del workspace: opera sobre el repo
# donde vive el script (git toplevel), no recorre el workspace. Pensado para
# correrlo cómodo desde la raíz de cada mini-app.
#
# Compara dev vs main contra el remoto:
#   - ahead  (main..dev) → hay trabajo en dev sin promover a prod
#   - behind (dev..main) → main tiene commits que dev no (ej: commit de release)
#
# Modos:
#   ./scripts/sync-branch.sh            # solo reporte (read-only)
#   ./scripts/sync-branch.sh --deploy   # reporte + ejecuta los pasos (interactivo)
#
# Flags:
#   --no-fetch   no hace git fetch (usa el estado local cacheado)
#   --auto|-a    muestra el audit y pregunta UNA sola vez; si confirmás, corre
#                todos los pasos sin volver a preguntar
#   --yes|-y     no pregunta confirmación antes de cada acción (PELIGROSO)
#   -h|--help    esta ayuda
#
# Pasos (los nombres, no números de versión — el bump de semver lo hace
# semantic-release solo al mergear a main):
#   ahead>0           → PR dev→main → merge (dispara release) → esperar action
#                       → sincronizar dev←main
#   ahead==0,behind>0 → solo sincronizar dev←main
#
# Pasos que tocan el remoto (push / merge de PR) preguntan [Y/n] (default Y)
# salvo --yes. Con --auto se confirma una vez y corre todo solo.

set -uo pipefail

# ── paths / colores ──────────────────────────────────────────────────────────
REPO_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "✗ no estás dentro de un repo git" >&2; exit 1; }
NAME="$(basename "$REPO_DIR")"

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
  YEL=$'\033[33m'; BLU=$'\033[34m'; CYN=$'\033[36m'; RST=$'\033[0m'
else
  BOLD=; DIM=; RED=; GRN=; YEL=; BLU=; CYN=; RST=
fi

# ── args ─────────────────────────────────────────────────────────────────────
DO_DEPLOY=0
DO_FETCH=1
ASSUME_YES=0
AUTO_AFTER_AUDIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deploy)   DO_DEPLOY=1 ;;
    --no-fetch) DO_FETCH=0 ;;
    --auto|-a)  AUTO_AFTER_AUDIT=1; DO_DEPLOY=1 ;;
    --yes|-y)   ASSUME_YES=1 ;;
    -h|--help)
      sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) echo "${RED}flag desconocida: $1${RST}" >&2; exit 2 ;;
    *)  echo "${RED}argumento inesperado: $1${RST}" >&2; exit 2 ;;
  esac
  shift
done

# ── helpers ──────────────────────────────────────────────────────────────────
die() { echo "${RED}✗ $*${RST}" >&2; exit 1; }

confirm() {
  # confirm "<pregunta>" → 0 si sí, 1 si no
  [[ $ASSUME_YES -eq 1 ]] && return 0
  local ans
  # drenar input pendiente: `gh run watch`/`gh pr merge` dejan bytes
  # buffereados en la tty que sino se comen este prompt.
  read -r -t 0.1 -N 100000 _ </dev/tty 2>/dev/null || true
  read -r -p "${YEL}? $1 [Y/n] ${RST}" ans </dev/tty
  # default Y: vacío (Enter) o y/Y → sí; solo n/N → no
  [[ "$ans" != "n" && "$ans" != "N" ]]
}

# git en este repo sin cd
g() { git -C "$REPO_DIR" "$@"; }

# slug del remoto (ej: locale-labs/locale-miniapp--mascotas-perdidas)
remote_slug() {
  g remote get-url origin 2>/dev/null \
    | sed -E 's#(git@github.com:|https://github.com/)##; s/\.git$//'
}

# workflow que corre al mergear a main
main_workflow() {
  if [[ -f "$REPO_DIR/.github/workflows/release.yml" ]]; then
    echo "release.yml"
  else
    echo "publish.yml"
  fi
}

require_clean_tree() {
  [[ -z "$(g status --porcelain)" ]] || die "working tree sucio, commitea/stashea primero"
}

# ── deploy ─────────────────────────────────────────────────────────────────--
# usa globals: REPO_DIR NAME AHEAD BEHIND SLUG WF
deploy_repo() {
  local cur_branch
  cur_branch="$(g rev-parse --abbrev-ref HEAD)"

  require_clean_tree

  # local dev debe estar al día con origin/dev (sino el PR no incluye tu trabajo)
  local local_dev remote_dev
  local_dev="$(g rev-parse refs/heads/dev 2>/dev/null || echo none)"
  remote_dev="$(g rev-parse refs/remotes/origin/dev)"
  if [[ "$local_dev" != "none" && "$local_dev" != "$remote_dev" ]]; then
    local unpushed
    unpushed="$(g rev-list --count origin/dev..dev 2>/dev/null || echo '?')"
    if [[ "$unpushed" != "0" && "$unpushed" != "?" ]]; then
      echo "${YEL}  ⚠ dev local tiene $unpushed commit(s) sin pushear.${RST}"
      if confirm "pushear dev a origin antes de promover?"; then
        g checkout dev >/dev/null 2>&1 || die "no pude checkout dev"
        g push origin dev || die "push dev falló"
      else
        die "abortado: dev local desincronizado con origin"
      fi
    fi
  fi

  if [[ $AHEAD -gt 0 ]]; then
    # ── PROMOVER: abrir PR dev → main ────────────────────────────────────────
    echo "${BOLD}  → promover dev→main (${AHEAD} commit(s) ahead)${RST}"

    local pr_num
    pr_num="$(gh pr list --repo "$SLUG" --base main --head dev --state open \
                --json number --jq '.[0].number' 2>/dev/null)"
    if [[ -n "$pr_num" ]]; then
      echo "${DIM}    PR #$pr_num ya abierto, reuso${RST}"
    else
      if confirm "crear PR dev→main en $SLUG?"; then
        local title="release: promote dev → main ($(date +%Y-%m-%d))"
        pr_num="$(gh pr create --repo "$SLUG" --base main --head dev \
                    --title "$title" --body "Promote dev → main. Auto-generated by sync-branch.sh." \
                    2>&1 | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | tail -1)"
        [[ -n "$pr_num" ]] || die "no pude crear/parsear el PR"
        echo "${GRN}    PR #$pr_num creado${RST}"
      else
        echo "${DIM}    skip${RST}"; return 0
      fi
    fi

    if confirm "MERGEAR PR #$pr_num (--merge, dispara release/deploy)?"; then
      gh pr merge "$pr_num" --repo "$SLUG" --merge || die "merge del PR falló"
      echo "${GRN}    PR #$pr_num mergeado${RST}"
    else
      echo "${DIM}    skip merge${RST}"; return 0
    fi

    # ── ESPERAR: la action de release disparada por el merge ─────────────────
    echo "${BOLD}  → esperando action de release (${WF}) en ${SLUG}…${RST}"
    sleep 5
    local run_id
    run_id="$(gh run list --repo "$SLUG" --workflow "$WF" --branch main \
                --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null)"
    if [[ -n "$run_id" ]]; then
      gh run watch --repo "$SLUG" --exit-status "$run_id" \
        || die "la action falló (run $run_id). Revisá: gh run view $run_id --repo $SLUG --log-failed"
      echo "${GRN}    action OK${RST}"
    else
      echo "${YEL}    ⚠ no encontré run reciente; revisá manualmente las actions${RST}"
    fi
  else
    echo "${BOLD}  → solo behind (${BEHIND}); sin promover, voy directo a sincronizar${RST}"
  fi

  # ── SINCRONIZAR: traer dev←main (incluye el chore(release) con el bump) ────
  echo "${BOLD}  → sincronizar dev←main${RST}"
  if confirm "sincronizar dev←main y pushear dev?"; then
    g fetch origin main dev || die "fetch falló"
    g checkout main || die "checkout main falló"
    g merge --ff-only origin/main || die "main no ff-only a origin/main (divergió?)"
    g checkout dev || die "checkout dev falló"
    g merge --ff-only origin/dev || die "dev no ff-only a origin/dev (commits locales sin pushear?)"
    g merge main || die "merge main→dev con conflictos; resolvé a mano"
    g push origin dev || die "push dev falló"
    echo "${GRN}    dev sincronizado y pusheado${RST}"
  else
    echo "${DIM}    skip sync${RST}"
  fi

  # restaurar branch original si existe todavía
  g rev-parse --verify "$cur_branch" >/dev/null 2>&1 && g checkout "$cur_branch" >/dev/null 2>&1
}

# ── main ─────────────────────────────────────────────────────────────────────
command -v git >/dev/null || die "git no encontrado"

g show-ref --verify --quiet refs/remotes/origin/dev \
  || die "este repo no tiene origin/dev (¿ya scaffoldeaste la mini-app?)"
g show-ref --verify --quiet refs/remotes/origin/main \
  || die "este repo no tiene origin/main"

if [[ $DO_DEPLOY -eq 1 ]]; then
  command -v gh >/dev/null || die "gh CLI no encontrado (necesario para --deploy)"
  gh auth status >/dev/null 2>&1 || die "gh no autenticado: corré 'gh auth login'"
fi

echo "${BOLD}${CYN}Branch sync${RST}  ${DIM}(${NAME})${RST}"
echo

if [[ $DO_FETCH -eq 1 ]]; then
  echo "${DIM}fetching…${RST}"
  g fetch --quiet --prune origin 2>/dev/null
fi

AHEAD="$(g rev-list --count origin/main..origin/dev 2>/dev/null || echo 0)"
BEHIND="$(g rev-list --count origin/dev..origin/main 2>/dev/null || echo 0)"

state="" ; action="" ; color="$GRN" ; need=0
if [[ "$AHEAD" -eq 0 && "$BEHIND" -eq 0 ]]; then
  state="✓ in-sync" ; action="—"
elif [[ "$AHEAD" -gt 0 ]]; then
  state="↑ ahead"   ; action="promote: PR→merge→sync" ; color="$YEL" ; need=1
else
  state="↓ behind"  ; action="sync: dev←main" ; color="$BLU" ; need=1
fi
[[ "$AHEAD" -gt 0 && "$BEHIND" -gt 0 ]] && state="⇅ diverged"

printf "${BOLD}%-6s %-6s  %-10s %s${RST}\n" "ahead" "behind" "estado" "acción"
printf '%s\n' "$(printf '─%.0s' {1..48})"
printf "${color}%-6s %-6s  %-10s${RST} %s\n" "$AHEAD" "$BEHIND" "$state" "$action"
echo

if [[ $need -eq 0 ]]; then
  echo "${GRN}${BOLD}Todo en sync. Nada que hacer.${RST}"
  exit 0
fi

if [[ $DO_DEPLOY -eq 0 ]]; then
  echo "${DIM}Correr con --deploy para ejecutar los pasos (interactivo).${RST}"
  exit 0
fi

# --auto: una sola confirmación tras ver el audit; luego no pregunta más.
if [[ $AUTO_AFTER_AUDIT -eq 1 && $ASSUME_YES -eq 0 ]]; then
  if confirm "ejecutar TODOS los pasos de deploy sin volver a preguntar?"; then
    ASSUME_YES=1
    echo "${DIM}modo auto: corriendo todos los pasos sin más prompts${RST}"
    echo
  else
    echo "${DIM}cancelado${RST}"
    exit 0
  fi
fi

SLUG="$(remote_slug)"
WF="$(main_workflow)"
echo "${BOLD}${CYN}━━ $NAME${RST} ${DIM}($SLUG · $WF · ahead=$AHEAD behind=$BEHIND)${RST}"
if confirm "procesar $NAME?"; then
  deploy_repo
else
  echo "${DIM}  skip${RST}"
fi
echo
echo "${GRN}${BOLD}Listo.${RST}"
