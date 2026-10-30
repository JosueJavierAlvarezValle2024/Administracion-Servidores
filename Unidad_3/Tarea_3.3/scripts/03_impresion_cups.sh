#!/usr/bin/env bash
# =============================================================================
#  03_impresion_cups.sh - Servidor de impresion CUPS con impresoras virtuales
#  PDF (cups-pdf), colas por area, prioridades, cuotas y comparticion por red.
#
#  Cola            Quien puede imprimir        Prioridad   Cuota
#  -------------   -------------------------   ---------   ----------------
#  PDF_General     todos (incluso desde red)   50          sin limite
#  PDF_Finanzas    finanzas, jefes, admin_ti   50          100 paginas/dia
#  PDF_Direccion   solo jefes                  90 (alta)   sin limite
#  Clase "Oficina" = PDF_General + PDF_Finanzas (reparte trabajos entre ambas)
#
#  Prioridad (job-priority 1-100): en una misma cola se imprime primero el
#  trabajo con numero mayor.
#  Los PDF quedan en ~/PDF del usuario que imprime; los trabajos que llegan
#  por red sin usuario local, en /var/spool/cups-pdf/ANONYMOUS.
#
#  Uso: sudo bash scripts/03_impresion_cups.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
requiere_tarea31

instalar_paquetes cups printer-driver-cups-pdf
systemctl enable --now cups >/dev/null 2>&1

titulo "Controladores (drivers) disponibles"
lpinfo -m 2>/dev/null | grep -i 'cups-pdf' || true
PPD="$(lpinfo -m 2>/dev/null | awk 'tolower($0) ~ /cups-pdf/ {print $1; exit}')"
[[ -n "$PPD" ]] || { error "No se encontro el controlador de cups-pdf"; exit 1; }
ok "Controlador elegido: $PPD"
info "Dispositivos (backends): $(lpinfo -v 2>/dev/null | grep -o 'cups-pdf:/' | head -n1)"

# crear_cola <nombre> <descripcion> <prioridad> <permitidos|todos> [opciones extra...]
crear_cola() {
    local nombre="$1" desc="$2" prio="$3" permitidos="$4"; shift 4
    # Si la cola ya existe, se quita su restriccion de usuarios y se borra
    lpadmin -p "$nombre" -u allow:all 2>/dev/null || true
    lpadmin -x "$nombre" 2>/dev/null || true
    lpadmin -p "$nombre" -E -v cups-pdf:/ -m "$PPD" \
            -D "$desc" -L "Servidor Xubuntu - $DIR_COMPARTIDO" \
            -o printer-is-shared=true \
            -o job-priority-default="$prio" "$@" 2>&1 | grep -v 'deprecated' || true
    # Activar y aceptar trabajos ANTES de restringir usuarios
    cupsenable "$nombre"; cupsaccept "$nombre"
    # La lista de permitidos tambien aplica a root: se incluye para que pueda
    # administrar la cola y cancelar trabajos
    if [[ "$permitidos" == "todos" ]]; then
        lpadmin -p "$nombre" -u allow:all
    else
        lpadmin -p "$nombre" -u "allow:root,$permitidos"
    fi
    lpstat -p "$nombre" &>/dev/null || { error "No se pudo crear la cola $nombre"; exit 1; }
    ok "Cola $nombre | prioridad $prio | permitidos: $permitidos"
}

titulo "Colas de impresion"
crear_cola PDF_General   "Impresora PDF general"         50 todos
crear_cola PDF_Finanzas  "Impresora PDF de Finanzas"     50 "@finanzas,@jefes,@admin_ti" \
           -o job-quota-period=86400 -o job-page-limit=100
crear_cola PDF_Direccion "Impresora PDF de Direccion"    90 "@jefes"

titulo "Clase de impresoras"
lpadmin -x Oficina 2>/dev/null || true
lpadmin -p PDF_General -c Oficina
lpadmin -p PDF_Finanzas -c Oficina
cupsenable Oficina; cupsaccept Oficina
lpadmin -p Oficina -o printer-is-shared=true
ok "Clase Oficina = PDF_General + PDF_Finanzas"

lpadmin -d PDF_General
ok "Destino predeterminado: PDF_General"

titulo "Compartir por red (IPP, puerto 631)"
respaldar /etc/cups/cupsd.conf
# --share-printers : publica las colas compartidas a la red local
# --remote-admin   : permite abrir la administracion web desde la red local
cupsctl --share-printers --remote-admin
systemctl restart cups
permitir_firewall 631
cupsctl | grep -E '_share_printers|_remote_admin'

titulo "Estado"
lpstat -t | head -n 30 || true
IP="$(IP_SERVIDOR)"
echo
echo "Administracion web:      http://${IP:-192.168.56.101}:631"
echo "Impresora para Windows:  http://${IP:-192.168.56.101}:631/printers/PDF_General"
