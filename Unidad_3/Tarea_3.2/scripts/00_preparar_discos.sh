#!/usr/bin/env bash
# =============================================================================
#  00_preparar_discos.sh - Prepara los dos discos virtuales de la tarea:
#
#   DISCO_DATOS (sdb)     -> ext4 con cuotas de usuario y grupo,
#                            montado en /srv/empresa (se migra lo de la 3.1)
#   DISCO_RESPALDOS (sdc) -> ext4, medio secundario en /mnt/respaldos
#                            (noauto: solo se monta mientras se respalda)
#
#  !! FORMATEA LOS DISCOS INDICADOS !!  Tiene protecciones: no toca el disco
#  del sistema, discos montados, discos de mas de 64 GB ni discos con datos.
#
#  Uso: sudo bash scripts/00_preparar_discos.sh [--datos /dev/sdX] [--respaldos /dev/sdY] [--si]
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
requiere_tarea31

CONFIRMADO=no
while [[ $# -gt 0 ]]; do
    case "$1" in
        --datos)     shift; DISCO_DATOS="$1" ;;
        --respaldos) shift; DISCO_RESPALDOS="$1" ;;
        --si)        CONFIRMADO=si ;;
        *) error "Opcion desconocida: $1"; exit 1 ;;
    esac
    shift
done

instalar_paquetes quota acl rsync

# ---- Comprobaciones de seguridad antes de formatear ----
validar_disco() {
    local d="$1" etiqueta="$2" tam firmas
    [[ -b "$d" ]] || { error "$d no existe. Revisa con: lsblk"; return 1; }
    [[ "$(lsblk -dno TYPE "$d")" == "disk" ]] || { error "$d no es un disco completo"; return 1; }
    if lsblk -no MOUNTPOINTS "$d" | grep -q .; then
        error "$d tiene particiones montadas (¿es el disco del sistema?)"; return 1
    fi
    tam="$(lsblk -bdno SIZE "$d")"
    (( tam <= 64 * 1024**3 )) || { error "$d mide mas de 64 GB: se rechaza por seguridad"; return 1; }
    # Si ya tiene nuestra etiqueta, se reutiliza; si tiene otros datos, se rechaza
    if lsblk -no LABEL "$d" | grep -qx "$etiqueta"; then
        return 0
    fi
    firmas="$(lsblk -no FSTYPE "$d" | grep -v '^$' || true)"
    if [[ -n "$firmas" ]] || [[ "$(lsblk -no NAME "$d" | wc -l)" -gt 1 ]]; then
        error "$d ya tiene particiones o datos ($firmas). Usa un disco vacio."; return 1
    fi
}

# Crea una sola particion GPT que ocupa todo el disco y devuelve su nombre
particionar() {
    local d="$1"
    # Los mensajes van a stderr para no mezclarse con el nombre devuelto
    wipefs -aq "$d" >&2
    printf 'label: gpt\n,,L\n' | sfdisk -q "$d" >&2
    partprobe "$d" >&2 2>/dev/null || true
    udevadm settle >&2
    lsblk -lnpo NAME,TYPE "$d" | awk '$2=="part" {print $1; exit}'
}

particion_con_etiqueta() { blkid -L "$1" 2>/dev/null || true; }

titulo "Discos detectados"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
echo
info "Disco de DATOS     : $DISCO_DATOS"
info "Disco de RESPALDOS : $DISCO_RESPALDOS"
[[ "$DISCO_DATOS" != "$DISCO_RESPALDOS" ]] || { error "Los dos discos no pueden ser el mismo"; exit 1; }
validar_disco "$DISCO_DATOS" "$ETIQUETA_DATOS"
validar_disco "$DISCO_RESPALDOS" "$ETIQUETA_RESPALDOS"

if [[ "$CONFIRMADO" != "si" ]]; then
    echo -e "${ROJO}Se FORMATEARAN $DISCO_DATOS y $DISCO_RESPALDOS (si aun no estan preparados).${NC}"
    read -r -p "Escribe FORMATEAR para continuar: " r
    [[ "$r" == "FORMATEAR" ]] || { echo "Cancelado"; exit 0; }
