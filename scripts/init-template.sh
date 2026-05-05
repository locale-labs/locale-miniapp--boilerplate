#!/usr/bin/env bash
#
# Inicializa una nueva mini-app a partir del boilerplate.
# - Pide nombre/slug/descripción al dev.
# - Reemplaza placeholders en todos los archivos relevantes.
# - Se elimina a sí mismo al final.
#
# Uso:
#   bash scripts/init-template.sh

set -euo pipefail

if [[ ! -f package.json ]]; then
  echo "❌ Ejecutá este script desde la raíz del repo recién clonado del template."
  exit 1
fi

if ! grep -q "{{MINIAPP_ID}}" package.json 2>/dev/null; then
  echo "❌ No se encontraron placeholders. ¿Ya inicializaste el repo?"
  exit 1
fi

# ── Defaults inferidos ──────────────────────────────────────────────────────
DIR_NAME="$(basename "$PWD")"
DEFAULT_SLUG="$DIR_NAME"
DEFAULT_ID="${DIR_NAME#locale-miniapp--}"
DEFAULT_PACKAGE="locale-miniapp-${DEFAULT_ID}"

prompt() {
  local var="$1" label="$2" default="$3"
  local val
  read -r -p "$label [$default]: " val
  val="${val:-$default}"
  printf -v "$var" '%s' "$val"
}

echo "🚀 Inicializando mini-app desde el boilerplate"
echo "   (Enter para aceptar el valor entre corchetes)"
echo

prompt MINIAPP_ID          "Mini-app id (slug corto, ej: eventos)" "$DEFAULT_ID"
prompt MINIAPP_NAME        "Nombre visible (ej: Eventos del barrio)" "$MINIAPP_ID"
prompt MINIAPP_DESCRIPTION "Descripción corta" "Mini-app de Localé"
prompt MINIAPP_SLUG        "Slug del repo (carpeta y project_id Supabase)" "$DEFAULT_SLUG"
prompt MINIAPP_PACKAGE_NAME "Nombre npm del paquete" "$DEFAULT_PACKAGE"

# Derivado: ID en upper-snake (ej. "lost-pets" → "LOST_PETS"), usado en env vars del core
MINIAPP_ID_UPPER="$(printf '%s' "$MINIAPP_ID" | tr '[:lower:]-' '[:upper:]_')"

echo
echo "📝 Reemplazando placeholders…"

# ── Archivos a procesar (excluyendo binarios, lockfiles, build/, node_modules/, .git/) ──
FILES=$(grep -RIl --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=build --exclude-dir=.temp --exclude="bun.lock" --exclude="deno.lock" -e "{{MINIAPP_" . || true)

if [[ -z "$FILES" ]]; then
  echo "⚠️  No se encontraron archivos con placeholders."
else
  while IFS= read -r f; do
    sed -i.bak \
      -e "s|{{MINIAPP_PACKAGE_NAME}}|$MINIAPP_PACKAGE_NAME|g" \
      -e "s|{{MINIAPP_DESCRIPTION}}|$MINIAPP_DESCRIPTION|g" \
      -e "s|{{MINIAPP_NAME}}|$MINIAPP_NAME|g" \
      -e "s|{{MINIAPP_SLUG}}|$MINIAPP_SLUG|g" \
      -e "s|{{MINIAPP_ID_UPPER}}|$MINIAPP_ID_UPPER|g" \
      -e "s|{{MINIAPP_ID}}|$MINIAPP_ID|g" \
      "$f"
    rm -f "$f.bak"
  done <<< "$FILES"
fi

# ── Limpieza del README: dejá solo la sección post-init ─────────────────────
if [[ -f README.md ]] && grep -q "<!-- TEMPLATE_INIT_START -->" README.md; then
  awk '
    /<!-- TEMPLATE_INIT_END -->/ { flag=0; next }
    /<!-- TEMPLATE_INIT_START -->/ { flag=1; next }
    !flag
  ' README.md > README.md.tmp && mv README.md.tmp README.md
fi

# ── Auto-eliminación ────────────────────────────────────────────────────────
echo
echo "✅ Listo. Próximos pasos:"
echo "   1. bun install"
echo "   2. Configurar .env.dev (ver DEPLOY.md y README)"
echo "   3. bunx supabase link --project-ref <project-ref>"
echo "   4. bunx supabase db push"
echo "   5. git add -A && git commit -m 'chore: init from template'"
echo
echo "🧹 Borrando este script (init-template.sh)…"
rm -- "$0"
