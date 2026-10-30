#!/usr/bin/env bash
# =============================================================================
#  montar_raid.sh - Ensambla y monta el arreglo RAID (por ejemplo, despues de
#  mover los discos a otro equipo o si no se monto al arrancar) y muestra
#  su estado.
#
#  Uso: sudo bash scripts/montar_raid.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

titulo "Ensamblando arreglos"
if [[ -b "$MD" ]] && mdadm --detail "$MD" &>/dev/null; then
    ok "$MD ya esta activo"
else
    # Busca superbloques RAID en todos los discos y arma los arreglos
    mdadm --assemble --scan || true
    MD_REAL="$(mdadm --detail --scan | awk -v n="$NOMBRE_RAID" '$0 ~ n {print $2; exit}')"
    [[ -n "$MD_REAL" ]] || { error "No se encontro el arreglo $NOMBRE_RAID"; exit 1; }
    MD="$MD_REAL"
    ok "Arreglo ensamblado como $MD"
fi

titulo "Montando en $PUNTO_RAID"
mkdir -p "$PUNTO_RAID"
if mountpoint -q "$PUNTO_RAID"; then
    ok "$PUNTO_RAID ya esta montado"
elif grep -q "$PUNTO_RAID" /etc/fstab; then
    mount "$PUNTO_RAID" && ok "Montado con la entrada de /etc/fstab"
else
    mount "$MD" "$PUNTO_RAID" && ok "Montado directamente desde $MD"
fi

titulo "Estado"
cat /proc/mdstat
mdadm --detail "$MD" | grep -E 'Raid Level|Array Size|State :|Active Devices|Working Devices|Failed Devices|Spare Devices|/dev/sd'
df -h "$PUNTO_RAID"
