#!/usr/bin/env bash
#
# limpeza_ubuntu.sh — Limpeza segura e completa para Ubuntu 24.04.3 (Noble Numbat)
#
# Uso:
#   sudo bash limpeza_ubuntu.sh [opções]
#
# Opções:
#   --dry-run          Mostra o que seria feito, sem apagar nada
#   --journald N       Mantém apenas N dias de logs do journald (padrão: 7)
#   --wipe-history     Zera histórico do Bash do usuário atual
#   --no-apt           Pula limpeza do APT
#   --no-flatpak       Pula limpeza do Flatpak
#   --no-snap          Pula limpeza do Snap (se existir)
#   --no-docker        Pula limpeza do Docker (se existir)
#   --help             Mostra esta ajuda
#
set -euo pipefail

# ---------- Configuração ----------
DRY_RUN=0
JOURNAL_DAYS=7
DO_APT=1
DO_FLATPAK=1
DO_SNAP=1
DO_DOCKER=1
WIPE_HISTORY=0

log() { printf "[*] %s\n" "$*"; }
warn() { printf "[!] %s\n" "$*" >&2; }
die() { printf "[x] %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# SUDO inteligente
SUDO=""
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  if need_cmd sudo; then
    SUDO="sudo"
  fi
fi

usage() { sed -n '1,40p' "$0"; }

# ---------- Parse de argumentos ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --journald) shift; JOURNAL_DAYS="${1:-7}" ;;
    --wipe-history) WIPE_HISTORY=1 ;;
    --no-apt) DO_APT=0 ;;
    --no-flatpak) DO_FLATPAK=0 ;;
    --no-snap) DO_SNAP=0 ;;
    --no-docker) DO_DOCKER=0 ;;
    --help|-h) usage; exit 0 ;;
    *) warn "Opção desconhecida: $1"; usage; exit 2 ;;
  esac
  shift
done

run() {
  if [ $DRY_RUN -eq 1 ]; then
    printf "    DRY-RUN: %q\n" "$*"
  else
    eval "$@"
  fi
}

