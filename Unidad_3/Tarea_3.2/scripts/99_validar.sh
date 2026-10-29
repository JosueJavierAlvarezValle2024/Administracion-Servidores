#!/usr/bin/env bash
# =============================================================================
#  99_validar.sh - Evidencia de la Tarea 3.2 y pruebas automaticas de
#                  sticky bit, SGID, ACL y cuotas.
#  Uso: sudo bash scripts/99_validar.sh
#  Salida guardada en evidencias/validacion_<fecha>.txt
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

mkdir -p "$BASE_DIR/evidencias"
SALIDA="$BASE_DIR/evidencias/validacion_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$SALIDA") 2>&1

pasaron=0; fallaron=0
probar() {   # probar "descripcion" permitido|denegado usuario comando...
    local desc="$1" esperado="$2" u="$3" r; shift 3
    existe_usuario "$u" || { echo "[OMITIDA] $desc (no existe $u)"; return 0; }
    if como "$u" "$@" >/dev/null 2>&1; then r="permitido"; else r="denegado"; fi
    if [[ "$r" == "$esperado" ]]; then echo -e "${VERDE}[PASA]${NC}  $desc -> $r"; ((pasaron++)) || true
    else echo -e "${ROJO}[FALLA]${NC} $desc -> $r (se esperaba $esperado)"; ((fallaron++)) || true; fi
}

titulo "Discos y montaje"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
grep "$MARCA" /etc/fstab || echo "Sin lineas $MARCA en fstab"
findmnt -no SOURCE,TARGET,OPTIONS "$DIR_EMPRESA" || true

titulo "Permisos especiales (s = SGID, t = sticky)"
find "$DIR_EMPRESA" -maxdepth 2 -type d ! -name lost+found -exec stat -c '%A  %U:%G  %n' {} \; | sort -k3

titulo "ACL"
for d in finanzas finanzas/reportes operaciones operaciones/inventario general buzon_ti; do
    echo "--- $DIR_EMPRESA/$d"; getfacl -pc "$DIR_EMPRESA/$d" 2>/dev/null | sed 's/^/    /'
done

titulo "Pruebas automaticas"
G="$DIR_EMPRESA/general"
como laura.mena bash -c "echo 'aviso de laura' > '$G/aviso_laura.txt'" 2>/dev/null || true
probar "SGID: archivo nuevo en finanzas hereda grupo finanzas" permitido pedro.ruiz \
       bash -c "touch '$DIR_EMPRESA/finanzas/sgid.txt' && [[ \$(stat -c %G '$DIR_EMPRESA/finanzas/sgid.txt') == finanzas ]]"
probar "Sticky: pedro.ruiz LEE el aviso de laura en general"       permitido pedro.ruiz cat "$G/aviso_laura.txt"
probar "Sticky: pedro.ruiz BORRA el aviso de laura"                denegado  pedro.ruiz rm -f "$G/aviso_laura.txt"
probar "Sticky: pedro.ruiz MODIFICA el aviso de laura"             denegado  pedro.ruiz bash -c "echo x >> '$G/aviso_laura.txt'"
probar "Sticky: laura.mena borra su propio aviso"                  permitido laura.mena rm -f "$G/aviso_laura.txt"
probar "ACL grupo: carlos.vega (jefe ope.) lee finanzas/reportes"  permitido carlos.vega cat "$DIR_EMPRESA/finanzas/reportes/reporte_T3.txt"
probar "ACL grupo: carlos.vega escribe en finanzas/reportes"       denegado  carlos.vega touch "$DIR_EMPRESA/finanzas/reportes/x"
probar "ACL grupo: carlos.vega lista finanzas (solo atraviesa)"    denegado  carlos.vega ls "$DIR_EMPRESA/finanzas"
probar "ACL grupo: laura.mena (no jefe) lee finanzas/reportes"     denegado  laura.mena ls "$DIR_EMPRESA/finanzas/reportes"
probar "ACL usuario: pedro.ruiz lee operaciones/inventario"        permitido pedro.ruiz cat "$DIR_EMPRESA/operaciones/inventario/inventario.csv"
probar "ACL usuario: pedro.ruiz lista operaciones"                 denegado  pedro.ruiz ls "$DIR_EMPRESA/operaciones"
probar "ACL usuario: sofia.diaz lee operaciones/inventario"        denegado  sofia.diaz ls "$DIR_EMPRESA/operaciones/inventario"
probar "ACL auditoria: ana.torres (admin_ti) lista finanzas"       permitido ana.torres ls "$DIR_EMPRESA/finanzas"
probar "ACL auditoria: ana.torres escribe en finanzas"             denegado  ana.torres touch "$DIR_EMPRESA/finanzas/ana.txt"
probar "Buzon: laura.mena deposita un archivo en buzon_ti"         permitido laura.mena bash -c "echo ticket > '$DIR_EMPRESA/buzon_ti/ticket_laura.txt'"
probar "Buzon: laura.mena lista buzon_ti"                          denegado  laura.mena ls "$DIR_EMPRESA/buzon_ti"
probar "Buzon: luis.rios (sistemas) lista buzon_ti"                permitido luis.rios ls "$DIR_EMPRESA/buzon_ti"
probar "Herencia: el ticket de laura es legible por sistemas"      permitido luis.rios cat "$DIR_EMPRESA/buzon_ti/ticket_laura.txt"
probar "Cuota: sofia.diaz escribe 40 MB (bajo el limite)"          permitido sofia.diaz dd if=/dev/zero of="$DIR_EMPRESA/finanzas/cuota_ok.bin" bs=1M count=40 status=none
probar "Cuota: sofia.diaz escribe 30 MB mas (supera 60 MB duro)"   denegado  sofia.diaz dd if=/dev/zero of="$DIR_EMPRESA/finanzas/cuota_excede.bin" bs=1M count=30 status=none

titulo "Cuota de sofia.diaz durante la prueba"
quota -us sofia.diaz 2>/dev/null || true
rm -f "$DIR_EMPRESA"/finanzas/{sgid.txt,cuota_ok.bin,cuota_excede.bin} "$DIR_EMPRESA/buzon_ti/ticket_laura.txt"

titulo "Reporte de cuotas"
repquota -us "$DIR_EMPRESA" 2>/dev/null | sed -n '1,30p' || echo "Cuotas no activas"
repquota -gs "$DIR_EMPRESA" 2>/dev/null | sed -n '1,20p' || true

titulo "Respaldos"
ls -l /usr/local/sbin/backup.sh /usr/local/sbin/restaurar.sh 2>/dev/null || echo "No instalados"
grep -hv '^\s*#' /etc/cron.d/tarea32-* 2>/dev/null | grep -v '^\s*$' || echo "Sin cron"
command -v restaurar.sh >/dev/null && restaurar.sh --listar 2>/dev/null || true
cat /var/lib/tarea32/ultimo_estado 2>/dev/null || true
echo "--- Ultimas lineas del log"
tail -n 15 /var/log/tarea32_backup.log 2>/dev/null || true

titulo "Resultado"
echo "Pruebas que pasaron: $pasaron   Pruebas que fallaron: $fallaron"
echo "Evidencia: $SALIDA"
