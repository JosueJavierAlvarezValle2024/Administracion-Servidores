#!/usr/bin/env bash
# =============================================================================
#  comun.sh - Funciones y variables compartidas por todos los scripts
#  Tarea 3.1 - Administracion de Servidores (Unidad 3)
#  Probado en: Xubuntu 25.10 (questing)
# =============================================================================
set -euo pipefail

# Rutas base (se calculan desde la ubicacion de este archivo)
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CSV_USUARIOS="${CSV_USUARIOS:-$BASE_DIR/data/usuarios.csv}"

LOG_FILE="/var/log/tarea31_usuarios.log"       # bitacora de todas las acciones
BACKUP_DIR="/var/backups/tarea31"              # respaldos de archivos del sistema
CRED_FILE="/root/tarea31_credenciales.csv"     # contrasenas temporales (solo root)
DIR_EMPRESA="/srv/empresa"                     # carpetas compartidas por depto
MARCA="TAREA31"                                # marca para identificar cambios

# Esquema organizativo
DEPARTAMENTOS=(sistemas finanzas operaciones)
#                 grupo:GID
GRUPOS=( "sistemas:3001" "finanzas:3002" "operaciones:3003"
         "empleados:3010" "jefes:3011" "admin_ti:3012" "horario_prueba:3099" )

# Politica de contrasenas
PASS_MAX_DIAS=90     # la contrasena caduca a los 90 dias
PASS_MIN_DIAS=1      # minimo 1 dia entre cambios
PASS_AVISO_DIAS=7    # avisar 7 dias antes
PASS_INACTIVO=15     # dias de gracia tras caducar antes de bloquear

# ---------- Mensajes en pantalla y bitacora ----------
VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; ROJO='\033[0;31m'; AZUL='\033[0;36m'; NC='\033[0m'

_log()  { printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" >> "$LOG_FILE" 2>/dev/null || true; }
info()  { echo -e "${AZUL}[INFO]${NC}  $*";  _log INFO  "$*"; }
ok()    { echo -e "${VERDE}[ OK ]${NC}  $*"; _log OK    "$*"; }
aviso() { echo -e "${AMARILLO}[AVISO]${NC} $*"; _log AVISO "$*"; }
error() { echo -e "${ROJO}[ERROR]${NC} $*" >&2; _log ERROR "$*"; }
titulo(){ echo -e "\n${AZUL}==== $* ====${NC}"; }

# ---------- Validaciones ----------
requiere_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Este script debe ejecutarse como root:  sudo bash $0" >&2
        exit 1
    fi
    touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
    mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR"
}

# Copia un archivo del sistema a $BACKUP_DIR una sola vez (copia original)
respaldar() {
    local archivo="$1" destino
    [[ -f "$archivo" ]] || return 0
    destino="$BACKUP_DIR/$(echo "$archivo" | tr '/' '_').orig"
    if [[ ! -f "$destino" ]]; then
        cp -a "$archivo" "$destino"
        info "Respaldo creado: $archivo -> $destino"
    fi
}

# Imprime el CSV sin encabezado, sin comentarios y sin retornos de carro (\r)
leer_csv() {
    [[ -f "$CSV_USUARIOS" ]] || { error "No existe el archivo $CSV_USUARIOS"; exit 1; }
    tail -n +2 "$CSV_USUARIOS" | tr -d '\r' | grep -Ev '^[[:space:]]*(#|$)' || true
}

# Lista los integrantes de un grupo (secundarios + quienes lo tienen como primario)
miembros_grupo() {
    local grupo="$1" gid lista
    gid="$(getent group "$grupo" | cut -d: -f3)" || return 0
    lista="$(getent group "$grupo" | cut -d: -f4 | tr ',' '\n')"
    lista+=$'\n'"$(awk -F: -v g="$gid" '$4==g {print $1}' /etc/passwd)"
    echo "$lista" | grep -v '^$' | sort -u || true
}

# Usuarios del sistema que nunca deben tocarse
es_protegido() {
    local u="$1" uid
    uid="$(id -u "$u" 2>/dev/null || echo 0)"
    [[ "$u" == "root" || "$uid" -lt 1000 || "$u" == "${SUDO_USER:-}" ]]
}
