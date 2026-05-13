#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Instalador do mini-flow
# Linux / WSL
# Autor: Will "BiGSerial" Oliveira
# Data: 13/05/2026
#
# Instala:
# - ~/bin/mini-flow por padrão
# - aliases globais do Git
#
# Uso:
#   chmod +x install-mini-flow.sh
#   ./install-mini-flow.sh
#
# Remover:
#   ./install-mini-flow.sh --uninstall
#
# Diretório customizado:
#   MINI_FLOW_INSTALL_DIR="$HOME/.local/bin" ./install-mini-flow.sh
# ============================================================

INSTALL_DIR="${MINI_FLOW_INSTALL_DIR:-$HOME/bin}"
BIN_PATH="$INSTALL_DIR/mini-flow"

die() { echo "❌ $*" >&2; exit 1; }
ok()  { echo "✅ $*"; }
info(){ echo "ℹ️  $*"; }
warn(){ echo "⚠️  $*"; }

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_git() {
  has_cmd git || die "Git não encontrado no PATH. Instale o Git antes de continuar."
}

timestamp() {
  date +"%Y%m%d_%H%M%S"
}

backup_existing() {
  if [[ -f "$BIN_PATH" ]]; then
    local backup="${BIN_PATH}.bak.$(timestamp)"
    cp "$BIN_PATH" "$backup"
    ok "Backup criado: $backup"
  fi
}

ensure_shell_path() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) return 0 ;;
  esac

  local export_line='export PATH="$HOME/bin:$PATH"'

  if [[ "$INSTALL_DIR" != "$HOME/bin" ]]; then
    export_line="export PATH=\"$INSTALL_DIR:\$PATH\""
  fi

  local shell_name
  shell_name="$(basename "${SHELL:-}")"

  local rc_file=""
  case "$shell_name" in
    zsh) rc_file="$HOME/.zshrc" ;;
    bash|"") rc_file="$HOME/.bashrc" ;;
    *) rc_file="$HOME/.profile" ;;
  esac

  touch "$rc_file"

  if grep -Fq "$export_line" "$rc_file"; then
    ok "PATH já configurado em $rc_file"
  else
    {
      echo ""
      echo "# mini-flow"
      echo "$export_line"
    } >> "$rc_file"

    ok "Adicionado ao PATH em $rc_file"
    warn "Abra um novo terminal ou rode: source \"$rc_file\""
  fi
}

install_git_aliases() {
  git config --global alias.start '!mini-flow start'
  git config --global alias.hotfix '!mini-flow hotfix'
  git config --global alias.publish '!mini-flow publish'
  git config --global alias.finish '!mini-flow finish'
  git config --global alias.abort '!mini-flow abort'
  git config --global alias.abort-remote '!mini-flow abort-remote'
  git config --global alias.release '!mini-flow release'
  git config --global alias.cleanup '!mini-flow cleanup'
  git config --global alias.pause '!mini-flow pause'
  git config --global alias.resume '!mini-flow resume'
  git config --global alias.sync '!mini-flow update'
  git config --global alias.helpme '!mini-flow help'

  git config --global alias.co 'checkout'
  git config --global alias.cob 'checkout -b'
  git config --global alias.br 'branch'
  git config --global alias.st 'status -sb'
  git config --global alias.lg 'log --oneline --decorate --graph --all'

  ok "Aliases globais do Git configurados."
}

uninstall_git_aliases() {
  local aliases=(
    start hotfix publish finish abort abort-remote release cleanup pause resume sync helpme
    co cob br st lg
  )

  local a
  for a in "${aliases[@]}"; do
    git config --global --unset "alias.$a" >/dev/null 2>&1 || true
  done

  ok "Aliases globais removidos."
}

