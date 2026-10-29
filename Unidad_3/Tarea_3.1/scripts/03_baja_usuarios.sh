#!/usr/bin/env bash
# =============================================================================
#  03_baja_usuarios.sh - Baja de usuarios en dos modalidades:
#
#    deshabilitar (por defecto): bloquea la contrasena, expira la cuenta,
#                  cambia el shell a nologin y cierra sus procesos.
#                  El home y los archivos se conservan (baja temporal).
#    eliminar:     respalda el home en un .tar.gz y borra la cuenta.
#
#  Uso:
#    sudo bash scripts/03_baja_usuarios.sh [--eliminar] usuario1 usuario2 ...
#    sudo bash scripts/03_baja_usuarios.sh [--eliminar] --csv data/usuarios.csv
#    sudo bash scripts/03_baja_usuarios.sh --reactivar usuario1
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

modo="deshabilitar"
usuarios=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --eliminar)  modo="eliminar" ;;
        --reactivar) modo="reactivar" ;;
        --csv)       shift; CSV_USUARIOS="$1"
                     while IFS=',' read -r u _; do usuarios+=("$u"); done < <(leer_csv) ;;
        -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
        *)           usuarios+=("$1") ;;
    esac
    shift
done

[[ ${#usuarios[@]} -gt 0 ]] || { error "Indica al menos un usuario (o --csv archivo)"; exit 1; }

titulo "Baja de usuarios (modo: $modo)"
for u in "${usuarios[@]}"; do
    if ! id "$u" &>/dev/null; then
        aviso "$u no existe (se omite)"; continue
    fi
    if es_protegido "$u"; then
        error "$u es una cuenta protegida del sistema o tu propio usuario: no se toca"; continue
    fi

    case "$modo" in
        deshabilitar)
            usermod --lock --expiredate 1 --shell /usr/sbin/nologin "$u"
            pkill -KILL -u "$u" 2>/dev/null || true
            ok "$u deshabilitado (contrasena bloqueada, cuenta expirada, shell nologin)"
            ;;
        reactivar)
            usermod --unlock --expiredate "" --shell /bin/bash "$u"
            ok "$u reactivado"
            ;;
        eliminar)
            mkdir -p "$BACKUP_DIR/bajas"
            respaldo="$BACKUP_DIR/bajas/${u}_$(date +%Y%m%d_%H%M%S).tar.gz"
            home="$(getent passwd "$u" | cut -d: -f6)"
            pkill -KILL -u "$u" 2>/dev/null || true
            if [[ -d "$home" ]]; then
                tar -czf "$respaldo" -C "$(dirname "$home")" "$(basename "$home")"
                info "Home respaldado en $respaldo"
            fi
            userdel --remove "$u" 2>/dev/null || userdel "$u"
            ok "$u eliminado"
            ;;
    esac
done

if [[ "$modo" == "eliminar" ]]; then
    aviso "Vuelve a ejecutar 05_horarios_acceso.sh para actualizar las reglas de horario"
fi
