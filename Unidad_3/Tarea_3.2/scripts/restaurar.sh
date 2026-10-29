#!/usr/bin/env bash
# =============================================================================
#  restaurar.sh - Restauracion desde los respaldos creados por backup.sh
#
#  Arma automaticamente la cadena necesaria:
#    completo     -> solo el completo
#    diferencial  -> completo + ese diferencial
#    incremental  -> completo + todos los incrementales hasta el elegido
#  Antes de extraer verifica el SHA-256 de cada archivo.
#
#  Uso:
#    sudo restaurar.sh --listar
#    sudo restaurar.sh --ultimo                          # todo, a /var/tmp/restauracion_<fecha>
#    sudo restaurar.sh --respaldo 20261028_020000 --destino /var/tmp/prueba
#    sudo restaurar.sh --ultimo --ruta srv/empresa/finanzas/archivo.txt --en-sitio
#
#  --en-sitio  escribe en su ubicacion original (/). Exige --ruta.
#  --si        no pide confirmacion
# =============================================================================
set -Eeuo pipefail
umask 077

CONF="${BACKUP_CONF:-/etc/tarea32/backup.conf}"
PUNTO_MONTAJE="/mnt/respaldos"
MONTAR_AUTOMATICO="si"
DESMONTAR_AL_FINAL="si"
SUBCARPETA="tarea32"
LOG="/var/log/tarea32_backup.log"
# shellcheck source=/dev/null
[[ -f "$CONF" ]] && source "$CONF"

log()   { local l; l="$(date '+%F %T') [$1] $2"; echo "$l"; echo "$l" >> "$LOG"; logger -t restaurar.sh "[$1] $2" 2>/dev/null || true; }
morir() { log ERROR "$1"; exit 1; }
uso()   { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; }

ACCION="restaurar"; OBJETIVO=""; DEST=""; RUTA=""; EN_SITIO="no"; SI="no"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --listar)   ACCION="listar" ;;
        --ultimo)   OBJETIVO="ultimo" ;;
        --respaldo) shift; OBJETIVO="$1" ;;
        --destino)  shift; DEST="$1" ;;
        --ruta)     shift; RUTA="${1#/}" ;;
        --en-sitio) EN_SITIO="si" ;;
        --si)       SI="si" ;;
        -h|--help)  uso; exit 0 ;;
        *) uso; exit 2 ;;
    esac
    shift
done
[[ $EUID -eq 0 ]] || { echo "Ejecuta como root" >&2; exit 1; }

MONTADO_POR_MI="no"
trap '[[ "$MONTADO_POR_MI" == si && "$DESMONTAR_AL_FINAL" == si ]] && umount "$PUNTO_MONTAJE"' EXIT
if ! mountpoint -q "$PUNTO_MONTAJE"; then
    [[ "$MONTAR_AUTOMATICO" == "si" ]] || morir "$PUNTO_MONTAJE no esta montado"
    mount "$PUNTO_MONTAJE"; MONTADO_POR_MI="si"
fi