write_mini_flow() {
  mkdir -p "$INSTALL_DIR"

  cat > "$BIN_PATH" <<'MINIFLOW'
#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config fixa do fluxo
# =========================
BASE_BRANCH="${MF_BASE_BRANCH:-develop}"
PROD_BRANCH="${MF_PROD_BRANCH:-main}"
REMOTE_NAME="${MF_REMOTE_NAME:-origin}"

# Prefixos permitidos para branches de trabalho
WORK_PREFIXES=("feature/" "fix/" "hotfix/" "chore/" "refactor/" "docs/" "test/")

# Para impedir delete remoto automático:
# export MF_NO_DELETE_REMOTE=1

# =========================
# Helpers
# =========================
die() { echo "❌ $*" >&2; exit 1; }
ok()  { echo "✅ $*"; }
info(){ echo "ℹ️  $*"; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_git() {
  has_cmd git || die "git não encontrado no PATH."
}

ensure_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Você não está dentro de um repositório Git."
}

ensure_not_busy() {
  if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    die "Repo está em MERGE. Finalize com: git commit, ou aborte antes de usar o mini-flow."
  fi

  local gd
  gd="$(git rev-parse --git-dir 2>/dev/null || true)"

  if [[ -n "$gd" ]] && { [[ -d "$gd/rebase-apply" ]] || [[ -d "$gd/rebase-merge" ]]; }; then
    die "Repo está em REBASE. Conclua ou aborte o rebase antes de usar o mini-flow."
  fi

  if [[ -n "$gd" && -f "$gd/CHERRY_PICK_HEAD" ]]; then
    die "Repo está em CHERRY-PICK. Conclua ou aborte antes de usar o mini-flow."
  fi
}

current_branch() {
  git branch --show-current 2>/dev/null | tr -d '\r' | xargs || true
}

ensure_branch_exists() {
  local name="$1"

  if git show-ref --verify --quiet "refs/heads/$name"; then
    return 0
  fi

  if git show-ref --verify --quiet "refs/remotes/${REMOTE_NAME}/${name}"; then
    git checkout -b "$name" "${REMOTE_NAME}/${name}" >/dev/null
    return 0
  fi

  die "Branch '$name' não existe localmente nem no ${REMOTE_NAME}."
}

ensure_clean() {
  local dirty
  dirty="$(git status --porcelain)"
  [[ -z "$dirty" ]] || die "Workspace sujo. Commit/stash antes."
}

git_fetch_prune() {
  git fetch "$REMOTE_NAME" --prune
}

git_pull_ffonly() {
  local br="$1"
  git pull "$REMOTE_NAME" "$br" --ff-only
}

slugify() {
  local s="$*"
  s="${s,,}"
  s="${s//_/-}"
  s="$(echo "$s" | tr -s ' ' '-')"
  s="$(echo "$s" | sed -E 's/[^a-z0-9._\/-]+/-/g; s/-+/-/g; s/^-|-$//g')"
  echo "$s"
}

join_args() {
  local joined="$*"
  joined="$(echo "$joined" | xargs || true)"
  echo "$joined"
}

git_dir() {
  git rev-parse --git-dir 2>/dev/null | tr -d '\r' | xargs
}

mf_lastbranch_file() {
  echo "$(git_dir)/mini-flow.lastbranch"
}

mf_laststash_file() {
  echo "$(git_dir)/mini-flow.laststash"
}

is_work_branch() {
  local b="$1"
  local p

  for p in "${WORK_PREFIXES[@]}"; do
    [[ "$b" == "$p"* ]] && return 0
  done

  return 1
}

is_hotfix_branch() {
  local b="$1"
  [[ "$b" == hotfix/* ]]
}

base_for_branch() {
  local b="$1"

  if is_hotfix_branch "$b"; then
    echo "$PROD_BRANCH"
  else
    echo "$BASE_BRANCH"
  fi
}

safe_delete_remote_branch() {
  local b="$1"

  [[ "${MF_NO_DELETE_REMOTE:-0}" == "1" ]] && return 0

  if is_work_branch "$b"; then
    git push "$REMOTE_NAME" --delete "$b" >/dev/null 2>&1 || true
  else
    echo "⚠️  Não apaguei branch remota '$b' porque não parece branch de trabalho."
  fi
}

usage_help() {
  cat <<EOF
SICODE Git Helper: mini-flow

Configuração atual:
- Base/integracao: $BASE_BRANCH
- Producao:        $PROD_BRANCH
- Remoto:          $REMOTE_NAME

Comandos:
- git start <feature|fix|chore|refactor|docs|test> <nome da branch>
- git hotfix <nome do hotfix>
- git start hotfix <nome do hotfix>
- git publish
- git sync
- git finish
- git abort
- git abort-remote
- git release <vX.Y.Z> "<mensagem>"
- git cleanup
- git pause "<motivo>"
- git resume
- git helpme

Uso com ou sem aspas:
  git start feature teste-do-instalador
  git start feature "teste do instalador"
  git start feature teste do instalador

Hotfix:
  git hotfix corrige-login
  git hotfix "corrige erro de login"
  git start hotfix corrige erro de login

Regras:
- feature/fix/chore/refactor/docs/test nascem de $BASE_BRANCH
- hotfix nasce de $PROD_BRANCH
- finish de hotfix faz merge em $PROD_BRANCH e depois em $BASE_BRANCH

Variáveis opcionais:
- MF_BASE_BRANCH=develop
- MF_PROD_BRANCH=main
- MF_REMOTE_NAME=origin
- MF_NO_DELETE_REMOTE=1
EOF
}

# =========================
# Commands
# =========================
cmd_help() {
  usage_help
}

cmd_start() {
  ensure_not_busy

  local type="${1:-}"
  [[ -n "$type" ]] || die "Uso: git start <feature|fix|chore|refactor|docs|test|hotfix> <nome da branch>"
  shift || true

  local name
  name="$(join_args "$@")"

  [[ -n "$name" ]] || die "Informe o nome da branch. Ex: git start feature teste-do-instalador"

  type="${type,,}"

  if [[ "$type" == "hotfix" ]]; then
    cmd_hotfix "$name"
    return 0
  fi

  local allowed=("feature" "fix" "chore" "refactor" "docs" "test")
  local ok_type="false"
  local t

  for t in "${allowed[@]}"; do
    [[ "$type" == "$t" ]] && ok_type="true"
  done

  [[ "$ok_type" == "true" ]] || die "Tipo inválido: $type"

  ensure_branch_exists "$BASE_BRANCH"
  ensure_clean

  local slug
  slug="$(slugify "$name")"

  [[ -n "$slug" ]] || die "Nome da branch inválido."

  git checkout "$BASE_BRANCH"
  git_fetch_prune
  git_pull_ffonly "$BASE_BRANCH"

  git checkout -b "${type}/${slug}"
  ok "Criada branch ${type}/${slug} a partir de $BASE_BRANCH"
}

cmd_hotfix() {
  ensure_not_busy

  local name
  name="$(join_args "$@")"

  [[ -n "$name" ]] || die "Uso: git hotfix <nome do hotfix>"

  ensure_branch_exists "$PROD_BRANCH"
  ensure_clean

  local slug
  slug="$(slugify "$name")"

  [[ -n "$slug" ]] || die "Nome do hotfix inválido."

  git checkout "$PROD_BRANCH"
  git_fetch_prune
  git_pull_ffonly "$PROD_BRANCH"

  git checkout -b "hotfix/${slug}"
  ok "Criada branch hotfix/${slug} a partir de $PROD_BRANCH"
}

cmd_publish() {
  ensure_not_busy

  local b
  b="$(current_branch)"

  [[ -n "$b" ]] || die "Não consegui identificar a branch atual."

  ensure_clean
  git push -u "$REMOTE_NAME" "$b"

  ok "Publicado: $b"
}

cmd_sync() {
  ensure_not_busy
  ensure_clean

  local b
  b="$(current_branch)"
  [[ -n "$b" ]] || die "Não consegui identificar a branch atual."

  local base
  base="$(base_for_branch "$b")"

  ensure_branch_exists "$base"
  git_fetch_prune
  git rebase "${REMOTE_NAME}/${base}"

  ok "Rebase em ${REMOTE_NAME}/${base} aplicado."
}

cmd_update() {
  cmd_sync
}

cmd_finish_hotfix() {
  local b="$1"

  ensure_branch_exists "$PROD_BRANCH"
  ensure_branch_exists "$BASE_BRANCH"

  git checkout "$PROD_BRANCH"
  git_pull_ffonly "$PROD_BRANCH"

  git merge --no-ff -m "Hotfix: merge '$b' into $PROD_BRANCH" "$b"
  git push "$REMOTE_NAME" "$PROD_BRANCH"

  git checkout "$BASE_BRANCH"
  git_pull_ffonly "$BASE_BRANCH"

  git merge --no-ff -m "Backmerge hotfix '$b' into $BASE_BRANCH" "$b"
  git push "$REMOTE_NAME" "$BASE_BRANCH"

  git branch -d "$b" >/dev/null || true
  safe_delete_remote_branch "$b"

  ok "Hotfix finalizado: $b -> $PROD_BRANCH e $BASE_BRANCH."
}

cmd_finish_regular() {
  local b="$1"

  ensure_branch_exists "$BASE_BRANCH"

  git checkout "$BASE_BRANCH"
  git_pull_ffonly "$BASE_BRANCH"

  git merge --no-ff -m "Merge branch '$b' into $BASE_BRANCH" "$b"
  git push "$REMOTE_NAME" "$BASE_BRANCH"

  git branch -d "$b" >/dev/null || true
  safe_delete_remote_branch "$b"

  ok "Finalizado: merge de $b -> $BASE_BRANCH e branch local removida."
}

cmd_finish() {
  ensure_not_busy

  local b
  b="$(current_branch)"

  [[ -n "$b" ]] || die "Não consegui identificar a branch atual."
  [[ "$b" != "$BASE_BRANCH" && "$b" != "$PROD_BRANCH" ]] || die "Você está numa branch fixa ($b)."
  is_work_branch "$b" || die "Branch '$b' não parece branch de trabalho."

  ensure_clean
  git_fetch_prune

  if is_hotfix_branch "$b"; then
    cmd_finish_hotfix "$b"
  else
    cmd_finish_regular "$b"
  fi
}

cmd_abort() {
  ensure_not_busy

  local b
  b="$(current_branch)"

  [[ -n "$b" ]] || die "Não consegui identificar a branch atual."
  [[ "$b" != "$BASE_BRANCH" && "$b" != "$PROD_BRANCH" ]] || die "Você já está numa branch fixa ($b)."
  is_work_branch "$b" || die "Recusei abortar '$b' porque não parece branch de trabalho."

  local base
  base="$(base_for_branch "$b")"

  ensure_branch_exists "$base"
  ensure_clean

  git checkout "$base"
  git branch -D "$b"

  ok "Abortado localmente: $b. Voltei para $base."
}

cmd_abort_remote() {
  ensure_not_busy

  local b
  b="$(current_branch)"

  [[ -n "$b" ]] || die "Não consegui identificar a branch atual."
  [[ "$b" != "$BASE_BRANCH" && "$b" != "$PROD_BRANCH" ]] || die "Você já está numa branch fixa ($b)."
  is_work_branch "$b" || die "Recusei abort-remote em '$b' porque não parece branch de trabalho."

  local base
  base="$(base_for_branch "$b")"

  ensure_branch_exists "$base"
  ensure_clean

  git checkout "$base"
  git branch -D "$b"
  safe_delete_remote_branch "$b"

  ok "Abortado local + remoto, quando permitido: $b. Voltei para $base."
}

cmd_release() {
  ensure_not_busy

  local tag="${1:-}"
  shift || true

  local msg
  msg="$(join_args "$@")"

  [[ -n "$tag" ]] || die 'Uso: git release vX.Y.Z "mensagem"'
  [[ -n "$msg" ]] || msg="$tag"

  ensure_branch_exists "$BASE_BRANCH"
  ensure_branch_exists "$PROD_BRANCH"

  local here
  here="$(current_branch)"

  [[ "$here" == "$BASE_BRANCH" ]] || die "Release deve ser executado a partir de '$BASE_BRANCH'. Você está em '$here'."

  ensure_clean
  git_fetch_prune

  git_pull_ffonly "$BASE_BRANCH"
  git push "$REMOTE_NAME" "$BASE_BRANCH"

  git checkout "$PROD_BRANCH"
  git_pull_ffonly "$PROD_BRANCH"

  git merge --no-ff -m "Release: merge $BASE_BRANCH into $PROD_BRANCH" "$BASE_BRANCH"
  git push "$REMOTE_NAME" "$PROD_BRANCH"

  git tag -a "$tag" -m "$msg"
  git push "$REMOTE_NAME" "$tag"

  git checkout "$BASE_BRANCH" >/dev/null

  ok "Release feito: $tag"
}

cmd_cleanup() {
  ensure_not_busy
  ensure_branch_exists "$BASE_BRANCH"
  ensure_clean

  git_fetch_prune >/dev/null

  local merged
  merged="$(git branch --merged "$BASE_BRANCH" | sed -E 's/^\*?\s+//g' | tr -d '\r')"

  local br
  local removed=0

  while IFS= read -r br; do
    [[ -n "$br" ]] || continue
    [[ "$br" == "$BASE_BRANCH" || "$br" == "$PROD_BRANCH" || "$br" == "master" ]] && continue

    if is_work_branch "$br"; then
      git branch -d "$br" >/dev/null || true
      echo "🧹 removida: $br"
      removed=$((removed+1))
    fi
  done <<< "$merged"

  [[ "$removed" -gt 0 ]] || ok "Nada para limpar."
}

cmd_pause() {
  ensure_not_busy

  local b
  b="$(current_branch)"

  [[ -n "$b" ]] || die "Não consegui identificar a branch atual."
  [[ "$b" != "$BASE_BRANCH" && "$b" != "$PROD_BRANCH" ]] || die "Você está numa branch fixa ($b). Vá para uma branch de trabalho."
  is_work_branch "$b" || die "Branch '$b' não parece branch de trabalho."

  local base
  base="$(base_for_branch "$b")"
  ensure_branch_exists "$base"

  local msg
  msg="$(join_args "$@")"
  [[ -n "$msg" ]] || msg="pause"

  local lastBranchFile
  local lastStashFile

  lastBranchFile="$(mf_lastbranch_file)"
  lastStashFile="$(mf_laststash_file)"

  echo "$b" > "$lastBranchFile"

  git stash push -u -m "mini-flow pause: $b | $msg" >/dev/null

  local stashRef
  local stashMsg

  stashRef="$(git stash list -n 1 --format="%gd" 2>/dev/null | tr -d '\r' | xargs || true)"
  stashMsg="$(git stash list -n 1 --format="%s" 2>/dev/null | tr -d '\r' | xargs || true)"

  if [[ -n "$stashRef" && "$stashMsg" == mini-flow\ pause:* ]]; then
    echo "$stashRef" > "$lastStashFile"
  else
    rm -f "$lastStashFile"
  fi

  git checkout "$base" >/dev/null

  ok "Pausado. Voltei para '$base'. Para retomar: git resume"
}

cmd_resume() {
  ensure_not_busy

  local lastBranchFile
  local lastStashFile

  lastBranchFile="$(mf_lastbranch_file)"
  lastStashFile="$(mf_laststash_file)"

  [[ -f "$lastBranchFile" ]] || die "Nada para retomar. Use 'git pause' antes."

  local b
  b="$(cat "$lastBranchFile" | tr -d '\r' | xargs || true)"

  [[ -n "$b" ]] || die "Arquivo de retorno inválido: mini-flow.lastbranch"

  local base
  base="$(base_for_branch "$b")"

  ensure_branch_exists "$base"

  git checkout "$b" >/dev/null

  git_fetch_prune >/dev/null
  git rebase "${REMOTE_NAME}/${base}" || die "Conflito no rebase. Resolva e continue."

  if [[ -f "$lastStashFile" ]]; then
    local stashRef
    stashRef="$(cat "$lastStashFile" | tr -d '\r' | xargs || true)"

    if [[ -n "$stashRef" ]]; then
      git stash pop "$stashRef" || die "Conflito ao aplicar stash. Resolva, adicione e commite."
    fi

    rm -f "$lastStashFile"
  fi

  rm -f "$lastBranchFile"

  ok "Retomado em '$b'."
}

# =========================
# Main
# =========================
ensure_git

cmd="${1:-help}"
shift || true

if [[ "$cmd" == "help" || "$cmd" == "-h" || "$cmd" == "--help" ]]; then
  cmd_help "$@"
  exit 0
fi

ensure_repo

case "$cmd" in
  start)        cmd_start "$@" ;;
  hotfix)       cmd_hotfix "$@" ;;
  publish)      cmd_publish "$@" ;;
  sync)         cmd_sync "$@" ;;
  update)       cmd_update "$@" ;;
  finish)       cmd_finish "$@" ;;
  abort)        cmd_abort "$@" ;;
  abort-remote) cmd_abort_remote "$@" ;;
  release)      cmd_release "$@" ;;
  cleanup)      cmd_cleanup "$@" ;;
  pause)        cmd_pause "$@" ;;
  resume)       cmd_resume "$@" ;;
  *) die "Comando inválido. Use: help|start|hotfix|publish|sync|finish|abort|abort-remote|release|cleanup|pause|resume" ;;
esac
MINIFLOW

  chmod +x "$BIN_PATH"
  ok "mini-flow instalado em: $BIN_PATH"
}

validate_install() {
  bash -n "$BIN_PATH" || die "O script mini-flow gerado possui erro de sintaxe."

  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    warn "$INSTALL_DIR ainda não está no PATH desta sessão."
    warn "Para usar agora, rode: export PATH=\"$INSTALL_DIR:\$PATH\""
  fi

  if "$BIN_PATH" help >/dev/null; then
    ok "Validação do mini-flow: OK"
  else
    die "Falha ao validar o mini-flow."
  fi

  info "Aliases instalados:"
  git config --global --get-regexp '^alias\.(start|hotfix|publish|finish|abort|abort-remote|release|cleanup|pause|resume|sync|helpme|co|cob|br|st|lg)' || true
}

uninstall() {
  ensure_git

  uninstall_git_aliases

  if [[ -f "$BIN_PATH" ]]; then
    rm -f "$BIN_PATH"
    ok "Removido: $BIN_PATH"
  else
    warn "Arquivo não encontrado: $BIN_PATH"
  fi

  info "Não removi alterações de PATH do seu .bashrc/.zshrc para evitar mexer em configuração manual."
}

main() {
  case "${1:-install}" in
    install)
      ensure_git
      backup_existing
      write_mini_flow
      ensure_shell_path
      install_git_aliases
      validate_install
      ok "Instalação concluída."
      info "Teste dentro de um repositório com: git helpme"
      ;;
    --uninstall|uninstall)
      uninstall
      ;;
    -h|--help|help)
      cat <<EOF
Instalador do mini-flow

Uso:
  ./install-mini-flow.sh
  ./install-mini-flow.sh --uninstall

Variáveis:
  MINI_FLOW_INSTALL_DIR="$HOME/bin" ./install-mini-flow.sh

Depois de instalar:
  git helpme
  git start feature teste-do-instalador
  git start feature "teste do instalador"
  git hotfix corrige-login
EOF
      ;;
    *)
      die "Opção inválida: $1"
      ;;
  esac
}

main "${1:-install}"