fi

# ---------------- Disco de datos ----------------
titulo "Disco de datos con cuotas"
PART_DATOS="$(particion_con_etiqueta "$ETIQUETA_DATOS")"
if [[ -n "$PART_DATOS" ]]; then
    aviso "$PART_DATOS ya tiene la etiqueta $ETIQUETA_DATOS (no se formatea)"
else
    PART_DATOS="$(particionar "$DISCO_DATOS")"
    # -O quota: el propio ext4 lleva la contabilidad de cuotas (no requiere quotacheck)
    mkfs.ext4 -q -F -L "$ETIQUETA_DATOS" -O quota -E quotatype=usrquota:grpquota "$PART_DATOS"
    ok "$PART_DATOS formateado en ext4 con soporte de cuotas"

    # Migrar el contenido actual de /srv/empresa (creado en la Tarea 3.1)
    if ! mountpoint -q "$DIR_EMPRESA" && [[ -n "$(ls -A "$DIR_EMPRESA" 2>/dev/null)" ]]; then
        TMP_MNT="$(mktemp -d)"
        mount "$PART_DATOS" "$TMP_MNT"
        cp -a "$DIR_EMPRESA"/. "$TMP_MNT"/
        umount "$TMP_MNT"; rmdir "$TMP_MNT"
        ok "Contenido de $DIR_EMPRESA copiado al disco nuevo (permisos y ACL conservados)"
    fi
fi
UUID_DATOS="$(blkid -s UUID -o value "$PART_DATOS")"

# ---------------- Disco de respaldos ----------------
titulo "Disco de respaldos (medio secundario)"
PART_RESP="$(particion_con_etiqueta "$ETIQUETA_RESPALDOS")"
if [[ -n "$PART_RESP" ]]; then
    aviso "$PART_RESP ya tiene la etiqueta $ETIQUETA_RESPALDOS (no se formatea)"
else
    PART_RESP="$(particionar "$DISCO_RESPALDOS")"
    mkfs.ext4 -q -F -L "$ETIQUETA_RESPALDOS" "$PART_RESP"
    ok "$PART_RESP formateado en ext4"
fi
UUID_RESP="$(blkid -s UUID -o value "$PART_RESP")"

# ---------------- /etc/fstab ----------------
titulo "Configurando /etc/fstab"
respaldar /etc/fstab
sed -i "/# $MARCA\$/d" /etc/fstab
cat >> /etc/fstab <<EOF
UUID=$UUID_DATOS  $DIR_EMPRESA    ext4  defaults,usrquota,grpquota,nofail  0 2  # $MARCA
UUID=$UUID_RESP  $PUNTO_RESPALDOS  ext4  defaults,noauto,nofail  0 2  # $MARCA
EOF
# nofail: si el disco falta, el sistema arranca igual
findmnt --verify --tab-file /etc/fstab >/dev/null 2>&1 || aviso "findmnt --verify reporto advertencias en /etc/fstab"
systemctl daemon-reload
grep "$MARCA" /etc/fstab

# ---------------- Montaje y cuotas ----------------
titulo "Montando"
mkdir -p "$DIR_EMPRESA" "$PUNTO_RESPALDOS"
mountpoint -q "$DIR_EMPRESA" || mount "$DIR_EMPRESA"
chown root:root "$DIR_EMPRESA"; chmod 755 "$DIR_EMPRESA"
quotaon -ug "$DIR_EMPRESA" 2>/dev/null || true
ok "$(findmnt -no SOURCE,TARGET,OPTIONS "$DIR_EMPRESA")"
quotaon -pug "$DIR_EMPRESA" || true

# El medio de respaldos se prueba y se deja DESMONTADO (fuera de linea)
mount "$PUNTO_RESPALDOS"
chmod 700 "$PUNTO_RESPALDOS"
umount "$PUNTO_RESPALDOS"
chmod 700 "$PUNTO_RESPALDOS"
ok "$PUNTO_RESPALDOS listo (se monta solo durante cada respaldo)"

titulo "Resultado"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$DISCO_DATOS" "$DISCO_RESPALDOS"
