#!/usr/bin/env bash
# =============================================================================
#  99_validar.sh - Genera la evidencia de validacion (para capturas y video).
#
#  Muestra grupos, cuentas, caducidad, permisos de homes, reglas de sudo,
#  horarios y bloqueo; y ejecuta PRUEBAS AUTOMATICAS de aislamiento
#  (cada prueba se ejecuta como el usuario indicado con setpriv).
#
#  Uso: sudo bash scripts/99_validar.sh
#  La salida tambien se guarda en evidencias/validacion_<fecha>.txt
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

mkdir -p "$BASE_DIR/evidencias"
SALIDA="$BASE_DIR/evidencias/validacion_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$SALIDA") 2>&1

pasaron=0; fallaron=0

# Ejecuta un comando como otro usuario (sin pedir contrasena, sin PAM)
como() {
    local u="$1"; shift
    setpriv --reuid="$u" --regid="$(id -gn "$u")" --init-groups -- "$@"
}

# probar "descripcion" permitido|denegado usuario comando...
probar() {
    local desc="$1" esperado="$2" u="$3"; shift 3
    local resultado
    if como "$u" "$@" >/dev/null 2>&1; then resultado="permitido"; else resultado="denegado"; fi
    if [[ "$resultado" == "$esperado" ]]; then
        echo -e "${VERDE}[PASA]${NC} $desc -> $resultado"; ((pasaron++)) || true
    else
        echo -e "${ROJO}[FALLA]${NC} $desc -> $resultado (se esperaba: $esperado)"; ((fallaron++)) || true
    fi
}

titulo "Sistema"
echo "Equipo: $(hostname)   Fecha: $(date)"
grep PRETTY_NAME /etc/os-release
sudo --version 2>/dev/null | head -n1

titulo "Grupos"
for entrada in "${GRUPOS[@]}"; do
    g="${entrada%%:*}"
    printf '%-15s GID %-6s miembros: %s\n' "$g" "$(getent group "$g" | cut -d: -f3)" \
        "$(miembros_grupo "$g" | paste -sd',' -)"
done

titulo "Usuarios, grupos y caducidad"
while IFS=',' read -r -u 3 u _; do
    id "$u" &>/dev/null || { echo "$u: NO EXISTE"; continue; }
    echo "--- $u"
    id "$u"
    chage -l "$u" | grep -E 'ltimo cambio|Last password|caduca|expires|M.ximo|Maximum'
    stat -c 'home: %A %U:%G %n' "$(getent passwd "$u" | cut -d: -f6)"
done 3< <(leer_csv)

titulo "Carpetas compartidas"
ls -ld "$DIR_EMPRESA"/*

titulo "Privilegios sudo por usuario"
while IFS=',' read -r -u 3 u _; do
    id "$u" &>/dev/null || continue
    echo "--- $u"
    sudo -l -U "$u" 2>&1 | grep -v '^[[:space:]]*$' | tail -n 8 || true
done 3< <(leer_csv)

titulo "Horarios de acceso (time.conf)"
sed -n "/# BEGIN $MARCA/,/# END $MARCA/p" /etc/security/time.conf 2>/dev/null || echo "Sin reglas"
grep -l "pam_time.so.*$MARCA" /etc/pam.d/* 2>/dev/null | sed 's/^/pam_time activo en: /'

titulo "Bloqueo por intentos fallidos"
sed -n "/# BEGIN $MARCA/,/# END $MARCA/p" /etc/security/faillock.conf 2>/dev/null
grep -n pam_faillock /etc/pam.d/common-auth /etc/pam.d/common-account 2>/dev/null || echo "pam_faillock NO activo"

titulo "Pruebas automaticas de aislamiento y permisos"
existe() { id "$1" &>/dev/null; }
if existe pedro.ruiz && existe laura.mena && existe maria.lopez; then
    probar "pedro.ruiz (finanzas) lee su propio home"              permitido pedro.ruiz ls /home/pedro.ruiz
    probar "pedro.ruiz (finanzas) entra al home de laura.mena"     denegado  pedro.ruiz ls /home/laura.mena
    probar "laura.mena (operaciones) lee LEEME de pedro.ruiz"      denegado  laura.mena cat /home/pedro.ruiz/LEEME.txt
    probar "pedro.ruiz escribe en carpeta de finanzas"             permitido pedro.ruiz touch "$DIR_EMPRESA/finanzas/prueba_pedro.txt"
    probar "pedro.ruiz escribe en carpeta de operaciones"          denegado  pedro.ruiz touch "$DIR_EMPRESA/operaciones/prueba_pedro.txt"
    probar "laura.mena lista carpeta de finanzas"                  denegado  laura.mena ls "$DIR_EMPRESA/finanzas"
    probar "laura.mena escribe en carpeta general"                 permitido laura.mena touch "$DIR_EMPRESA/general/prueba_laura.txt"
    probar "laura.mena (no jefe) entra a direccion"                denegado  laura.mena ls "$DIR_EMPRESA/direccion"
    probar "maria.lopez (jefe) entra a direccion"                  permitido maria.lopez ls "$DIR_EMPRESA/direccion"
    probar "pedro.ruiz lee /etc/shadow"                            denegado  pedro.ruiz cat /etc/shadow
    rm -f "$DIR_EMPRESA"/finanzas/prueba_pedro.txt "$DIR_EMPRESA"/general/prueba_laura.txt
else
    aviso "Faltan usuarios de ejemplo: ejecuta primero 02_alta_usuarios.sh"
fi

titulo "Resultado"
echo "Pruebas que pasaron: $pasaron   Pruebas que fallaron: $fallaron"
echo "Evidencia guardada en: $SALIDA"
