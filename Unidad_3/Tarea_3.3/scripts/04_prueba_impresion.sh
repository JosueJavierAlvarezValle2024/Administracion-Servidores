#!/usr/bin/env bash
# =============================================================================
#  04_prueba_impresion.sh - Demuestra las prioridades y los permisos de las
#  colas de impresion.
#
#   1. Pausa la cola PDF_General y envia 3 trabajos con prioridad 10, 50 y 90
#   2. Muestra la cola: el de prioridad 90 queda primero aunque llego ultimo
#   3. Reanuda la cola y muestra el orden en que se imprimieron
#   4. Prueba permisos: laura.mena (operaciones) NO puede usar PDF_Finanzas;
#      pedro.ruiz (finanzas) SI
#
#  Los PDF generados quedan en ~/PDF del usuario que ejecuta el script.
#  Uso: sudo bash scripts/04_prueba_impresion.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

USUARIO="${SUDO_USER:-root}"
COLA="PDF_General"
lpstat -p "$COLA" &>/dev/null || { error "No existe $COLA: ejecuta 03_impresion_cups.sh"; exit 1; }
mkdir -p "$BASE_DIR/evidencias"
SALIDA="$BASE_DIR/evidencias/impresion_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$SALIDA") 2>&1

DOC="$(mktemp --suffix=.txt)"; chmod 644 "$DOC"
trap 'rm -f "$DOC"' EXIT

titulo "1. Cola pausada y 3 trabajos con distinta prioridad"
cupsdisable "$COLA"
for p in 10 50 90; do
    case $p in 10) n="BAJA";; 50) n="NORMAL";; 90) n="ALTA";; esac
    printf 'Prueba de prioridad %s (%s)\nEnviado: %s\nServidor: %s\n' "$n" "$p" "$(date '+%F %T')" "$(hostname)" > "$DOC"
    como "$USUARIO" lp -d "$COLA" -o job-priority="$p" -t "prioridad_${n}_${p}" "$DOC"
    sleep 1
done

titulo "2. Orden en la cola (rank 1 = se imprime primero)"
lpq -P "$COLA"

titulo "3. Reanudar la cola"
cupsenable "$COLA"
for _ in $(seq 1 20); do
    [[ -z "$(lpstat -o "$COLA" 2>/dev/null)" ]] && break
    sleep 1
done
echo "Trabajos completados (los mas recientes primero):"
lpstat -W completed -o "$COLA" | head -n 3 || true
HOME_U="$(getent passwd "$USUARIO" | cut -d: -f6)"
echo
echo "PDF generados en $HOME_U/PDF:"
ls -lt "$HOME_U/PDF" 2>/dev/null | head -n 4 || echo "(aun no aparecen)"

titulo "4. Permisos por cola"
probar_cola() {   # probar_cola <usuario> <cola> <esperado>
    local u="$1" c="$2" esperado="$3" r
    existe_usuario "$u" || { echo "[OMITIDA] $u no existe"; return 0; }
    # -H hold: el trabajo queda retenido y luego se cancela (no genera PDF)
    if id_trabajo="$(como "$u" lp -d "$c" -H hold -t "permiso_$u" /etc/hostname 2>&1)"; then
        r="permitido"; cancel "$(echo "$id_trabajo" | grep -oE "$c-[0-9]+")" 2>/dev/null || true
    else r="denegado"; fi
    if [[ "$r" == "$esperado" ]]; then echo -e "${VERDE}[PASA]${NC}  $u -> $c: $r"
    else echo -e "${ROJO}[FALLA]${NC} $u -> $c: $r (se esperaba $esperado)"; fi
}
probar_cola pedro.ruiz  PDF_Finanzas  permitido
probar_cola laura.mena  PDF_Finanzas  denegado
probar_cola carlos.vega PDF_Direccion permitido
probar_cola laura.mena  PDF_Direccion denegado
probar_cola laura.mena  PDF_General   permitido

echo
echo "Evidencia: $SALIDA"