DIR="$PUNTO_MONTAJE/$SUBCARPETA/$(hostname)"
[[ -d "$DIR" ]] || morir "No hay respaldos en $DIR"
mapfile -t TODOS < <(find "$DIR" -maxdepth 1 -name '*.tar.gz' -printf '%f\n' | sort)
(( ${#TODOS[@]} > 0 )) || morir "No hay respaldos en $DIR"

tipo_de() { local b="${1%.tar.gz}"; echo "${b:16}"; }

# ---------------- Listar ----------------
if [[ "$ACCION" == "listar" ]]; then
    printf '%-20s %-12s %8s\n' "RESPALDO" "TIPO" "TAMANO"
    for b in "${TODOS[@]}"; do
        printf '%-20s %-12s %8s\n' "${b:0:15}" "$(tipo_de "$b")" "$(du -h "$DIR/$b" | cut -f1)"
    done
    exit 0
fi

# ---------------- Elegir respaldo objetivo ----------------
if [[ -z "$OBJETIVO" || "$OBJETIVO" == "ultimo" ]]; then
    OBJ="${TODOS[-1]}"
else
    OBJ=""
    for b in "${TODOS[@]}"; do [[ "$b" == "$OBJETIVO"* ]] && OBJ="$b"; done
    [[ -n "$OBJ" ]] || morir "No existe el respaldo '$OBJETIVO' (usa --listar)"
fi
TIPO_OBJ="$(tipo_de "$OBJ")"

# Ultimo completo anterior o igual al objetivo
BASE=""
for b in "${TODOS[@]}"; do
    [[ "$(tipo_de "$b")" == "completo" && ! "$b" > "$OBJ" ]] && BASE="$b"
done
[[ -n "$BASE" ]] || morir "No hay un respaldo completo anterior a $OBJ"

CADENA=("$BASE")
case "$TIPO_OBJ" in
    diferencial) CADENA+=("$OBJ") ;;
    incremental)
        for b in "${TODOS[@]}"; do
            [[ "$(tipo_de "$b")" == "incremental" && "$b" > "$BASE" && ! "$b" > "$OBJ" ]] && CADENA+=("$b")
        done ;;
esac

log INFO "Restauracion solicitada: $OBJ ($TIPO_OBJ)"
log INFO "Cadena a aplicar: ${CADENA[*]}"

# ---------------- Verificar integridad ----------------
for b in "${CADENA[@]}"; do
    ( cd "$DIR" && sha256sum -c --quiet "$b.sha256" ) || morir "Checksum INCORRECTO en $b"
    log OK "Checksum correcto: $b"
done

# ---------------- Destino ----------------
if [[ "$EN_SITIO" == "si" ]]; then
    [[ -n "$RUTA" ]] || morir "--en-sitio requiere --ruta (por seguridad)"
    DEST="/"
    if [[ "$SI" != "si" ]]; then
        read -r -p "Se sobrescribira /$RUTA en el sistema. Escribe SI para continuar: " r
        [[ "$r" == "SI" ]] || { echo "Cancelado"; exit 0; }
    fi
else
    DEST="${DEST:-/var/tmp/restauracion_$(date +%Y%m%d_%H%M%S)}"
    mkdir -p "$DEST"; chmod 700 "$DEST"
fi
log INFO "Destino: $DEST ${RUTA:+(solo $RUTA)}"

# ---------------- Extraer ----------------
INICIO=$(date +%s)
ERRTMP="$(mktemp)"
for b in "${CADENA[@]}"; do
    OPC=(--extract --gzip --file="$DIR/$b" --acls --xattrs -C "$DEST")
    # En un destino nuevo se reproduce el estado exacto (incluye borrados).
    # En sitio solo se agregan/sobrescriben archivos (nunca se borra nada).
    [[ "$EN_SITIO" == "no" ]] && OPC+=(--listed-incremental=/dev/null)
    RC=0
    # LC_ALL=C: mensajes de tar en ingles para poder reconocerlos
    if [[ -n "$RUTA" ]]; then LC_ALL=C tar "${OPC[@]}" "$RUTA" 2>"$ERRTMP" || RC=$?
    else LC_ALL=C tar "${OPC[@]}" 2>"$ERRTMP" || RC=$?; fi
    if (( RC == 0 )); then
        log OK "Extraido: $b"
    elif [[ -n "$RUTA" ]] && grep -q 'Not found in archive' "$ERRTMP"; then
        log INFO "$b no contiene $RUTA (normal en respaldos parciales)"
    else
        cat "$ERRTMP" >&2; rm -f "$ERRTMP"; morir "Fallo al extraer $b"
    fi
done
rm -f "$ERRTMP"

if [[ -n "$RUTA" ]]; then
    [[ -e "$DEST/$RUTA" ]] || morir "La ruta $RUTA no esta en ningun respaldo de la cadena"
    ls -la "$DEST/$RUTA"
fi
log OK "RESTAURACION CORRECTA en $(( $(date +%s) - INICIO ))s -> $DEST"
