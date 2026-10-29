#!/usr/bin/env bash
# =============================================================================
#  01_crear_grupos.sh - Crea los grupos departamentales y de rol, y las
#                       carpetas compartidas de cada departamento.
#  Uso: sudo bash scripts/01_crear_grupos.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

titulo "Creacion de grupos"
for entrada in "${GRUPOS[@]}"; do
    grupo="${entrada%%:*}"
    gid="${entrada##*:}"
    if getent group "$grupo" >/dev/null; then
        aviso "El grupo '$grupo' ya existe (se omite)"
    elif getent group "$gid" >/dev/null; then
        # El GID sugerido esta ocupado: se deja que el sistema asigne uno
        groupadd "$grupo"
        ok "Grupo '$grupo' creado (GID automatico, $gid estaba ocupado)"
    else
        groupadd -g "$gid" "$grupo"
        ok "Grupo '$grupo' creado con GID $gid"
    fi
done

titulo "Carpetas compartidas en $DIR_EMPRESA"
# Permisos 2770:
#   2   = setgid: los archivos nuevos heredan el grupo de la carpeta
#   770 = dueno y grupo con rwx, el resto SIN acceso (aislamiento)
mkdir -p "$DIR_EMPRESA"
chown root:root "$DIR_EMPRESA"
chmod 755 "$DIR_EMPRESA"

crear_carpeta() {
    local ruta="$1" grupo="$2"
    mkdir -p "$ruta"
    chown root:"$grupo" "$ruta"
    chmod 2770 "$ruta"
    ok "$(stat -c '%A %U:%G %n' "$ruta")"
}

for depto in "${DEPARTAMENTOS[@]}"; do
    crear_carpeta "$DIR_EMPRESA/$depto" "$depto"
done
crear_carpeta "$DIR_EMPRESA/general"   empleados   # todos los empleados
crear_carpeta "$DIR_EMPRESA/direccion" jefes       # solo jefes de area

ok "Estructura de grupos lista"
