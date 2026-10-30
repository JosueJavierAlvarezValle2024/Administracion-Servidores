# Guion del video — Tarea 3.3 (≈ 10 min)

## Antes de grabar

- Snapshot de la VM ("3.3 lista").
- Ya debe estar aplicado: `00_crear_raid.sh`, `02_compartir_samba_nfs.sh` y `03_impresion_cups.sh`.
- En Windows, ten agregada la impresora `PDF_General` (ver README) y abierto el Explorador de archivos.
- OBS: captura de **pantalla completa**, para mostrar la VM y Windows.
- Terminal con letra grande. Video sin audio: escribe letreros con `#` antes de cada paso.
- Si te equivocas, usa **Pausar grabación** en OBS.

## Pasos

| # | Qué mostrar | Comandos / acciones |
|---|---|---|
| 1 | Presentación | `# TAREA 3.3 - RAID 5, Samba/NFS y servidor de impresion CUPS` |
| 2 | Discos del arreglo | `lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS` |
| 3 | **Estado del RAID** | `cat /proc/mdstat` · `sudo mdadm --detail /dev/md0` (señala *State : clean* y los 3 discos *active sync*) |
| 4 | Persistencia | `grep ARRAY /etc/mdadm/mdadm.conf` · `grep TAREA33 /etc/fstab` · `df -h /srv/raid` |
| 5 | **Simulación de desconexión** | `sudo bash scripts/01_simular_fallo.sh --fallo` (señala *clean, degraded*, `[3/2] [U_U]` y "DATOS INTACTOS") |
| 6 | Los datos siguen accesibles | `ls -lh /srv/raid/compartido/general` |
| 7 | **Reconstrucción** | `sudo bash scripts/01_simular_fallo.sh --reconstruir` (se ve el % de *recovery* hasta terminar) |
| 8 | Logs de degradación y reconstrucción | `ls logs/` · `cat logs/degradacion_*.log` |
| 9 | Configuración de Samba y NFS | `testparm -s` · `sudo exportfs -v` |
| 10 | **Carpeta de red desde Windows** | Explorador → `\\192.168.56.101\finanzas` con `pedro.ruiz` → crear un archivo · intentar `\\192.168.56.101\operaciones` → acceso denegado |
| 11 | Archivo creado desde Windows, visto en la VM | `ls -l /srv/raid/compartido/finanzas` |
| 12 | Colas de impresión y drivers | `lpstat -t` · `lpinfo -m \| grep -i pdf` · navegador de Windows en `http://192.168.56.101:631/printers` |
| 13 | **Prioridades y permisos** | `sudo bash scripts/04_prueba_impresion.sh` (el trabajo de prioridad 90 queda *rank 1st*) |
| 14 | **Impresión en red desde Windows** | Bloc de notas → Imprimir → PDF_General · en la VM: `sudo ls -l /var/spool/cups-pdf/ANONYMOUS/` |
| 15 | Validación final | `sudo bash scripts/99_validar.sh` |
| 16 | Cierre | `# Fin - RAID 5 tolera 1 disco, recursos por grupo, impresion por IPP` |

## Simulación con desconexión "física" (opcional, más visual)

En lugar de `--fail`, puedes quitar un disco con la VM encendida:

1. Con la VM **apagada**, en *Configuración → Almacenamiento*, selecciona `raid2.vdi` y marca **"Conectable en caliente"** (*Hot-pluggable*).
2. Enciende la VM y, durante la grabación, abre en VirtualBox *Configuración → Almacenamiento* de la VM encendida y **quita** `raid2.vdi`. Solo funciona si el puerto quedó marcado como "Conectable en caliente".
3. `cat /proc/mdstat` mostrará el arreglo degradado.
4. Vuelve a conectar el disco y ejecuta: `sudo mdadm --manage /dev/md0 --re-add /dev/sde` (o `--add`).

## Después de grabar

- Guarda los logs de `logs/`: son entregables del repositorio. Desde Windows los puedes copiar por Samba (ver README) o subirlos desde la VM.
- Toma las capturas para el reporte: `mdadm --detail` normal, degradado y reconstruido; `testparm`; Windows en la carpeta compartida; `lpq` con prioridades; el PDF impreso desde Windows.
