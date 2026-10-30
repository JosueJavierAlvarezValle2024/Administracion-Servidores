#!/usr/bin/env bash
# =============================================================================
#  99_validar.sh - Evidencia de la Tarea 3.3: RAID, Samba, NFS y CUPS, con
#  pruebas automaticas de acceso.
#  Uso: sudo bash scripts/99_validar.sh
#  Salida guardada en evidencias/validacion_<fecha>.txt
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

mkdir -p "$BASE_DIR/evidencias"
SALIDA="$BASE_DIR/evidencias/validacion_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$SALIDA") 2>&1
CRED_SAMBA="/root/tarea33_samba.csv"

pasaron=0; fallaron=0
resultado() {   # resultado "descripcion" esperado obtenido
    if [[ "$2" == "$3" ]]; then echo -e "${VERDE}[PASA]${NC}  $1 -> $3"; ((pasaron++)) || true
    else echo -e "${ROJO}[FALLA]${NC} $1 -> $3 (se esperaba $2)"; ((fallaron++)) || true; fi
}
clave_samba() { awk -F, -v u="$1" '$1==u {print $2}' "$CRED_SAMBA" 2>/dev/null; }
smb() {   # smb <usuario> <recurso> <comando smbclient>
    local u="$1" r="$2" c="$3"
    smbclient "//localhost/$r" -U "$u%$(clave_samba "$u")" -c "$c" >/dev/null 2>&1 && echo permitido || echo denegado
}

titulo "RAID"
cat /proc/mdstat
mdadm --detail "$MD" 2>/dev/null | grep -E 'Raid Level|Array Size|State :|Active Devices|Working Devices|Failed Devices|/dev/sd' || echo "Sin RAID"
grep "$MARCA" /etc/fstab || true
grep ARRAY /etc/mdadm/mdadm.conf || true
df -h "$PUNTO_RAID" 2>/dev/null || true
ls -ld "$DIR_COMPARTIDO"/* 2>/dev/null || true

titulo "Samba"
systemctl is-active smbd
testparm -s 2>/dev/null | grep -E '^\[|path =|valid users' | grep -v '^\[global\]' || true

titulo "NFS"
exportfs -v 2>/dev/null || true

titulo "CUPS"
lpstat -t 2>/dev/null | head -n 25 || true
echo; cupsctl | grep -E '_share_printers|_remote_admin' || true

titulo "Pruebas automaticas"
# RAID
estado_raid="$(mdadm --detail "$MD" 2>/dev/null | awk -F': ' '/State :/ {print $2}' | xargs || true)"
resultado "RAID en estado limpio (clean)" "si" "$([[ "$estado_raid" =~ ^(clean|active)$ ]] && echo si || echo "no: $estado_raid")"
resultado "RAID montado en $PUNTO_RAID" "si" "$(mountpoint -q "$PUNTO_RAID" && echo si || echo no)"

# Samba
if [[ -f "$CRED_SAMBA" ]]; then
    resultado "Samba: pedro.ruiz entra a finanzas"            permitido "$(smb pedro.ruiz finanzas ls)"
    resultado "Samba: pedro.ruiz entra a operaciones"         denegado  "$(smb pedro.ruiz operaciones ls)"
    resultado "Samba: laura.mena entra a operaciones"         permitido "$(smb laura.mena operaciones ls)"
    resultado "Samba: laura.mena entra a sistemas"            denegado  "$(smb laura.mena sistemas ls)"
    resultado "Samba: luis.rios escribe en general"           permitido "$(smb luis.rios general 'mkdir prueba_smb_luis; rmdir prueba_smb_luis')"
    resultado "Samba: acceso anonimo a general"               denegado  "$(smbclient //localhost/general -N -c ls >/dev/null 2>&1 && echo permitido || echo denegado)"
else
    aviso "No existe $CRED_SAMBA: ejecuta 02_compartir_samba_nfs.sh"
fi

# NFS (montaje de prueba en el mismo equipo)
MNT="$(mktemp -d)"
if mount -t nfs localhost:"$DIR_COMPARTIDO/general" "$MNT" 2>/dev/null; then
    resultado "NFS: montar general desde la red"           si        si
    resultado "NFS: laura.mena (empleados) escribe en general" permitido "$(como laura.mena touch "$MNT/prueba_nfs_laura" 2>/dev/null && echo permitido || echo denegado)"
    resultado "NFS: root del cliente escribe (root_squash)"  denegado  "$(touch "$MNT/prueba_nfs_root" 2>/dev/null && echo permitido || echo denegado)"
    rm -f "$DIR_COMPARTIDO/general/prueba_nfs_laura" "$DIR_COMPARTIDO/general/prueba_nfs_root"
    umount "$MNT"
else
    resultado "NFS: montar general desde la red" si no
fi
rmdir "$MNT"

# CUPS
imprimir() {   # imprimir <usuario> <cola>  (el trabajo se retiene y se cancela)
    local salida
    if salida="$(como "$1" lp -d "$2" -H hold -t prueba_permiso /etc/hostname 2>&1)"; then
        cancel "$(echo "$salida" | grep -oE "$2-[0-9]+")" 2>/dev/null || true; echo permitido
    else echo denegado; fi
}
resultado "CUPS: colas compartidas en red" si "$(cupsctl | grep -q '_share_printers=1' && echo si || echo no)"
resultado "CUPS: pedro.ruiz imprime en PDF_Finanzas"   permitido "$(imprimir pedro.ruiz PDF_Finanzas)"
resultado "CUPS: laura.mena imprime en PDF_Finanzas"   denegado  "$(imprimir laura.mena PDF_Finanzas)"
resultado "CUPS: carlos.vega imprime en PDF_Direccion" permitido "$(imprimir carlos.vega PDF_Direccion)"
resultado "CUPS: laura.mena imprime en PDF_Direccion"  denegado  "$(imprimir laura.mena PDF_Direccion)"

titulo "Logs de degradacion y reconstruccion"
ls -l "$DIR_LOGS" 2>/dev/null || echo "Aun no hay logs: ejecuta 01_simular_fallo.sh"

titulo "Resultado"
echo "Pruebas que pasaron: $pasaron   Pruebas que fallaron: $fallaron"
echo "Evidencia: $SALIDA"
