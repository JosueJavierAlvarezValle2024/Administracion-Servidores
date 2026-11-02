#!/usr/bin/env bash
# =============================================================================
#  03_instalar_respaldos.sh - Instala backup.sh y restaurar.sh, su
#  configuracion, el calendario de cron y la rotacion de logs.
#
#  Uso:
#    sudo bash scripts/03_instalar_respaldos.sh
#    sudo bash scripts/03_instalar_respaldos.sh --forzar-config  # reemplaza backup.conf
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

FORZAR_CONF="no"
for a in "$@"; do
    case "$a" in
        --forzar-config) FORZAR_CONF="si" ;;
        *) error "Opcion desconocida: $a"; exit 1 ;;
    esac
done

instalar_paquetes rsync cron

titulo "Scripts"
install -o root -g root -m 0750 "$BASE_DIR/scripts/backup.sh"    /usr/local/sbin/backup.sh
install -o root -g root -m 0750 "$BASE_DIR/scripts/restaurar.sh" /usr/local/sbin/restaurar.sh
ok "/usr/local/sbin/backup.sh y /usr/local/sbin/restaurar.sh instalados (750)"

titulo "Configuracion"
mkdir -p /etc/tarea32 /var/lib/tarea32
chmod 700 /var/lib/tarea32
if [[ -f /etc/tarea32/backup.conf && "$FORZAR_CONF" != "si" ]]; then
    aviso "/etc/tarea32/backup.conf ya existe (no se sobrescribe; usa --forzar-config)"
else
    install -o root -g root -m 0640 "$BASE_DIR/config/backup.conf" /etc/tarea32/backup.conf
    ok "/etc/tarea32/backup.conf instalado"
fi

titulo "Calendario (cron)"
# Los archivos de /etc/cron.d deben ser de root, 644 y sin puntos en el nombre
install -o root -g root -m 0644 "$BASE_DIR/config/tarea32-respaldos.cron" /etc/cron.d/tarea32-respaldos
ok "/etc/cron.d/tarea32-respaldos instalado"
systemctl enable --now cron >/dev/null 2>&1 || true
systemctl is-active --quiet cron && ok "Servicio cron activo"
grep -hv '^\s*#' /etc/cron.d/tarea32-respaldos | grep -v '^\s*$'

titulo "Rotacion de logs"
install -o root -g root -m 0644 "$BASE_DIR/config/logrotate-tarea32" /etc/logrotate.d/tarea32
logrotate -d /etc/logrotate.d/tarea32 >/dev/null 2>&1 && ok "logrotate configurado"

grep -q "$PUNTO_RESPALDOS" /etc/fstab || aviso "$PUNTO_RESPALDOS no esta en /etc/fstab: ejecuta 00_preparar_discos.sh"
info "Primer respaldo manual:  sudo backup.sh completo"
