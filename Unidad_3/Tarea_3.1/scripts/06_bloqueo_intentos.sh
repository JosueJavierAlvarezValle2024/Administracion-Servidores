#!/usr/bin/env bash
# =============================================================================
#  06_bloqueo_intentos.sh - Bloqueo de cuentas por intentos fallidos
#                           con el modulo PAM pam_faillock.
#
#  Politica: 3 intentos fallidos en 15 minutos -> cuenta bloqueada 5 minutos.
#
#  Se activa "a la manera de Ubuntu" con perfiles de pam-auth-update, en lugar
#  de editar /etc/pam.d/common-auth a mano.
#
#  IMPORTANTE: la politica tambien aplica a tu usuario administrador (sudo).
#  Mientras pruebas, deja una terminal abierta con "sudo -i" por seguridad.
#  Desbloquear una cuenta:  sudo faillock --user <usuario> --reset
#
#  Uso: sudo bash scripts/06_bloqueo_intentos.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

INTENTOS=3          # deny
VENTANA=900         # fail_interval (segundos)
BLOQUEO=300         # unlock_time   (segundos)

FAILLOCK_CONF="/etc/security/faillock.conf"
PERFIL_1="/usr/share/pam-configs/tarea31-faillock"
PERFIL_2="/usr/share/pam-configs/tarea31-faillock-preauth"

titulo "Configurando $FAILLOCK_CONF"
respaldar "$FAILLOCK_CONF"
touch "$FAILLOCK_CONF"
sed -i "/# BEGIN $MARCA/,/# END $MARCA/d" "$FAILLOCK_CONF"
cat >> "$FAILLOCK_CONF" <<EOF
# BEGIN $MARCA
# Registrar en el log el nombre de usuario de los intentos fallidos
audit
# Intentos fallidos permitidos antes del bloqueo
deny = $INTENTOS
# Ventana de tiempo (segundos) en la que se cuentan los intentos
fail_interval = $VENTANA
# Tiempo de bloqueo (segundos)
unlock_time = $BLOQUEO
# END $MARCA
EOF
ok "deny=$INTENTOS  fail_interval=${VENTANA}s  unlock_time=${BLOQUEO}s"

titulo "Creando perfiles de pam-auth-update"
respaldar /etc/pam.d/common-auth
respaldar /etc/pam.d/common-account

# Perfil 1: cuenta el fallo DESPUES de pam_unix y reinicia el contador al
# iniciar sesion correctamente (seccion account)
cat > "$PERFIL_1" <<'EOF'
Name: TAREA31 - Contador de intentos fallidos (pam_faillock)
Default: no
Priority: 0
Auth-Type: Primary
Auth:
	[default=die]	pam_faillock.so authfail
Account-Type: Additional
Account:
	required	pam_faillock.so
EOF

# Perfil 2: verifica ANTES de pedir la contrasena si la cuenta esta bloqueada
cat > "$PERFIL_2" <<'EOF'
Name: TAREA31 - Verificacion previa de bloqueo (pam_faillock)
Default: no
Priority: 1024
Auth-Type: Primary
Auth:
	requisite	pam_faillock.so preauth
EOF

DEBIAN_FRONTEND=noninteractive pam-auth-update --enable tarea31-faillock tarea31-faillock-preauth
ok "Perfiles activados con pam-auth-update"

titulo "Resultado en /etc/pam.d/common-auth"
grep -nE 'pam_(faillock|unix|deny|permit)' /etc/pam.d/common-auth || true
titulo "Resultado en /etc/pam.d/common-account"
grep -n 'pam_faillock' /etc/pam.d/common-account || true

info "Ver intentos de un usuario:  sudo faillock --user <usuario>"
info "Desbloquear un usuario:      sudo faillock --user <usuario> --reset"
