#!/usr/bin/env bash
# =============================================================================
#  00_crear_raid.sh - Crea un arreglo RAID por software con mdadm
#
#   RAID 5 (por defecto): 3 discos, tolera la falla de 1 disco.
#                         Capacidad util = (n - 1) x tamano = 2 GB con 3 x 1 GB.
#   RAID 1 (NIVEL_RAID=1): 2 discos en espejo. Capacidad util = 1 disco.
#
#  Pasos: valida discos -> mdadm --create -> espera la sincronizacion ->
#         ext4 -> mdadm.conf + initramfs -> /etc/fstab -> monta en /srv/raid ->
#         crea carpetas compartidas por departamento -> guarda log de creacion
#
#  !! BORRA LOS DISCOS INDICADOS !!  No toca discos montados, del sistema,
#  de mas de 64 GB ni discos con datos.
#
#  Uso: sudo bash scripts/00_crear_raid.sh [--si]
#       sudo DISCOS_RAID="/dev/sdd /dev/sde" NIVEL_RAID=1 bash scripts/00_crear_raid.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
requiere_tarea31
CONFIRMADO="${1:-}"

instalar_paquetes mdadm

MINIMO=3; [[ "$NIVEL_RAID" == "1" ]] && MINIMO=2
[[ ${#DISCOS_RAID[@]} -ge $MINIMO ]] || { error "RAID $NIVEL_RAID necesita al menos $MINIMO discos"; exit 1; }

# ---- Si el arreglo ya existe, no se vuelve a crear ----
if [[ -b "$MD" ]] && mdadm --detail "$MD" &>/dev/null; then
    aviso "$MD ya existe: no se vuelve a crear"
    mdadm --detail "$MD"
    exit 0
fi

validar_disco() {
    local d="$1" tam
    [[ -b "$d" ]] || { error "$d no existe. Revisa con: lsblk"; return 1; }
    [[ "$(lsblk -dno TYPE "$d")" == "disk" ]] || { error "$d no es un disco completo"; return 1; }
    if lsblk -no MOUNTPOINTS "$d" | grep -q .; then error "$d esta montado"; return 1; fi
    tam="$(lsblk -bdno SIZE "$d")"
    (( tam <= 64 * 1024**3 )) || { error "$d mide mas de 64 GB: se rechaza por seguridad"; return 1; }
    if [[ -n "$(lsblk -no FSTYPE "$d" | grep -v '^$\|linux_raid_member' || true)" ]]; then
        error "$d tiene datos ($(lsblk -no FSTYPE "$d" | tr '\n' ' ')). Usa un disco vacio."; return 1
    fi
}

titulo "Discos para el RAID $NIVEL_RAID"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "${DISCOS_RAID[@]}"
for d in "${DISCOS_RAID[@]}"; do validar_disco "$d"; done
ok "Discos validados: ${DISCOS_RAID[*]}"

if [[ "$CONFIRMADO" != "--si" ]]; then
    echo -e "${ROJO}Se BORRARAN ${DISCOS_RAID[*]} para crear el RAID $NIVEL_RAID.${NC}"
    read -r -p "Escribe RAID para continuar: " r
    [[ "$r" == "RAID" ]] || { echo "Cancelado"; exit 0; }
fi

mkdir -p "$DIR_LOGS"
LOG_CREACION="$DIR_LOGS/raid_creacion_$(date +%Y%m%d_%H%M%S).log"

titulo "Creando $MD (RAID $NIVEL_RAID)"
for d in "${DISCOS_RAID[@]}"; do
    wipefs -aq "$d"
    mdadm --zero-superblock "$d" 2>/dev/null || true
done
# --run: no preguntar; --metadata=1.2: formato moderno de superbloque
mdadm --create "$MD" --run --level="$NIVEL_RAID" --raid-devices="${#DISCOS_RAID[@]}" \
      --metadata=1.2 --name="$NOMBRE_RAID" "${DISCOS_RAID[@]}"
registrar "$LOG_CREACION" "Arreglo $MD creado: RAID $NIVEL_RAID con ${DISCOS_RAID[*]}"

titulo "Sincronizacion inicial"
# Se muestra el avance hasta que termine
while grep -qE 'resync|recovery' /proc/mdstat; do
    grep -oE '(resync|recovery) = *[0-9.]+%.*' /proc/mdstat | head -n1 | sed 's/^/   /' || true
    sleep 3
done
cat /proc/mdstat | tee -a "$LOG_CREACION"
ok "Sincronizacion terminada"

titulo "Sistema de archivos"
mkfs.ext4 -q -F -L "$ETIQUETA_RAID" "$MD"
ok "$MD formateado en ext4 (etiqueta $ETIQUETA_RAID)"

titulo "Configuracion permanente"
# mdadm.conf: permite que el arreglo se ensamble solo al arrancar
respaldar /etc/mdadm/mdadm.conf
LINEA_ARRAY="$(mdadm --detail --brief "$MD")"
UUID_ARRAY="$(mdadm --detail "$MD" | awk '/UUID :/ {print $3}')"
grep -q "$UUID_ARRAY" /etc/mdadm/mdadm.conf 2>/dev/null || echo "$LINEA_ARRAY" >> /etc/mdadm/mdadm.conf
ok "mdadm.conf: $LINEA_ARRAY"
info "Actualizando initramfs (puede tardar un poco)..."
update-initramfs -u >/dev/null 2>&1 && ok "initramfs actualizado"

# fstab: se usa el UUID del sistema de archivos
respaldar /etc/fstab
sed -i "/# $MARCA\$/d" /etc/fstab
UUID_FS="$(blkid -s UUID -o value "$MD")"
echo "UUID=$UUID_FS  $PUNTO_RAID  ext4  defaults,nofail  0 2  # $MARCA" >> /etc/fstab
systemctl daemon-reload
ok "fstab: $(grep "$MARCA" /etc/fstab)"

mkdir -p "$PUNTO_RAID"
mountpoint -q "$PUNTO_RAID" || mount "$PUNTO_RAID"
chown root:root "$PUNTO_RAID"; chmod 0755 "$PUNTO_RAID"
ok "Montado: $(findmnt -no SOURCE,TARGET,FSTYPE "$PUNTO_RAID")"

titulo "Carpetas compartidas en el RAID"
mkdir -p "$DIR_COMPARTIDO"; chmod 0755 "$DIR_COMPARTIDO"
for d in "${DEPARTAMENTOS[@]}"; do
    mkdir -p "$DIR_COMPARTIDO/$d"; chown "root:$d" "$DIR_COMPARTIDO/$d"; chmod 02770 "$DIR_COMPARTIDO/$d"
done
mkdir -p "$DIR_COMPARTIDO/general"; chown root:empleados "$DIR_COMPARTIDO/general"; chmod 03770 "$DIR_COMPARTIDO/general"
ls -ld "$DIR_COMPARTIDO"/*

titulo "Estado final"
mdadm --detail "$MD" | tee -a "$LOG_CREACION"
df -h "$PUNTO_RAID" | tee -a "$LOG_CREACION"
ok "Log de creacion: $LOG_CREACION"
