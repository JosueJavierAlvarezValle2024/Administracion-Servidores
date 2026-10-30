#!/usr/bin/env bash
# =============================================================================
#  02_cuotas.sh - Cuotas de disco por USUARIO y por GRUPO en /srv/empresa
#
#  Limite blando (soft): se puede superar durante el periodo de gracia.
#  Limite duro  (hard) : nunca se puede superar ("Disk quota exceeded").
#
#  Las cuotas de grupo funcionan junto con el SGID de las carpetas: todo lo
#  que se guarda en /srv/empresa/finanzas pertenece al grupo finanzas y
#  cuenta para la cuota de ese grupo.
#
#  Uso: sudo bash scripts/02_cuotas.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
requiere_tarea31
instalar_paquetes quota

FS="$DIR_EMPRESA"
MB=1024   # setquota usa bloques de 1 KB

# ---- Limites (MB) : blando duro    inodos: blando duro ----
CUOTA_EMPLEADO=(50 60 2000 2500)
CUOTA_JEFE=(100 120 4000 5000)
declare -A CUOTA_GRUPO=(
    [sistemas]="400 500"
    [finanzas]="300 350"
    [operaciones]="300 350"
    [empleados]="200 250"     # carpeta general y buzon
    [jefes]="100 150"         # carpeta de direccion
)
GRACIA=86400   # periodo de gracia: 1 dia (segundos)

mountpoint -q "$FS" || { error "$FS no es un disco montado: ejecuta 00_preparar_discos.sh"; exit 1; }
# Estado de las cuotas. Notas:
#  - LC_ALL=C: mensaje en ingles ("is on") sin importar el idioma del sistema
#  - quotaon -p devuelve codigo distinto de 0 cuando las cuotas ESTAN activas,
#    por eso se guarda la salida y solo se revisa el texto
estado_cuotas() { LC_ALL=C quotaon -pug "$FS" 2>&1 || true; }
if ! estado_cuotas | grep -q 'user quota.* is on'; then
    quotaon -ug "$FS" 2>/dev/null || true
fi
ESTADO="$(estado_cuotas)"
echo "$ESTADO"
grep -q 'user quota.* is on' <<< "$ESTADO" && grep -q 'group quota.* is on' <<< "$ESTADO" \
    || { error "Las cuotas no estan activas en $FS"; exit 1; }

titulo "Periodo de gracia"
setquota -u -t "$GRACIA" "$GRACIA" "$FS"
setquota -g -t "$GRACIA" "$GRACIA" "$FS"
ok "Gracia de $((GRACIA/3600)) horas para usuarios y grupos"

titulo "Cuotas por usuario"
while read -r u; do
    [[ -n "$u" ]] || continue
    if id -nG "$u" | tr ' ' '\n' | grep -qx jefes; then c=("${CUOTA_JEFE[@]}"); rol="jefe"
    else c=("${CUOTA_EMPLEADO[@]}"); rol="empleado"; fi
    setquota -u "$u" $((c[0]*MB)) $((c[1]*MB)) "${c[2]}" "${c[3]}" "$FS"
    ok "$(printf '%-13s %-9s %4s MB / %4s MB   inodos %s / %s' "$u" "$rol" "${c[0]}" "${c[1]}" "${c[2]}" "${c[3]}")"
done < <(miembros_grupo empleados)

titulo "Cuotas por grupo"
for g in "${!CUOTA_GRUPO[@]}"; do
    read -r blando duro <<< "${CUOTA_GRUPO[$g]}"
    setquota -g "$g" $((blando*MB)) $((duro*MB)) 0 0 "$FS"
    ok "$(printf '%-12s %4s MB / %4s MB' "$g" "$blando" "$duro")"
done

titulo "Reporte de cuotas (repquota)"
# -v: muestra tambien a quien aun no tiene archivos en el disco
repquota -usv "$FS" | sed -n '1,40p'
echo
repquota -gsv "$FS" | sed -n '1,40p'

info "Consultar a un usuario:  sudo quota -us <usuario>"
