#!/usr/bin/env bash
# =============================================================================
#  05_horarios_acceso.sh - Restriccion de horarios de inicio de sesion
#                          con el modulo PAM pam_time.
#
#  1) Activa pam_time en: lightdm (login grafico), login (terminales
#     Ctrl+Alt+F3), su y sshd (si existe).
#  2) Escribe las reglas en /etc/security/time.conf
#
#  Formato de una regla:   servicios ; terminales ; usuarios ; horario
#     Wk = lunes a viernes, Wd = sabado y domingo, Al = todos los dias
#     !  = negacion (ej. !Al0000-2400 = nunca)
#
#  Las reglas se generan con los integrantes ACTUALES de cada grupo:
#  vuelve a ejecutar este script despues de dar altas o bajas.
#
#  Uso: sudo bash scripts/05_horarios_acceso.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

# ---- Horarios por grupo (puedes ajustarlos para tu demostracion) ----
HORARIO_FINANZAS="${HORARIO_FINANZAS:-Wk0800-1800}"      # L-V de 8:00 a 18:00
HORARIO_OPERACIONES="${HORARIO_OPERACIONES:-Al0600-2200}" # diario 6:00 a 22:00
HORARIO_PRUEBA="!Al0000-2400"                             # acceso denegado siempre

TIME_CONF="/etc/security/time.conf"
SERVICIOS_PAM=(lightdm login su sshd)

titulo "Activando pam_time en los servicios de inicio de sesion"
for servicio in "${SERVICIOS_PAM[@]}"; do
    archivo="/etc/pam.d/$servicio"
    if [[ ! -f "$archivo" ]]; then
        info "$archivo no existe (se omite)"; continue
    fi
    if grep -q "pam_time.so.*$MARCA" "$archivo"; then
        aviso "$archivo ya tiene pam_time (se omite)"; continue
    fi
    respaldar "$archivo"
    # Inserta la regla antes de la primera linea de la seccion "account"
    sed -i "0,/^\(@include common-account\|account\)/s//account    required     pam_time.so    # $MARCA\n&/" "$archivo"
    if grep -q "pam_time.so.*$MARCA" "$archivo"; then
        ok "pam_time activado en $archivo"
    else
        error "No se pudo insertar pam_time en $archivo"
    fi
done

# Construye la lista "usuario1|usuario2|..." con los integrantes de un grupo
lista_usuarios() { miembros_grupo "$1" | paste -sd'|' -; }

titulo "Escribiendo reglas en $TIME_CONF"
respaldar "$TIME_CONF"
# Elimina el bloque anterior (si existe) para regenerarlo
sed -i "/# BEGIN $MARCA/,/# END $MARCA/d" "$TIME_CONF"

{
    echo "# BEGIN $MARCA - generado por 05_horarios_acceso.sh"
    for par in "finanzas:$HORARIO_FINANZAS" "operaciones:$HORARIO_OPERACIONES" "horario_prueba:$HORARIO_PRUEBA"; do
        grupo="${par%%:*}"; horario="${par#*:}"
        usuarios="$(lista_usuarios "$grupo")"
        if [[ -n "$usuarios" ]]; then
            echo "# Grupo $grupo"
            echo "*;*;$usuarios;$horario"
        else
            echo "# Grupo $grupo sin integrantes: sin regla"
        fi
    done
    echo "# END $MARCA"
} >> "$TIME_CONF"

ok "Reglas aplicadas:"
sed -n "/# BEGIN $MARCA/,/# END $MARCA/p" "$TIME_CONF"
info "Hora actual del sistema: $(date '+%A %H:%M')"
