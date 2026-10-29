#!/usr/bin/env bash
# =============================================================================
#  comun.sh - Variables y funciones compartidas (Tarea 3.2)
#  Requiere que la Tarea 3.1 ya este aplicada (usuarios, grupos, /srv/empresa)
# =============================================================================
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---- Discos (cambialos si en tu VM tienen otro nombre; revisa con: lsblk) ----
DISCO_DATOS="${DISCO_DATOS:-/dev/sdb}"          # datos con cuotas -> /srv/empresa
DISCO_RESPALDOS="${DISCO_RESPALDOS:-/dev/sdc}"  # medio secundario -> /mnt/respaldos
ETIQUETA_DATOS="DATOS_EMP"
ETIQUETA_RESPALDOS="RESPALDOS"

DIR_EMPRESA="/srv/empresa"
PUNTO_RESPALDOS="/mnt/respaldos"
LOG_FILE="/var/log/tarea32.log"
BACKUP_DIR="/var/backups/tarea32"
MARCA="TAREA32"
DEPARTAMENTOS=(sistemas finanzas operaciones)

# ---------- Mensajes ----------
VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; ROJO='\033[0;31m'; AZUL='\033[0;36m'; NC='\033[0m'
_log()  { printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" >> "$LOG_FILE" 2>/dev/null || true; }
info()  { echo -e "${AZUL}[INFO]${NC}  $*";  _log INFO  "$*"; }
ok()    { echo -e "${VERDE}[ OK ]${NC}  $*"; _log OK    "$*"; }
aviso() { echo -e "${AMARILLO}[AVISO]${NC} $*"; _log AVISO "$*"; }
error() { echo -e "${ROJO}[ERROR]${NC} $*" >&2; _log ERROR "$*"; }
titulo(){ echo -e "\n${AZUL}==== $* ====${NC}"; }

requiere_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Este script debe ejecutarse como root:  sudo bash $0" >&2
        exit 1
    fi
    touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
    mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR"
}

# Verifica que la Tarea 3.1 este aplicada
requiere_tarea31() {
    local g
    for g in sistemas finanzas operaciones empleados jefes admin_ti; do
        getent group "$g" >/dev/null || { error "Falta el grupo '$g': aplica primero la Tarea 3.1"; exit 1; }
    done
    [[ -d "$DIR_EMPRESA" ]] || { error "No existe $DIR_EMPRESA: aplica primero la Tarea 3.1"; exit 1; }
}

# Instala solo los paquetes que falten
instalar_paquetes() {
    local faltan=() p
    for p in "$@"; do dpkg -s "$p" &>/dev/null || faltan+=("$p"); done
    if [[ ${#faltan[@]} -gt 0 ]]; then
        info "Instalando paquetes: ${faltan[*]}"
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${faltan[@]}"
    fi
}

respaldar() {
    local archivo="$1" destino
    [[ -f "$archivo" ]] || return 0
    destino="$BACKUP_DIR/$(echo "$archivo" | tr '/' '_').orig"
    [[ -f "$destino" ]] || { cp -a "$archivo" "$destino"; info "Respaldo: $archivo -> $destino"; }
}

# Integrantes de un grupo (secundarios + primarios)
miembros_grupo() {
    local grupo="$1" gid
    gid="$(getent group "$grupo" | cut -d: -f3)" || return 0
    { getent group "$grupo" | cut -d: -f4 | tr ',' '\n'
      awk -F: -v g="$gid" '$4==g {print $1}' /etc/passwd; } | grep -v '^$' | sort -u || true
}

existe_usuario() { id "$1" &>/dev/null; }

# Ejecuta un comando como otro usuario sin pedir contrasena
como() {
    local u="$1"; shift
    setpriv --reuid="$u" --regid="$(id -gn "$u")" --init-groups -- "$@"
}
