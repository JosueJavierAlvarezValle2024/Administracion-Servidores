#!/usr/bin/env bash
# =============================================================================
#  backup.sh - Respaldo automatico comprimido con verificacion y log
#  Tarea 3.2 - Administracion de Servidores
#
#  Tipos de respaldo (GNU tar --listed-incremental):
#    completo     : copia TODO. Reinicia la cadena de respaldos.
#    diferencial  : copia lo que cambio desde el ultimo COMPLETO.
#    incremental  : copia lo que cambio desde el ultimo respaldo (completo o
#                   incremental).
#    auto         : completo el dia DIA_COMPLETO (o si no existe ninguno);
#                   el resto de los dias usa TIPO_DIARIO.
#
#  Flujo:
#    1. Monta el medio secundario (/mnt/respaldos) si no esta montado
#    2. Revisa espacio libre
#    3. Crea  AAAAMMDD_HHMMSS_<tipo>.tar.gz  (conserva permisos, ACL y xattrs)
#    4. Verifica: integridad gzip, lectura completa con tar y SHA-256
#    5. Guarda listado de archivos (.lst), checksum (.sha256) y log (.log)
#    6. Rotacion: conserva los ultimos RETENER_COMPLETOS ciclos
#    7. (Opcional) Copia a un servidor remoto con rsync por SSH
#    8. Desmonta el medio secundario (queda fuera de linea)
#
#  Uso:  sudo backup.sh [completo|diferencial|incremental|auto]
#  Configuracion: /etc/tarea32/backup.conf
#  Codigos de salida: 0 = correcto, 1 = error, 2 = uso incorrecto
# =============================================================================
set -Eeuo pipefail
umask 077

# ------------------------- Valores por defecto -------------------------------
CONF="${BACKUP_CONF:-/etc/tarea32/backup.conf}"
ORIGENES=(/srv/empresa /home /etc)
EXCLUIR=('*/.cache' '*/.local/share/Trash' '*/snap' '*.iso' '*/lost+found')
PUNTO_MONTAJE="/mnt/respaldos"
MONTAR_AUTOMATICO="si"
DESMONTAR_AL_FINAL="si"
SUBCARPETA="tarea32"
TIPO_DIARIO="diferencial"
DIA_COMPLETO=7                 # date +%u  (1 = lunes ... 7 = domingo)
RETENER_COMPLETOS=4            # ciclos completos que se conservan
ESPACIO_MINIMO_MB=200
REMOTO=""                      # ej. "respaldo@192.168.56.10:/respaldos"
LOG="/var/log/tarea32_backup.log"
SNAR_DIR="/var/lib/tarea32"    # archivos de estado de tar (.snar)

# shellcheck source=/dev/null
[[ -f "$CONF" ]] && source "$CONF"

# ------------------------------ Funciones ------------------------------------
LOG_EJECUCION=""
log() {
    local linea
    linea="$(date '+%F %T') [$1] $2"
    echo "$linea"
    echo "$linea" >> "$LOG"
    if [[ -n "$LOG_EJECUCION" ]]; then echo "$linea" >> "$LOG_EJECUCION" 2>/dev/null || true; fi
    logger -t backup.sh "[$1] $2" 2>/dev/null || true
}

uso() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

MONTADO_POR_MI="no"
al_salir() {
    local rc=$?
    trap - ERR             # la limpieza final no debe disparar el manejador de errores
    LOG_EJECUCION=""       # el log por ejecucion vive en el medio que se va a desmontar
    if [[ "$MONTADO_POR_MI" == "si" && "$DESMONTAR_AL_FINAL" == "si" ]]; then
        sync
        umount "$PUNTO_MONTAJE" && log INFO "Medio secundario desmontado ($PUNTO_MONTAJE)"
    fi
    [[ -n "${SNAR_TMP:-}" ]] && rm -f "$SNAR_TMP"
    exit "$rc"
}
al_fallar() {
    log ERROR "Fallo en la linea $1 (codigo $2). Respaldo NO valido."
    echo "ERROR $(date '+%F %T') linea $1" > "$SNAR_DIR/ultimo_estado"
}
trap 'al_fallar $LINENO $?' ERR
trap al_salir EXIT

# ------------------------------ Inicio ---------------------------------------
TIPO="${1:-auto}"
case "$TIPO" in
    completo|diferencial|incremental|auto) ;;
    -h|--help) uso; exit 0 ;;
    *) uso; exit 2 ;;
esac
[[ $EUID -eq 0 ]] || { echo "Ejecuta como root: sudo $0 $TIPO" >&2; exit 1; }

mkdir -p "$SNAR_DIR"; chmod 700 "$SNAR_DIR"
touch "$LOG"; chmod 600 "$LOG"

# Evita dos respaldos al mismo tiempo
exec 9> /run/tarea32_backup.lock
flock -n 9 || { log ERROR "Ya hay un respaldo en ejecucion"; exit 1; }

INICIO=$(date +%s)
FECHA="$(date +%Y%m%d_%H%M%S)"
log INFO "===== Inicio de respaldo (solicitado: $TIPO) en $(hostname) ====="

# 1. Montar medio secundario
if ! mountpoint -q "$PUNTO_MONTAJE"; then
    if [[ "$MONTAR_AUTOMATICO" == "si" ]]; then
        mkdir -p "$PUNTO_MONTAJE"
        mount "$PUNTO_MONTAJE"
        MONTADO_POR_MI="si"
        log OK "Medio secundario montado: $(findmnt -no SOURCE "$PUNTO_MONTAJE") -> $PUNTO_MONTAJE"
    else
        log ERROR "$PUNTO_MONTAJE no esta montado"; exit 1
    fi
