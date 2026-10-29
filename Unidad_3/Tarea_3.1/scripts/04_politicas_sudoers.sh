#!/usr/bin/env bash
# =============================================================================
#  04_politicas_sudoers.sh - Control de privilegios con sudo por grupo/rol.
#
#    admin_ti     -> sudo TOTAL (jefe de Sistemas)
#    sistemas     -> solo comandos de soporte (desbloquear cuentas, etc.)
#    operaciones  -> solo comandos operativos puntuales
#    finanzas     -> SIN sudo
#
#  Nunca se edita /etc/sudoers: se crea un archivo aparte en /etc/sudoers.d/
#  y se valida con visudo ANTES de instalarlo (un error podria dejar el
#  sistema sin sudo).
#
#  Nota Ubuntu 25.10: el sudo por defecto es "sudo-rs". Las reglas usan solo
#  sintaxis compatible con sudo-rs y con el sudo clasico.
#
#  Uso: sudo bash scripts/04_politicas_sudoers.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

DESTINO="/etc/sudoers.d/tarea31-roles"
TEMPORAL="$(mktemp)"
trap 'rm -f "$TEMPORAL"' EXIT

titulo "Generando reglas de sudo"
cat > "$TEMPORAL" <<'EOF'
# ============================================================
#  Tarea 3.1 - Reglas de privilegios por rol (TAREA31)
#  Generado por 04_politicas_sudoers.sh - no editar a mano
# ============================================================

# Comandos permitidos para soporte tecnico (Sistemas)
Cmnd_Alias SOPORTE_TI  = /usr/sbin/faillock, \
                         /usr/bin/systemctl restart cron, \
                         /usr/bin/apt update, \
                         /usr/bin/journalctl -n 50 --no-pager

# Comandos permitidos para Operaciones
Cmnd_Alias OPERACION   = /usr/bin/systemctl restart cron, \
                         /usr/bin/apt update

# Jefe de Sistemas: administracion total
%admin_ti     ALL=(ALL:ALL) ALL

# Tecnicos de Sistemas: solo soporte
%sistemas     ALL=(root) SOPORTE_TI

# Operaciones: solo comandos operativos
%operaciones  ALL=(root) OPERACION

# Finanzas: sin reglas = sin privilegios de sudo
EOF

# Validar sintaxis antes de instalar
chmod 0440 "$TEMPORAL"
if visudo -c -f "$TEMPORAL" >/dev/null 2>&1; then
    ok "Sintaxis validada con visudo"
else
    error "visudo encontro errores; NO se instalo nada:"
    visudo -c -f "$TEMPORAL" || true
    exit 1
fi

install -o root -g root -m 0440 "$TEMPORAL" "$DESTINO"
ok "Reglas instaladas en $DESTINO (permisos 440)"

# Comprobar que /etc/sudoers incluye la carpeta sudoers.d
if ! grep -Eq '^[@#]includedir[[:space:]]+/etc/sudoers.d' /etc/sudoers; then
    aviso "/etc/sudoers no incluye /etc/sudoers.d: las reglas no se aplicaran"
fi

info "Version de sudo en uso: $(sudo --version 2>/dev/null | head -n1)"
info "Prueba con: sudo -l -U <usuario>"
