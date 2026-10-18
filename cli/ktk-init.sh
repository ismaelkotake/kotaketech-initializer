#!/usr/bin/env bash
set -euo pipefail

VERSION="0.2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/ktk-init"
CONFIG_FILE="$CONFIG_DIR/config"
CACHE_DIR="$HOME/.cache/ktk-init"

# ─── Helpers ──────────────────────────────────────────────────────────────────

info()    { gum style --foreground 212 "→ $*"; }
success() { gum style --foreground 82  "✓ $*"; }
error()   { gum style --foreground 196 "✗ $*" >&2; exit 1; }

# ─── Dependency check ─────────────────────────────────────────────────────────

check_deps() {
  local missing=()
  command -v gum &>/dev/null || missing+=(gum)
  command -v git &>/dev/null || missing+=(git)
  command -v jq  &>/dev/null || missing+=(jq)

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing dependencies: ${missing[*]}"
    echo "  gum : https://github.com/charmbracelet/gum"
    echo "  jq  : sudo apt install jq  /  brew install jq"
    exit 1
  fi
}

# ─── Config ───────────────────────────────────────────────────────────────────

load_config() {
  mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" <<EOF
# ktk-init configuration
#
# TEMPLATES_SOURCE options:
#   local:/path/to/templates
#   git:https://github.com/ismaelkotake/kotaketech-initializer
TEMPLATES_SOURCE=local:$SCRIPT_DIR/../templates
EOF
  fi

  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
}

# ─── Templates ────────────────────────────────────────────────────────────────

get_templates() {
  local source_type="${TEMPLATES_SOURCE%%:*}"
  local source_path="${TEMPLATES_SOURCE#*:}"

  case "$source_type" in
    local)
      TEMPLATES_DIR="$(realpath "$source_path")"
      ;;
    git)
      local repo_dir="$CACHE_DIR/repo"
      if [[ -d "$repo_dir/.git" ]]; then
        info "Updating templates..."
        git -C "$repo_dir" pull --quiet 2>/dev/null || true
      else
        info "Downloading templates..."
        git clone --quiet "$source_path" "$repo_dir"
      fi
      TEMPLATES_DIR="$repo_dir/templates"
      ;;
    *)
      error "Invalid TEMPLATES_SOURCE: $TEMPLATES_SOURCE"
      ;;
  esac

  REGISTRY="$TEMPLATES_DIR/registry.json"
  [[ -f "$REGISTRY" ]] || error "registry.json não encontrado em $TEMPLATES_DIR"
}

# ─── Seleção interativa ───────────────────────────────────────────────────────

select_template() {
  local languages
  languages=$(jq -r '.[].language' "$REGISTRY" | sort -u)

  SELECTED_LANG=$(echo "$languages" | gum choose --header "Select language:")
  [[ -z "$SELECTED_LANG" ]] && error "No language selected."

  local frameworks
  frameworks=$(jq -r --arg lang "$SELECTED_LANG" \
    '.[] | select(.language == $lang) | .framework' "$REGISTRY")

  SELECTED_FW=$(echo "$frameworks" | gum choose --header "Select framework:")
  [[ -z "$SELECTED_FW" ]] && error "No framework selected."

  TEMPLATE_ID=$(jq -r --arg lang "$SELECTED_LANG" --arg fw "$SELECTED_FW" \
    '.[] | select(.language == $lang and .framework == $fw) | .id' "$REGISTRY")

  TEMPLATE_DIR="$TEMPLATES_DIR/$TEMPLATE_ID"
  [[ -d "$TEMPLATE_DIR" ]] || error "Template '$TEMPLATE_ID' not found."
}

# ─── Coleta de variáveis ──────────────────────────────────────────────────────

