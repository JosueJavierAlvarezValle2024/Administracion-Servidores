#!/usr/bin/env bash
# =============================================================================
#  comun.sh - Variables y funciones compartidas (Tarea 3.3)
#  Requiere la Tarea 3.1 aplicada (usuarios y grupos de los departamentos).
# =============================================================================
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---- RAID (cambia los discos si en tu VM tienen otro nombre; revisa con lsblk) ----
DISCOS_RAID=(${DISCOS_RAID:-/dev/sdd /dev/sde /dev/sdf})
NIVEL_RAID="${NIVEL_RAID:-5}"              # 5 (3 discos) o 1 (2 discos)
MD="/dev/md0"
NOMBRE_RAID="raid_empresa"
ETIQUETA_RAID="RAID_EMPRESA"
PUNTO_RAID="/srv/raid"
DIR_COMPARTIDO="$PUNTO_RAID/compartido"

# ---- Red ----
RED_LOCAL="${RED_LOCAL:-192.168.56.0/24}"  # red "solo anfitrion" de VirtualBox
PREFIJO_RED="192.168.56."                  # para "hosts allow" de Samba

LOG_FILE="/var/log/tarea33.log"
BACKUP_DIR="/var/backups/tarea33"
DIR_LOGS="$BASE_DIR/logs"                  # logs de degradacion/reconstruccion
MARCA="TAREA33"
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

requiere_tarea31() {
    local g
    for g in sistemas finanzas operaciones empleados jefes admin_ti; do
        getent group "$g" >/dev/null || { error "Falta el grupo '$g': aplica primero la Tarea 3.1"; exit 1; }
    done
}

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

existe_usuario() { id "$1" &>/dev/null; }

como() {
    local u="$1"; shift
    setpriv --reuid="$u" --regid="$(id -gn "$u")" --init-groups -- "$@"
}

# Abre puertos en el firewall solo si ufw esta activo
permitir_firewall() {
    local puerto
    if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q 'Status: active\|Estado: activo'; then
        for puerto in "$@"; do
            ufw allow from "$RED_LOCAL" to any port "$puerto" proto tcp >/dev/null
            ok "Firewall: puerto $puerto/tcp permitido desde $RED_LOCAL"
        done
    fi
}

# Registra en pantalla y en un archivo de log de evidencia (con fecha y hora)
registrar() {
    local archivo="$1"; shift
    echo "$(date '+%F %T') | $*" | tee -a "$archivo"
}

IP_SERVIDOR() { ip -4 -o addr show | awk -v p="$PREFIJO_RED" 'index($4,p)==1 {split($4,a,"/"); print a[1]; exit}'; }
