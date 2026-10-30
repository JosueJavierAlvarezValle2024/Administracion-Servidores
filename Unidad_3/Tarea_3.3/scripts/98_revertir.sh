#!/usr/bin/env bash
# =============================================================================
#  98_revertir.sh - Deshace la Tarea 3.3: colas de CUPS, Samba, NFS y el RAID.
#  !! BORRA EL CONTENIDO DEL RAID !!
#  Uso: sudo bash scripts/98_revertir.sh [--si]
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

if [[ "${1:-}" != "--si" ]]; then
    read -r -p "Esto BORRA el RAID ($MD) y su contenido. Escribe SI para continuar: " r
    [[ "$r" == "SI" ]] || { echo "Cancelado"; exit 0; }
fi

titulo "CUPS"
for c in Oficina PDF_General PDF_Finanzas PDF_Direccion; do lpadmin -x "$c" 2>/dev/null && ok "Cola $c eliminada" || true; done
[[ -f "$BACKUP_DIR/_etc_cups_cupsd.conf.orig" ]] && cp -a "$BACKUP_DIR/_etc_cups_cupsd.conf.orig" /etc/cups/cupsd.conf && systemctl restart cups

titulo "Samba y NFS"
[[ -f "$BACKUP_DIR/_etc_samba_smb.conf.orig" ]] && cp -a "$BACKUP_DIR/_etc_samba_smb.conf.orig" /etc/samba/smb.conf && ok "smb.conf original restaurado"
for u in $(pdbedit -L 2>/dev/null | cut -d: -f1); do smbpasswd -x "$u" >/dev/null 2>&1 || true; done
systemctl restart smbd 2>/dev/null || true
sed -i "/# BEGIN $MARCA/,/# END $MARCA/d" /etc/exports 2>/dev/null || true
exportfs -ra 2>/dev/null || true
ok "Recursos compartidos retirados"

titulo "RAID"
mountpoint -q "$PUNTO_RAID" && umount "$PUNTO_RAID" && ok "$PUNTO_RAID desmontado"
sed -i "/# $MARCA\$/d" /etc/fstab
if [[ -b "$MD" ]]; then
    UUID_ARRAY="$(mdadm --detail "$MD" 2>/dev/null | awk '/UUID :/ {print $3}')"
    mdadm --stop "$MD" && ok "$MD detenido"
    [[ -n "$UUID_ARRAY" ]] && sed -i "/$UUID_ARRAY/d" /etc/mdadm/mdadm.conf
fi
for d in "${DISCOS_RAID[@]}"; do mdadm --zero-superblock "$d" 2>/dev/null || true; wipefs -aq "$d" 2>/dev/null || true; done
systemctl daemon-reload
update-initramfs -u >/dev/null 2>&1 || true
ok "Discos ${DISCOS_RAID[*]} liberados"
aviso "Las contrasenas de Samba siguen en /root/tarea33_samba.csv (borralo si ya no lo necesitas)"
