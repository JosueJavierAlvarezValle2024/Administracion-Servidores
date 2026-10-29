#!/usr/bin/env bash
# =============================================================================
#  98_revertir.sh - Deshace TODO lo que hicieron los scripts de la tarea:
#                   usuarios del CSV, grupos, carpetas, sudoers, pam_time y
#                   pam_faillock. Util para repetir la practica desde cero.
#  Uso: sudo bash scripts/98_revertir.sh [--si]
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

if [[ "${1:-}" != "--si" ]]; then
    read -r -p "Esto ELIMINA los usuarios del CSV, sus homes y $DIR_EMPRESA. Escribe SI para continuar: " r
    [[ "$r" == "SI" ]] || { echo "Cancelado"; exit 0; }
fi

titulo "Eliminando usuarios"
while IFS=',' read -r -u 3 u _; do
    if id "$u" &>/dev/null && ! es_protegido "$u"; then
        pkill -KILL -u "$u" 2>/dev/null || true
        userdel --remove "$u" 2>/dev/null || userdel "$u" || true
        faillock --user "$u" --reset 2>/dev/null || true
        ok "Usuario $u eliminado"
    fi
done 3< <(leer_csv)

titulo "Eliminando grupos y carpetas"
for entrada in "${GRUPOS[@]}"; do
    g="${entrada%%:*}"
    getent group "$g" >/dev/null && groupdel "$g" && ok "Grupo $g eliminado" || true
done
rm -rf "$DIR_EMPRESA" && ok "$DIR_EMPRESA eliminado"

titulo "Quitando reglas de sudo"
rm -f /etc/sudoers.d/tarea31-roles && ok "sudoers.d/tarea31-roles eliminado"

titulo "Quitando pam_time y reglas de horario"
for f in /etc/pam.d/*; do
    if grep -q "pam_time.so.*$MARCA" "$f"; then
        sed -i "/pam_time.so.*$MARCA/d" "$f" && ok "pam_time quitado de $f"
    fi
done
sed -i "/# BEGIN $MARCA/,/# END $MARCA/d" /etc/security/time.conf 2>/dev/null || true

titulo "Quitando pam_faillock"
DEBIAN_FRONTEND=noninteractive pam-auth-update --remove tarea31-faillock tarea31-faillock-preauth || true
rm -f /usr/share/pam-configs/tarea31-faillock /usr/share/pam-configs/tarea31-faillock-preauth
sed -i "/# BEGIN $MARCA/,/# END $MARCA/d" /etc/security/faillock.conf 2>/dev/null || true
ok "pam_faillock desactivado"

aviso "Las contrasenas temporales siguen en $CRED_FILE (borralo si ya no lo necesitas)"
ok "Sistema revertido"