collect_vars() {
  PROJECT_NAME=$(gum input --header "Project name:" --placeholder "my-project")
  [[ -z "$PROJECT_NAME" ]] && error "Project name is required."

  OUTPUT_DIR=$(gum input --header "Output directory:" --value "$(pwd)/$PROJECT_NAME")
  [[ -z "$OUTPUT_DIR" ]] && error "Output directory is required."

  # Variáveis extras definidas pelo template
  VARS_FILE=$(mktemp)
  trap 'rm -f "$VARS_FILE"' EXIT

  printf "PROJECT_NAME=%s\n" "$PROJECT_NAME" > "$VARS_FILE"

  local meta="$TEMPLATE_DIR/template.json"
  if [[ -f "$meta" ]]; then
    local count
    count=$(jq 'if .variables then (.variables | length) else 0 end' "$meta")

    for ((i=0; i<count; i++)); do
      local name prompt default val
      name=$(jq -r ".variables[$i].name" "$meta")
      prompt=$(jq -r ".variables[$i].prompt" "$meta")
      default=$(jq -r ".variables[$i].default // empty" "$meta")

      val=$(gum input --header "$prompt:" --value "$default")
      printf "%s=%s\n" "$name" "$val" >> "$VARS_FILE"

      # PACKAGE_NAME → PACKAGE_PATH (dots replaced with /)
      if [[ "$name" == "PACKAGE_NAME" ]]; then
        local pkg_path="${val//.//}"
        printf "PACKAGE_PATH=%s\n" "$pkg_path" >> "$VARS_FILE"
      fi
    done
  fi
}

# ─── Aplicação do template ────────────────────────────────────────────────────

apply_template() {
  [[ -d "$OUTPUT_DIR" ]] && error "Directory '$OUTPUT_DIR' already exists."

  local parent_dir
  parent_dir="$(dirname "$OUTPUT_DIR")"
  if [[ ! -d "$parent_dir" ]]; then
    gum confirm "Directory '$parent_dir' does not exist. Create it?" || error "Operation cancelled."
    mkdir -p "$parent_dir"
  fi

  info "Copying template $TEMPLATE_ID..."
  cp -r "$TEMPLATE_DIR" "$OUTPUT_DIR"
  rm -f "$OUTPUT_DIR/template.json"

  # 1. Replace variables in file contents
  local sed_args=()
  while IFS= read -r line; do
    local key="${line%%=*}" val="${line#*=}"
    [[ -z "$key" ]] && continue
    sed_args+=(-e "s|{{${key}}}|${val}|g")
  done < "$VARS_FILE"

  # Only rewrite files that contain placeholders, so others (e.g. mvnw.cmd) keep their line endings
  { grep -rlF '{{' "$OUTPUT_DIR" || true; } | while read -r file; do
    sed -i "${sed_args[@]}" "$file" 2>/dev/null || true
  done

  # 2. Rename directories containing variable placeholders
  #    Processed deepest-first (-depth) to avoid conflicts.
  #    Values with '/' (e.g. PACKAGE_PATH=com/kotaketech/app) produce a nested directory hierarchy.
  while IFS= read -r line; do
    local key="${line%%=*}" val="${line#*=}"
    [[ -z "$key" ]] && continue
    local placeholder="{{${key}}}"
    find "$OUTPUT_DIR" -depth -type d -name "$placeholder" 2>/dev/null | while read -r src_dir; do
      local parent_dir tgt_dir
      parent_dir="$(dirname "$src_dir")"
      tgt_dir="${parent_dir}/${val}"
      mkdir -p "$tgt_dir"
      find "$src_dir" -mindepth 1 -maxdepth 1 | while read -r item; do
        mv "$item" "$tgt_dir/"
      done
      rmdir "$src_dir" 2>/dev/null || true
    done
  done < "$VARS_FILE"

  # 3. Rename files containing variable placeholders in their name
  while IFS= read -r line; do
    local key="${line%%=*}" val="${line#*=}"
    [[ -z "$key" ]] && continue
    local placeholder="{{${key}}}"
    find "$OUTPUT_DIR" -depth -type f -name "*${placeholder}*" 2>/dev/null | while read -r path; do
      local new_path="${path//${placeholder}/$val}"
      mkdir -p "$(dirname "$new_path")"
      mv "$path" "$new_path"
    done
  done < "$VARS_FILE"

  # Init git
  if gum confirm "Initialize git repository?"; then
    git -C "$OUTPUT_DIR" init --quiet --initial-branch=main
    git -C "$OUTPUT_DIR" add .
    # Keep the Maven Wrapper executable even where core.fileMode is false (e.g. Windows)
    [[ -f "$OUTPUT_DIR/mvnw" ]] && git -C "$OUTPUT_DIR" update-index --chmod=+x mvnw
    git -C "$OUTPUT_DIR" commit --quiet -m "chore: initial commit via ktk-init"
    success "Git initialized."
  fi
}

