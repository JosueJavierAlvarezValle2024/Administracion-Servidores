#!/usr/bin/env bash
# =============================================================================
#  02_compartir_samba_nfs.sh - Comparte las carpetas del RAID en la red
#
#  SAMBA (Windows y Linux): \\<IP>\general, \\<IP>\sistemas, \\<IP>\finanzas,
#        \\<IP>\operaciones. Cada carpeta solo para su grupo.
#  NFS   (Linux): /srv/raid/compartido/general (rw) y operaciones (ro).
#
#  Samba usa contrasenas propias (smbpasswd). El script genera una por
#  usuario y las guarda en /root/tarea33_samba.csv (solo root).
#  Para usar una contrasena conocida en la demostracion:
#     sudo bash scripts/02_compartir_samba_nfs.sh --password Demo2026#
#
#  Uso: sudo bash scripts/02_compartir_samba_nfs.sh [--password <clave>]
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
requiere_tarea31

CLAVE_FIJA=""
[[ "${1:-}" == "--password" ]] && CLAVE_FIJA="${2:?Falta la clave}"
CRED_SAMBA="/root/tarea33_samba.csv"

mountpoint -q "$PUNTO_RAID" || { error "$PUNTO_RAID no esta montado: ejecuta 00_crear_raid.sh"; exit 1; }
instalar_paquetes samba smbclient nfs-kernel-server

# ============================== SAMBA ==============================
titulo "Configuracion de Samba"
respaldar /etc/samba/smb.conf
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
cp "$BASE_DIR/config/smb.conf" "$TMP"
# Validar antes de instalar
if testparm -s "$TMP" >/dev/null 2>&1; then
    install -o root -g root -m 0644 "$TMP" /etc/samba/smb.conf
    ok "smb.conf validado con testparm e instalado"
else
    error "testparm encontro errores; no se instalo:"; testparm -s "$TMP" || true; exit 1
fi

titulo "Usuarios de Samba"
[[ -f "$CRED_SAMBA" ]] || echo "usuario,password_samba" > "$CRED_SAMBA"
chmod 600 "$CRED_SAMBA"
for u in $(getent group empleados | cut -d: -f4 | tr ',' ' '); do
    existe_usuario "$u" || continue
    if [[ -n "$CLAVE_FIJA" ]]; then clave="$CLAVE_FIJA"
    else clave="$(openssl rand -base64 9 | tr -d '/+=' | cut -c1-10)#5"; fi
    # -s: lee la clave de la entrada estandar; -a: agrega o actualiza
    printf '%s\n%s\n' "$clave" "$clave" | smbpasswd -s -a "$u" >/dev/null
    smbpasswd -e "$u" >/dev/null
    sed -i "/^$u,/d" "$CRED_SAMBA"; echo "$u,$clave" >> "$CRED_SAMBA"
    ok "Usuario Samba: $u"
done
info "Contrasenas de Samba en $CRED_SAMBA  (ver: sudo cat $CRED_SAMBA)"

systemctl enable --now smbd >/dev/null 2>&1
systemctl restart smbd
systemctl disable --now nmbd >/dev/null 2>&1 || true   # NetBIOS no es necesario
systemctl is-active --quiet smbd && ok "Servicio smbd activo"
permitir_firewall 445 139

titulo "Recursos compartidos"
testparm -s 2>/dev/null | grep -E '^\[|path =|valid users' | grep -v '^\[global\]' || true
echo
pdbedit -L | sed 's/^/  usuario samba: /'

# =============================== NFS ===============================
titulo "Configuracion de NFS"
respaldar /etc/exports
sed -i "/# BEGIN $MARCA/,/# END $MARCA/d" /etc/exports
{ echo "# BEGIN $MARCA"; grep -v '^\s*#' "$BASE_DIR/config/exports" | grep -v '^\s*$'; echo "# END $MARCA"; } >> /etc/exports
systemctl enable --now nfs-server >/dev/null 2>&1
exportfs -ra
ok "Exportaciones activas:"
exportfs -v
permitir_firewall 2049

IP="$(IP_SERVIDOR)"
titulo "Como conectarse"
echo "Desde Windows (Explorador de archivos):  \\\\${IP:-192.168.56.101}\\general"
echo "                                          \\\\${IP:-192.168.56.101}\\finanzas   (usuario Samba de finanzas)"
echo "Desde Linux (NFS):  sudo mount -t nfs ${IP:-192.168.56.101}:/srv/raid/compartido/general /mnt/nfs"