fi
# Nunca escribir en el disco del sistema por error
mountpoint -q "$PUNTO_MONTAJE" || { log ERROR "$PUNTO_MONTAJE no es un punto de montaje"; exit 1; }

DESTINO="$PUNTO_MONTAJE/$SUBCARPETA/$(hostname)"
mkdir -p "$DESTINO"; chmod 700 "$DESTINO"

# 2. Espacio libre
LIBRE_MB=$(df -Pm "$DESTINO" | awk 'NR==2 {print $4}')
(( LIBRE_MB >= ESPACIO_MINIMO_MB )) || { log ERROR "Espacio insuficiente: ${LIBRE_MB} MB libres"; exit 1; }
log INFO "Espacio libre en destino: ${LIBRE_MB} MB"

# Decidir el tipo real de respaldo
hay_completo() { compgen -G "$DESTINO/*_completo.tar.gz" >/dev/null && [[ -f "$SNAR_DIR/nivel0.snar" ]]; }
if [[ "$TIPO" == "auto" ]]; then
    if ! hay_completo || [[ "$(date +%u)" == "$DIA_COMPLETO" ]]; then TIPO="completo"; else TIPO="$TIPO_DIARIO"; fi
fi
if [[ "$TIPO" != "completo" ]] && ! hay_completo; then
    log AVISO "No existe un respaldo completo previo: se hara uno completo"
    TIPO="completo"
fi

NOMBRE="${FECHA}_${TIPO}"
ARCHIVO="$DESTINO/$NOMBRE.tar.gz"
LOG_EJECUCION="$DESTINO/$NOMBRE.log"
log INFO "Tipo de respaldo: $TIPO -> $ARCHIVO"

# 3. Crear el archivo
case "$TIPO" in
    completo)    rm -f "$SNAR_DIR"/*.snar; SNAR="$SNAR_DIR/nivel0.snar" ;;
    diferencial) SNAR_TMP="$(mktemp)"; cp "$SNAR_DIR/nivel0.snar" "$SNAR_TMP"; SNAR="$SNAR_TMP" ;;
    incremental) SNAR="$SNAR_DIR/incremental.snar" ;;
esac

RUTAS=()
for o in "${ORIGENES[@]}"; do
    if [[ -e "$o" ]]; then RUTAS+=("${o#/}"); else log AVISO "No existe el origen $o (se omite)"; fi
done
EXCL=()
for e in "${EXCLUIR[@]}"; do EXCL+=("--exclude=$e"); done

log INFO "Origenes: ${ORIGENES[*]}"
RC_TAR=0
tar --create --gzip \
    --file="$ARCHIVO" \
    --listed-incremental="$SNAR" \
    --acls --xattrs --one-file-system \
    "${EXCL[@]}" \
    -C / "${RUTAS[@]}" 2>>"$LOG_EJECUCION" || RC_TAR=$?

# tar: 0 = correcto, 1 = algun archivo cambio mientras se leia (advertencia)
if (( RC_TAR > 1 )); then
    log ERROR "tar termino con codigo $RC_TAR"; rm -f "$ARCHIVO"; exit 1
fi
(( RC_TAR == 1 )) && log AVISO "Algunos archivos cambiaron durante el respaldo"

# El completo inicia tambien la cadena de incrementales
[[ "$TIPO" == "completo" ]] && cp "$SNAR_DIR/nivel0.snar" "$SNAR_DIR/incremental.snar"

# 4-5. Verificacion
gzip -t "$ARCHIVO"
log OK "Integridad gzip verificada"
tar --list --gzip --file="$ARCHIVO" > "$DESTINO/$NOMBRE.lst"
NUM=$(grep -vc '/$' "$DESTINO/$NOMBRE.lst" || true)
log OK "Lectura completa con tar: $NUM archivos"
( cd "$DESTINO" && sha256sum "$NOMBRE.tar.gz" > "$NOMBRE.tar.gz.sha256" && sha256sum -c --quiet "$NOMBRE.tar.gz.sha256" )
log OK "SHA-256: $(cut -d' ' -f1 "$ARCHIVO.sha256")"

# 6. Rotacion: conservar los ultimos RETENER_COMPLETOS ciclos
mapfile -t COMPLETOS < <(find "$DESTINO" -maxdepth 1 -name '*_completo.tar.gz' -printf '%f\n' | sort)
if (( ${#COMPLETOS[@]} > RETENER_COMPLETOS )); then
    CORTE="${COMPLETOS[${#COMPLETOS[@]}-RETENER_COMPLETOS]:0:15}"
    for f in "$DESTINO"/*; do
        b="$(basename "$f")"
        if [[ "$b" =~ ^[0-9]{8}_[0-9]{6}_ && "${b:0:15}" < "$CORTE" ]]; then
            rm -f "$f"; log INFO "Rotacion: eliminado $b"
        fi
    done
fi

# 7. Copia remota opcional
if [[ -n "$REMOTO" ]]; then
    if rsync -a --partial "$ARCHIVO" "$ARCHIVO.sha256" "$DESTINO/$NOMBRE.lst" "$REMOTO/"; then
        log OK "Copia remota enviada a $REMOTO"
    else
        log AVISO "No se pudo copiar a $REMOTO (el respaldo local es valido)"
    fi
fi

# Resumen
TAMANO="$(du -h "$ARCHIVO" | cut -f1)"
DURACION=$(( $(date +%s) - INICIO ))
log OK "RESPALDO CORRECTO | tipo=$TIPO | tamano=$TAMANO | archivos=$NUM | duracion=${DURACION}s"
echo "OK $(date '+%F %T') $NOMBRE $TAMANO" > "$SNAR_DIR/ultimo_estado"
