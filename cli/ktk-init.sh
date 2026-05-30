#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
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
    echo "Dependências faltando: ${missing[*]}"
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
# TEMPLATES_SOURCE pode ser:
#   local:/caminho/para/templates
#   git:https://github.com/seu-user/kotaketech-initializer
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
        info "Atualizando templates..."
        git -C "$repo_dir" pull --quiet 2>/dev/null || true
      else
        info "Baixando templates..."
        git clone --quiet "$source_path" "$repo_dir"
      fi
      TEMPLATES_DIR="$repo_dir/templates"
      ;;
    *)
      error "TEMPLATES_SOURCE inválido: $TEMPLATES_SOURCE"
      ;;
  esac

  REGISTRY="$TEMPLATES_DIR/registry.json"
  [[ -f "$REGISTRY" ]] || error "registry.json não encontrado em $TEMPLATES_DIR"
}

# ─── Seleção interativa ───────────────────────────────────────────────────────

select_template() {
  local languages
  languages=$(jq -r '.[].language' "$REGISTRY" | sort -u)

  SELECTED_LANG=$(echo "$languages" | gum choose --header "Escolha a linguagem:")
  [[ -z "$SELECTED_LANG" ]] && error "Nenhuma linguagem selecionada."

  local frameworks
  frameworks=$(jq -r --arg lang "$SELECTED_LANG" \
    '.[] | select(.language == $lang) | .framework' "$REGISTRY")

  SELECTED_FW=$(echo "$frameworks" | gum choose --header "Escolha o framework:")
  [[ -z "$SELECTED_FW" ]] && error "Nenhum framework selecionado."

  TEMPLATE_ID=$(jq -r --arg lang "$SELECTED_LANG" --arg fw "$SELECTED_FW" \
    '.[] | select(.language == $lang and .framework == $fw) | .id' "$REGISTRY")

  TEMPLATE_DIR="$TEMPLATES_DIR/$TEMPLATE_ID"
  [[ -d "$TEMPLATE_DIR" ]] || error "Template '$TEMPLATE_ID' não encontrado."
}

# ─── Coleta de variáveis ──────────────────────────────────────────────────────

collect_vars() {
  PROJECT_NAME=$(gum input --header "Nome do projeto:" --placeholder "meu-projeto")
  [[ -z "$PROJECT_NAME" ]] && error "Nome do projeto é obrigatório."

  OUTPUT_DIR=$(gum input --header "Diretório de saída:" --value "$(pwd)/$PROJECT_NAME")
  [[ -z "$OUTPUT_DIR" ]] && error "Diretório de saída é obrigatório."

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

      # PACKAGE_NAME → PACKAGE_PATH automático
      if [[ "$name" == "PACKAGE_NAME" ]]; then
        local pkg_path="${val//.//}"
        printf "PACKAGE_PATH=%s\n" "$pkg_path" >> "$VARS_FILE"
      fi
    done
  fi
}

# ─── Aplicação do template ────────────────────────────────────────────────────

apply_template() {
  [[ -d "$OUTPUT_DIR" ]] && error "Diretório '$OUTPUT_DIR' já existe."

  info "Copiando template $TEMPLATE_ID..."
  cp -r "$TEMPLATE_DIR" "$OUTPUT_DIR"
  rm -f "$OUTPUT_DIR/template.json"

  # 1. Substitui variáveis no conteúdo dos arquivos
  local sed_args=()
  while IFS= read -r line; do
    local key="${line%%=*}" val="${line#*=}"
    [[ -z "$key" ]] && continue
    sed_args+=(-e "s|{{${key}}}|${val}|g")
  done < "$VARS_FILE"

  find "$OUTPUT_DIR" -type f | while read -r file; do
    sed -i "${sed_args[@]}" "$file" 2>/dev/null || true
  done

  # 2. Renomeia diretórios com variáveis no nome
  #    Processa do mais profundo para o mais raso (-depth) para evitar conflitos.
  #    Valores com '/' (ex: PACKAGE_PATH=com/kotaketech/app) criam hierarquia de dirs.
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

  # 3. Renomeia arquivos com variáveis no nome
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
  if gum confirm "Inicializar repositório git?"; then
    git -C "$OUTPUT_DIR" init --quiet
    git -C "$OUTPUT_DIR" add .
    git -C "$OUTPUT_DIR" commit --quiet -m "chore: initial commit via ktk-init"
    success "Git inicializado."
  fi
}

# ─── Claude (opcional) ────────────────────────────────────────────────────────

claude_enhance() {
  local has_claude=false
  command -v claude &>/dev/null && has_claude=true
  [[ -n "${ANTHROPIC_API_KEY:-}" ]] && has_claude=true

  $has_claude || return 0

  gum confirm "Claude detectado. Deseja uma revisão assistida do projeto gerado?" || return 0

  info "Passando para o Claude..."
  claude "Acabei de criar um projeto baseado no template '$TEMPLATE_ID' em '$OUTPUT_DIR'. Analise a estrutura gerada e sugira melhorias ou ajustes relevantes para o projeto '$PROJECT_NAME'."
}

# ─── Comandos ─────────────────────────────────────────────────────────────────

cmd_update() {
  local source_type="${TEMPLATES_SOURCE%%:*}"
  if [[ "$source_type" != "git" ]]; then
    info "Templates locais — nada para atualizar."
    return
  fi

  local repo_dir="$CACHE_DIR/repo"
  if [[ -d "$repo_dir/.git" ]]; then
    info "Atualizando templates..."
    git -C "$repo_dir" pull
    success "Templates atualizados."
  else
    get_templates
  fi
}

cmd_list() {
  load_config
  get_templates
  echo ""
  gum style --bold "Templates disponíveis:"
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
ktk-init v$VERSION — Inicializador de projetos KotakeTech

Uso: ktk-init [comando]

Comandos:
  (sem argumento)   Criar novo projeto interativamente
  list              Listar templates disponíveis
  update            Atualizar templates do repositório remoto
  version           Exibir versão
  help              Esta mensagem

Configuração: $CONFIG_FILE
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
  claude_enhance

  echo ""
  success "Projeto '$PROJECT_NAME' criado em $OUTPUT_DIR"
}

main "$@"
