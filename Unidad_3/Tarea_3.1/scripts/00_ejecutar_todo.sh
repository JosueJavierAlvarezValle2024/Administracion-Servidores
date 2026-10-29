#!/usr/bin/env bash
# =============================================================================
#  00_ejecutar_todo.sh - Ejecuta toda la configuracion en orden y al final
#                        genera la evidencia de validacion.
#  Uso: sudo bash scripts/00_ejecutar_todo.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
DIR="$(dirname "$0")"

# Aviso: con inicio de sesion automatico no se pueden probar horarios/bloqueos
if grep -rqs '^[[:space:]]*autologin-user=' /etc/lightdm/; then
    aviso "LightDM tiene inicio de sesion automatico activado:"
    grep -rs '^[[:space:]]*autologin-user=' /etc/lightdm/
    aviso "Comenta esa linea si quieres probar el login grafico con otros usuarios."
fi

for paso in 01_crear_grupos 02_alta_usuarios 04_politicas_sudoers 05_horarios_acceso 06_bloqueo_intentos 99_validar; do
    titulo "Ejecutando $paso.sh"
    bash "$DIR/$paso.sh"
done

ok "Configuracion completa. Bitacora: $LOG_FILE"
