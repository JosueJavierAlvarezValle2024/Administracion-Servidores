#!/usr/bin/env bash
# =============================================================================
#  01_simular_fallo.sh - Simula la falla de un disco del RAID y su
#  reconstruccion, guardando logs de evidencia.
#
#  Fases:
#   --fallo         1. Escribe un archivo de prueba y guarda su SHA-256
#                   2. Marca un disco como fallido (mdadm --fail)
#                   3. Muestra el arreglo DEGRADADO y comprueba que los datos
#                      siguen accesibles
#                   4. Retira el disco (mdadm --remove)
#   --reconstruir   5. "Reemplaza" el disco (borra su superbloque) y lo agrega
#                   6. Muestra el avance de la reconstruccion hasta terminar
#                   7. Comprueba otra vez la integridad de los datos
#   (sin opcion)    Ejecuta todo seguido
#
#  Logs: logs/degradacion_<fecha>.log y logs/reconstruccion_<fecha>.log
#
#  Uso: sudo bash scripts/01_simular_fallo.sh [--fallo|--reconstruir] [--disco /dev/sde]
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

FASE="todo"
DISCO="${DISCOS_RAID[1]}"     # por defecto el segundo disco (sde)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fallo) FASE="fallo" ;; --reconstruir) FASE="reconstruir" ;;
        --disco) shift; DISCO="$1" ;;
        *) error "Opcion desconocida: $1"; exit 1 ;;
    esac
    shift
done

[[ -b "$MD" ]] && mdadm --detail "$MD" &>/dev/null || { error "$MD no existe: ejecuta 00_crear_raid.sh"; exit 1; }
mountpoint -q "$PUNTO_RAID" || { error "$PUNTO_RAID no esta montado: ejecuta montar_raid.sh"; exit 1; }

mkdir -p "$DIR_LOGS"
FECHA="$(date +%Y%m%d_%H%M%S)"
PRUEBA="$DIR_COMPARTIDO/general/prueba_raid.bin"
SUMA="/root/tarea33_prueba_raid.sha256"

estado() {   # estado <archivo_log> : resumen del arreglo
    local log="$1"
    { echo "------ mdadm --detail $MD ------"
      mdadm --detail "$MD" | grep -E 'Raid Level|Array Size|State :|Active Devices|Working Devices|Failed Devices|Rebuild Status|/dev/sd|removed'
      echo "------ /proc/mdstat ------"
      cat /proc/mdstat; } | tee -a "$log"
}
verificar_datos() {   # comprueba el SHA-256 del archivo de prueba
    local log="$1"
    if sha256sum -c --quiet "$SUMA" 2>/dev/null; then
        registrar "$log" "DATOS INTACTOS: el SHA-256 de $PRUEBA coincide con el original"
    else
        registrar "$log" "ERROR: el archivo de prueba no coincide o no se puede leer"
    fi
}
mensajes_kernel() {   # mensajes del kernel sobre el RAID desde el inicio de la fase
    local log="$1" desde="$2"
    { echo "------ Mensajes del kernel (md/raid) ------"
      journalctl -k --since "$desde" --no-pager 2>/dev/null | grep -Ei 'md/raid|md0|md:' || echo "(sin mensajes)"; } | tee -a "$log"
}

# ============================== FALLO ==============================
if [[ "$FASE" == "todo" || "$FASE" == "fallo" ]]; then
    LOG="$DIR_LOGS/degradacion_$FECHA.log"
    DESDE="$(date '+%F %T')"
    titulo "1. Estado inicial y archivo de prueba"
    registrar "$LOG" "Inicio de la simulacion de falla en $MD (disco a fallar: $DISCO)"
    head -c 50M /dev/urandom > "$PRUEBA"
    sha256sum "$PRUEBA" > "$SUMA"
    registrar "$LOG" "Archivo de prueba de 50 MB creado. SHA-256: $(cut -d' ' -f1 "$SUMA")"
    estado "$LOG"

    titulo "2. Falla del disco $DISCO"
    mdadm --manage "$MD" --fail "$DISCO" 2>&1 | tee -a "$LOG"
    sleep 2
    registrar "$LOG" "Disco $DISCO marcado como FALLIDO"

    titulo "3. Arreglo DEGRADADO: los datos siguen disponibles"
    estado "$LOG"
    verificar_datos "$LOG"
    ls -lh "$PRUEBA" | tee -a "$LOG"

    titulo "4. Retiro del disco"
    mdadm --manage "$MD" --remove "$DISCO" 2>&1 | tee -a "$LOG"
    registrar "$LOG" "Disco $DISCO RETIRADO del arreglo"
    estado "$LOG"
    mensajes_kernel "$LOG" "$DESDE"
    ok "Log de degradacion: $LOG"
fi

# ============================ RECONSTRUCCION ============================
if [[ "$FASE" == "todo" || "$FASE" == "reconstruir" ]]; then
    LOG="$DIR_LOGS/reconstruccion_$FECHA.log"
    DESDE="$(date '+%F %T')"
    titulo "5. Reemplazo del disco $DISCO"
    if mdadm --detail "$MD" | grep -q "$DISCO"; then
        aviso "$DISCO ya forma parte del arreglo: no hay nada que reconstruir"
        estado "$LOG"; exit 0
    fi
    # Borrar el superbloque simula un disco NUEVO de reemplazo
    mdadm --zero-superblock "$DISCO" 2>/dev/null || true
    wipefs -aq "$DISCO"
    registrar "$LOG" "Disco $DISCO preparado como reemplazo (superbloque borrado)"
    mdadm --manage "$MD" --add "$DISCO" 2>&1 | tee -a "$LOG"
    registrar "$LOG" "Disco $DISCO agregado: inicia la reconstruccion"

    titulo "6. Reconstruccion en curso"
    sleep 1
    while grep -qE 'recovery|resync' /proc/mdstat; do
        AVANCE="$(grep -oE '(recovery|resync) = *[0-9.]+%.*' /proc/mdstat | head -n1 || true)"
        registrar "$LOG" "$AVANCE"
        sleep 3
    done
    registrar "$LOG" "Reconstruccion TERMINADA"

    titulo "7. Estado final"
    estado "$LOG"
    verificar_datos "$LOG"
    mensajes_kernel "$LOG" "$DESDE"
    ok "Log de reconstruccion: $LOG"
fi
