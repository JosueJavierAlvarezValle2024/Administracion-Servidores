#!/usr/bin/env bash
# =============================================================================
#  02_alta_usuarios.sh - Alta de usuarios POR LOTES desde un archivo CSV.
#
#  Por cada usuario:
#    - Crea la cuenta con home propio (/home/usuario) en modo 700 (privado)
#    - Grupo primario  = su departamento
#    - Grupos secundarios = empleados + rol (jefes/admin_ti) + grupos_extra
#    - Contrasena temporal aleatoria y CAMBIO OBLIGATORIO en el primer acceso
#    - Caducidad de contrasena (90 dias) y fecha de expiracion de la cuenta
#
#  Uso: sudo bash scripts/02_alta_usuarios.sh [archivo.csv]
#  Formato CSV: usuario,nombre_completo,departamento,rol,grupos_extra,expira_cuenta
#               (grupos_extra separados por ';'   expira_cuenta = AAAA-MM-DD)
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
[[ -n "${1:-}" ]] && CSV_USUARIOS="$1"

# Genera una contrasena temporal de 12 caracteres + sufijo con simbolo y numero
generar_password() {
    local p
    p="$(openssl rand -base64 18 2>/dev/null | tr -d '/+=' | cut -c1-12)" || true
    [[ ${#p} -ge 12 ]] || p="$(date +%s%N | sha256sum | cut -c1-12)"
    echo "${p}#7"
}

# Archivo de credenciales: solo root puede leerlo
if [[ ! -f "$CRED_FILE" ]]; then
    echo "usuario,password_temporal,fecha_alta" > "$CRED_FILE"
fi
chmod 600 "$CRED_FILE"

titulo "Alta de usuarios desde $CSV_USUARIOS"
creados=0; omitidos=0; errores=0

# Se lee por el descriptor 3 para que ningun comando del ciclo "consuma" el CSV
while IFS=',' read -r -u 3 usuario nombre depto rol extras expira; do
    # ---- Validaciones de cada fila ----
    if [[ ! "$usuario" =~ ^[a-z][a-z0-9._-]{0,31}$ ]]; then
        error "Nombre de usuario invalido: '$usuario'"; ((errores++)) || true; continue
    fi
    if [[ ! " ${DEPARTAMENTOS[*]} " == *" $depto "* ]]; then
        error "$usuario: departamento desconocido '$depto'"; ((errores++)) || true; continue
    fi
    if ! date -d "$expira" +%F >/dev/null 2>&1; then
        error "$usuario: fecha de expiracion invalida '$expira'"; ((errores++)) || true; continue
    fi

    # ---- Grupos secundarios segun el rol ----
    secundarios="empleados"
    [[ "$rol" == "jefe" ]] && secundarios+=",jefes"
    [[ "$rol" == "jefe" && "$depto" == "sistemas" ]] && secundarios+=",admin_ti"
    if [[ -n "$extras" ]]; then
        for g in ${extras//;/ }; do
            if getent group "$g" >/dev/null; then secundarios+=",$g"
            else aviso "$usuario: el grupo extra '$g' no existe (se omite)"; fi
        done
    fi

    # ---- Si ya existe, solo se actualizan sus grupos ----
    if id "$usuario" &>/dev/null; then
        usermod -aG "$secundarios" "$usuario"
        aviso "$usuario ya existia: grupos actualizados ($secundarios)"
        ((omitidos++)) || true
        continue
    fi

    # ---- Creacion de la cuenta ----
    useradd \
        --create-home \
        --shell /bin/bash \
        --comment "$nombre,$depto,$rol" \
        --gid "$depto" \
        --groups "$secundarios" \
        "$usuario"

    # Home privado: solo el propio usuario puede entrar
    chmod 700 "/home/$usuario"

    # Archivo de bienvenida dentro del home
    cat > "/home/$usuario/LEEME.txt" <<EOF
Bienvenido(a) $nombre
Departamento : $depto
Rol          : $rol
Carpeta de tu area : $DIR_EMPRESA/$depto
Carpeta general    : $DIR_EMPRESA/general
Tu home (/home/$usuario) es privado: ningun otro usuario puede verlo.
EOF
    chown "$usuario:$depto" "/home/$usuario/LEEME.txt"

    # ---- Contrasena temporal ----
    pass="$(generar_password)"
    echo "$usuario:$pass" | chpasswd
    echo "$usuario,$pass,$(date +%F)" >> "$CRED_FILE"

    # ---- Politica de caducidad ----
    #  -d 0  -> la contrasena se marca como vencida: debe cambiarla al entrar
    #  -M/-m/-W/-I -> maximo, minimo, aviso e inactividad (dias)
    #  -E    -> fecha en que la CUENTA deja de funcionar
    chage -d 0 \
          -M "$PASS_MAX_DIAS" -m "$PASS_MIN_DIAS" \
          -W "$PASS_AVISO_DIAS" -I "$PASS_INACTIVO" \
          -E "$expira" "$usuario"

    ok "$usuario creado | primario: $depto | secundarios: $secundarios | expira: $expira"
    ((creados++)) || true
done 3< <(leer_csv)

titulo "Resumen"
echo "Creados: $creados   Ya existian: $omitidos   Con error: $errores"
echo "Contrasenas temporales guardadas en: $CRED_FILE  (ver con: sudo cat $CRED_FILE)"
