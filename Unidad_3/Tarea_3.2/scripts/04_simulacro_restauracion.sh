#!/usr/bin/env bash
# =============================================================================
#  04_simulacro_restauracion.sh - Prueba de recuperacion de archivos borrados
#
#   1. Crea archivos de prueba en finanzas (como pedro.ruiz) y guarda su SHA-256
#   2. Ejecuta un respaldo (incremental)
#   3. BORRA los archivos
#   4. Los restaura en su ubicacion original con restaurar.sh
#   5. Compara contenido, dueno, permisos y ACL -> PASA / FALLA
#   6. Mide el tiempo de recuperacion (evidencia para el RTO)
#
#  Uso: sudo bash scripts/04_simulacro_restauracion.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
command -v backup.sh >/dev/null || { error "Instala primero: sudo bash scripts/03_instalar_respaldos.sh"; exit 1; }

USUARIO="pedro.ruiz"
existe_usuario "$USUARIO" || USUARIO="root"
CARPETA="$DIR_EMPRESA/finanzas/simulacro"
EVID="$BASE_DIR/evidencias"; mkdir -p "$EVID"
SALIDA="$EVID/simulacro_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$SALIDA") 2>&1

titulo "1. Crear archivos de prueba como $USUARIO"
mkdir -p "$CARPETA"; chown "$USUARIO:finanzas" "$CARPETA"
como "$USUARIO" bash -c "
    echo 'Nomina octubre - documento critico - $(date)' > '$CARPETA/nomina_octubre.txt'
    head -c 2M /dev/urandom > '$CARPETA/estado_financiero.bin'
"
ls -la "$CARPETA"
ANTES="$(cd "$CARPETA" && sha256sum ./* && stat -c '%n %U:%G %a' ./* && getfacl -c ./* 2>/dev/null)"
echo "$ANTES" > /tmp/simulacro_antes.txt

titulo "2. Respaldo"
backup.sh incremental

titulo "3. Borrado accidental"
rm -rf "$CARPETA"
ls -la "$DIR_EMPRESA/finanzas/" ; [[ ! -e "$CARPETA" ]] && echo ">>> La carpeta $CARPETA YA NO EXISTE"

titulo "4. Restauracion"
T0=$(date +%s)
restaurar.sh --ultimo --ruta "${CARPETA#/}" --en-sitio --si
T1=$(date +%s)

titulo "5. Comparacion"
ls -la "$CARPETA"
DESPUES="$(cd "$CARPETA" && sha256sum ./* && stat -c '%n %U:%G %a' ./* && getfacl -c ./* 2>/dev/null)"
if [[ "$ANTES" == "$DESPUES" ]]; then
    echo -e "${VERDE}[PASA]${NC} Contenido (SHA-256), dueno, permisos y ACL identicos al original"
    RES="EXITOSO"
else
    echo -e "${ROJO}[FALLA]${NC} Hay diferencias:"
    diff <(echo "$ANTES") <(echo "$DESPUES") || true
    RES="FALLIDO"
fi

titulo "6. Resultado"
echo "Simulacro: $RES"
echo "Tiempo de recuperacion medido: $((T1 - T0)) segundos"
echo "Evidencia: $SALIDA"
rm -f /tmp/simulacro_antes.txt
