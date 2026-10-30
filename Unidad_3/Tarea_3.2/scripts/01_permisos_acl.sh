#!/usr/bin/env bash
# =============================================================================
#  01_permisos_acl.sh - Permisos POSIX especiales y ACL con herencia
#
#  Carpeta                     Modo  Que demuestra
#  --------------------------  ----  ------------------------------------------
#  /srv/empresa/<depto>        2770  SGID: los archivos heredan el grupo del depto
#                                    ACL: admin_ti solo lectura (auditoria)
#  /srv/empresa/general        3770  Sticky + SGID: todos escriben, pero solo el
#                                    dueno puede borrar o modificar su archivo
#  /srv/empresa/direccion      2770  Solo jefes
#  /srv/empresa/buzon_ti       3770  ACL g:empleados -wx: todos DEPOSITAN
#                                    archivos pero NO pueden listar la carpeta
#  finanzas/reportes           2770  ACL g:jefes r-x: jefes de otras areas leen
#  operaciones/inventario      2770  ACL u:pedro.ruiz r-x (+ --x en operaciones
#                                    para atravesar sin poder listar)
#
#  "Herencia" = ACL por defecto (setfacl -d): todo lo que se cree dentro
#  recibe automaticamente esos permisos.
#
#  Uso: sudo bash scripts/01_permisos_acl.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
requiere_tarea31
instalar_paquetes acl

# Aplica dueno, modo y (opcional) limpia ACL previas
base() {
    local ruta="$1" dueno="$2" modo="$3"
    mkdir -p "$ruta"
    setfacl -b "$ruta"          # quitar ACL anteriores para aplicar desde cero
    chown "$dueno" "$ruta"
    # Se antepone un 0 (ej. 02770): en directorios, GNU chmod con 4 digitos
    # conserva un setuid previo; con 5 digitos lo quita explicitamente
    chmod "0$modo" "$ruta"
}

mostrar() { echo; stat -c '%A  %U:%G  %n' "$1"; getfacl -pc "$1" | sed 's/^/    /'; }

titulo "Carpetas de departamento (SGID + ACL de auditoria)"
for d in "${DEPARTAMENTOS[@]}"; do
    ruta="$DIR_EMPRESA/$d"
    base "$ruta" "root:$d" 2770
    # Acceso actual: admin_ti lee y atraviesa (X = x solo en carpetas)
    setfacl -R -m "g:admin_ti:rX" "$ruta"
    # Herencia: lo nuevo sera rwx para el depto, r-x para admin_ti, nada para otros
    setfacl -d -m "u::rwx,g::rwx,g:$d:rwx,g:admin_ti:r-x,o::---" "$ruta"
    mostrar "$ruta"
done

titulo "Carpeta general (sticky bit + SGID)"
ruta="$DIR_EMPRESA/general"
base "$ruta" "root:empleados" 3770
# Herencia: el dueno escribe, el resto del grupo solo lee
setfacl -d -m "u::rwx,g::r-x,o::---" "$ruta"
mostrar "$ruta"

titulo "Carpeta de direccion (solo jefes)"
ruta="$DIR_EMPRESA/direccion"
base "$ruta" "root:jefes" 2770
setfacl -d -m "u::rwx,g::rwx,o::---" "$ruta"
mostrar "$ruta"

titulo "Buzon de TI (depositar sin poder listar)"
ruta="$DIR_EMPRESA/buzon_ti"
base "$ruta" "root:sistemas" 3770
setfacl -m "g:empleados:-wx" "$ruta"                  # escribir y entrar, sin leer
setfacl -d -m "u::rw-,g::rw-,g:sistemas:rw-,o::---" "$ruta"
mostrar "$ruta"

titulo "finanzas/reportes (ACL de grupo: jefes leen)"
ruta="$DIR_EMPRESA/finanzas/reportes"
base "$ruta" "root:finanzas" 2770
# Para llegar a reportes, los jefes deben poder ATRAVESAR finanzas (x) sin listarla
setfacl -m "g:jefes:--x" "$DIR_EMPRESA/finanzas"
setfacl -m "g:jefes:r-x,g:admin_ti:r-x" "$ruta"
setfacl -d -m "u::rwx,g::rwx,g:finanzas:rwx,g:jefes:r-x,g:admin_ti:r-x,o::---" "$ruta"
echo "Reporte trimestral de ejemplo - $(date +%F)" > "$ruta/reporte_T3.txt"
chgrp finanzas "$ruta/reporte_T3.txt"
mostrar "$ruta"

titulo "operaciones/inventario (ACL de usuario: pedro.ruiz audita)"
ruta="$DIR_EMPRESA/operaciones/inventario"
base "$ruta" "root:operaciones" 2770
if existe_usuario pedro.ruiz; then
    setfacl -m "u:pedro.ruiz:--x" "$DIR_EMPRESA/operaciones"
    setfacl -m "u:pedro.ruiz:r-x" "$ruta"
    setfacl -d -m "u::rwx,g::rwx,u:pedro.ruiz:r-x,g:admin_ti:r-x,o::---" "$ruta"
else
    aviso "pedro.ruiz no existe: se omite la ACL de usuario"
fi
echo "Inventario de ejemplo - $(date +%F)" > "$ruta/inventario.csv"
chgrp operaciones "$ruta/inventario.csv"
mostrar "$ruta"

ok "Permisos y ACL aplicados"