# ─── GitHub (optional) ────────────────────────────────────────────────────────
# Creates the GitHub repository, sets up Git Flow (develop as default branch)
# and the secrets used by the shared workflows in ismaelkotake/workflows.

set_repo_secret() {
  local repo="$1" name="$2" hint="$3" value="${!2:-}"

  if [[ -z "$value" ]]; then
    value=$(gum input --password --header "$name ($hint) — leave empty to skip:")
  fi

  if [[ -z "$value" ]]; then
    info "Skipped $name. Set it later with: gh secret set $name -R $repo"
    return 0
  fi

  printf '%s' "$value" | gh secret set "$name" -R "$repo"
  success "Secret $name set."
}

setup_github() {
  [[ -d "$OUTPUT_DIR/.git" ]] || return 0

  if ! command -v gh &>/dev/null; then
    info "GitHub CLI (gh) not found — skipping GitHub setup."
    return 0
  fi

  gum confirm "Create GitHub repository with Git Flow (develop as default branch)?" || return 0

  local owner visibility description repo
  owner=$(gh api user -q .login) || error "gh is not authenticated. Run: gh auth login"
  visibility=$(gum choose --header "Repository visibility:" private public)
  description=$(grep -m1 '^DESCRIPTION=' "$VARS_FILE" | cut -d= -f2- || true)
  repo="$owner/$PROJECT_NAME"

  info "Creating $repo..."
  gh repo create "$repo" "--$visibility" --description "$description" \
    --source "$OUTPUT_DIR" --remote origin --push

  git -C "$OUTPUT_DIR" checkout --quiet -b develop
  git -C "$OUTPUT_DIR" push --quiet -u origin develop
  gh repo edit "$repo" --default-branch develop --delete-branch-on-merge >/dev/null
  success "Repository $repo created (default branch: develop)."

  set_repo_secret "$repo" CLAUDE_CODE_OAUTH_TOKEN "from: claude setup-token"
  set_repo_secret "$repo" PACKAGES_TOKEN "PAT with read:packages, for kotake-parent"
}

# ─── Claude (opcional) ────────────────────────────────────────────────────────

claude_enhance() {
  local has_claude=false
  command -v claude &>/dev/null && has_claude=true
  [[ -n "${ANTHROPIC_API_KEY:-}" ]] && has_claude=true

  $has_claude || return 0

  gum confirm "Claude detected. Would you like an assisted review of the generated project?" || return 0

  info "Handing off to Claude..."
  claude "I just created a project based on the '$TEMPLATE_ID' template at '$OUTPUT_DIR'. Analyze the generated structure and suggest relevant improvements or adjustments for the '$PROJECT_NAME' project."
}

# ─── Comandos ─────────────────────────────────────────────────────────────────

cmd_update() {
  local source_type="${TEMPLATES_SOURCE%%:*}"
  if [[ "$source_type" != "git" ]]; then
    info "Local templates — nothing to update."
    return
  fi

  local repo_dir="$CACHE_DIR/repo"
  if [[ -d "$repo_dir/.git" ]]; then
    info "Updating templates..."
    git -C "$repo_dir" pull
    success "Templates updated."
  else
    get_templates
  fi
}

cmd_list() {
  load_config
  get_templates
  echo ""
  gum style --bold "Available templates:"
  echo ""
  jq -r '.[] | "  \(.language) \(.version // "") — \(.framework)  [\(.id)]"' "$REGISTRY"
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  case "${1:-}" in
    update)  check_deps; load_config; cmd_update; exit 0 ;;
    list)    check_deps; cmd_list; exit 0 ;;
    version) echo "ktk-init v$VERSION"; exit 0 ;;
    help|-h|--help)
      cat <<EOF
ktk-init v$VERSION — KotakeTech project initializer

Usage: ktk-init [command]

Commands:
  (no argument)     Create a new project interactively
  list              List available templates
  update            Update templates from remote repository
  version           Show version
  help              Show this message

Config: $CONFIG_FILE
EOF
      exit 0 ;;
  esac

  check_deps
  load_config

  gum style \
    --border rounded \
    --padding "1 2" \
    --margin "1" \
    --foreground 212 \
    --bold \
    "ktk-init v$VERSION"

  get_templates
  select_template
  collect_vars
  apply_template
  setup_github
  claude_enhance

  echo ""
  success "Project '$PROJECT_NAME' created at $OUTPUT_DIR"
}

main "$@"