# Remove CONTEÚDO de um diretório (sem apagar o próprio dir)
clean_dir_contents() {
  local dir="$1"
  if [ -d "$dir" ]; then
    log "Limpando conteúdo de $dir"
    if [ $DRY_RUN -eq 1 ]; then
      run "find \"$dir\" -mindepth 1 -maxdepth 1 -print"
    else
      shopt -s nullglob dotglob
      local entries=("$dir"/*)
      if [ ${#entries[@]} -gt 0 ]; then
        run "$SUDO rm -rf --one-file-system -- \"${entries[@]}\""
      fi
      shopt -u dotglob nullglob
    fi
  else
    log "$dir não existe; ignorando."
  fi
}

# Trunca arquivos *.log e limpa /var/log rotineiramente
truncate_var_log() {
  local base="/var/log"
  if [ -d "$base" ]; then
    log "Truncando arquivos de log em $base (mantendo arquivos, zerando conteúdo)"
    if [ $DRY_RUN -eq 1 ]; then
      run "find $base -type f -name \"*.log\" -printf '%p\n'"
    else
      run "$SUDO find $base -type f -name \"*.log\" -exec truncate -s 0 {} +"
      run "$SUDO find $base -type f \\( -name \"*.gz\" -o -name \"*.old\" -o -name \"*.1\" \\) -delete"
    fi
  fi
}

# ---------- Limpezas de usuário ----------
USER_HOME="$(getent passwd ${SUDO_USER:-$USER} | cut -d: -f6)"
log "HOME alvo: $USER_HOME"

log "Forçando limpeza da lixeira do usuário"
run "$SUDO rm -rf \"$USER_HOME/.local/share/Trash/files\"/*"
run "$SUDO rm -rf \"$USER_HOME/.local/share/Trash/info\"/*"

log "Limpando caches do usuário (~/.cache, miniaturas, etc.)"
clean_dir_contents "$USER_HOME/.cache"
clean_dir_contents "$USER_HOME/.thumbnails"
clean_dir_contents "$USER_HOME/.fragments"

log "Limpando caches de aplicações comuns"
clean_dir_contents "$USER_HOME/.cache/evolution"
clean_dir_contents "$USER_HOME/.cache/mozilla"
clean_dir_contents "$USER_HOME/.cache/google-chrome"
clean_dir_contents "$USER_HOME/.cache/chromium"
clean_dir_contents "$USER_HOME/.cache/BraveSoftware"
clean_dir_contents "$USER_HOME/.cache/microsoft-edge"
clean_dir_contents "$USER_HOME/.cache/flatpak"

log "Limpando caches de outros aplicativos"
clean_dir_contents "$USER_HOME/.cache/spotify"
clean_dir_contents "$USER_HOME/.config/discord/Cache"
clean_dir_contents "$USER_HOME/.config/discord/Code Cache"
clean_dir_contents "$USER_HOME/.steam/steam/appcache"
clean_dir_contents "$USER_HOME/.steam/steam/depotcache"
clean_dir_contents "$USER_HOME/.config/Code/Cache"
clean_dir_contents "$USER_HOME/.config/Code/CachedData"
clean_dir_contents "$USER_HOME/.cache/libreoffice"
clean_dir_contents "$USER_HOME/.zoom"
clean_dir_contents "$USER_HOME/.config/Microsoft/Microsoft Teams/Cache"
clean_dir_contents "$USER_HOME/.config/Microsoft/Microsoft Teams/Code Cache"

log "Limpando caches do Kodi"
clean_dir_contents "$USER_HOME/.kodi/temp"
clean_dir_contents "$USER_HOME/.kodi/cache"
clean_dir_contents "$USER_HOME/.kodi/addons/packages"

# Limpar arquivos recentes (recently-used.xbel)
RECENT_FILE="$USER_HOME/.local/share/recently-used.xbel"
if [ -f "$RECENT_FILE" ]; then
  log "Limpando lista de arquivos recentes"
  if [ $DRY_RUN -eq 1 ]; then
    run "echo 'Zeraria $RECENT_FILE'"
  else
    : > "$RECENT_FILE" || true
  fi
fi

# Pip/NPM/Yarn caches
if need_cmd pip; then run "pip cache purge"; fi
if need_cmd npm; then run "npm cache clean --force"; fi
if need_cmd yarn; then run "yarn cache clean"; fi

# Histórico do bash
if [ $WIPE_HISTORY -eq 1 ]; then
  log "Limpando histórico do Bash do usuário"
  : > "$USER_HOME/.bash_history" || true
  history -c || true
  history -w || true
fi

# ---------- Limpezas de sistema ----------
if [ $DO_APT -eq 1 ] && need_cmd apt-get; then
  log "Limpando pacotes APT"
  run "$SUDO apt-get -y autoremove --purge"
  run "$SUDO apt-get -y autoclean"
  run "$SUDO apt-get -y clean"
  if need_cmd dpkg; then
    RC_PKGS=$(dpkg -l | awk '/^rc/ {print $2}')
    if [ -n "${RC_PKGS:-}" ]; then
      run "$SUDO dpkg -P $RC_PKGS"
    fi
  fi
fi

if [ $DO_FLATPAK -eq 1 ] && need_cmd flatpak; then
  run "$SUDO flatpak uninstall --unused -y"
fi

if [ $DO_SNAP -eq 1 ] && need_cmd snap; then
  mapfile -t TO_REMOVE < <(snap list --all | awk '/disabled/ {print $1, $2}')
  for entry in "${TO_REMOVE[@]}"; do
    name=$(awk '{print $1}' <<<"$entry")
    rev=$(awk '{print $2}' <<<"$entry")
    if [[ "$rev" =~ ^[0-9]+$ ]]; then
      run "$SUDO snap remove --purge \"$name\" --revision=\"$rev\""
    fi
  done
fi

if [ $DO_DOCKER -eq 1 ] && need_cmd docker; then
  run "$SUDO docker system prune -af"
  run "$SUDO docker volume prune -f"
fi

truncate_var_log

if need_cmd journalctl; then
  run "$SUDO journalctl --vacuum-time=${JOURNAL_DAYS}d"
fi

log "✅ Limpeza concluída com sucesso!"

