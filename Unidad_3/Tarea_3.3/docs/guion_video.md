# Guion del video — Tarea 3.3 (≈ 10 min)

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: los bloques **🎙️ Qué decir** están en el mismo orden que la grabación. Léelos como apoyo y dilo con tus palabras.

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

## 🎙️ Qué decir en cada paso

Texto para cuando te grabes explicando el video. Los números corresponden a los pasos de la tabla.

**1.** Hola, soy Josué Javier Álvarez Valle. En la Tarea 3.3 configuro almacenamiento redundante con un RAID 5, lo comparto en red con Samba y NFS, e instalo un servidor de impresión CUPS con colas, prioridades y acceso desde Windows.

**2.** Para el RAID agregué tres discos de 1 GB: sdd, sde y sdf. Juntos forman el dispositivo md0.

**3.** Aquí se ve el RAID 5 en estado clean, con los tres discos en active sync. Tiene 2 GB útiles, porque el equivalente a un disco se usa para la paridad, que es lo que permite recuperar los datos.

**4.** Para que el arreglo siga funcionando después de reiniciar, está registrado en mdadm.conf y se monta solo desde el fstab en /srv/raid.

**5.** Ahora simulo que un disco falla. El arreglo pasa a clean, degraded y muestra U guion bajo U: falta un disco, pero sigue funcionando. El script compara la huella del archivo de prueba y confirma DATOS INTACTOS.

**6.** Aunque falta un disco, las carpetas compartidas siguen accesibles con normalidad.

**7.** Agrego un disco de reemplazo y el RAID se reconstruye solo: el porcentaje avanza hasta terminar y el arreglo vuelve a clean con los tres discos.

**8.** Cada etapa quedó registrada en un log con fecha y hora: la creación, la degradación y la reconstrucción.

**9.** testparm valida la configuración de Samba: hay una carpeta por departamento y solo entra el grupo correspondiente. exportfs muestra las carpetas que se comparten por NFS para equipos con Linux.

**10.** Desde el Explorador de Windows entro a la carpeta de Finanzas con el usuario pedro.ruiz y creo un archivo. Si intento abrir la de Operaciones, Windows me niega el acceso, porque Pedro no pertenece a ese departamento.

**11.** En el servidor se ve el archivo que creé desde Windows, guardado dentro del RAID.

**12.** lpstat muestra las colas de impresión: una general, una de Finanzas y una de Dirección, agrupadas en la clase Oficina. lpinfo lista el controlador que usan, y desde Windows veo las impresoras en la página web de CUPS, en el puerto 631.

**13.** Este script pausa una cola y envía tres trabajos con prioridad 10, 50 y 90. Aunque el de prioridad 90 se envió al último, queda en primer lugar. También comprueba que cada usuario solo puede imprimir en las colas que tiene permitidas.

**14.** Desde el Bloc de notas de Windows imprimo en PDF_General a través de la red con el protocolo IPP, y en el servidor aparece el PDF de ese trabajo.

**15.** La validación final comprueba el RAID, Samba, NFS y CUPS, y todas las pruebas pasan.

**16.** En resumen: el RAID 5 tolera la falla de un disco sin perder datos, las carpetas de red respetan los grupos de cada departamento y la impresión se comparte en red con prioridades y permisos. Gracias.

## Simulación con desconexión "física" (opcional, más visual)

En lugar de `--fail`, puedes quitar un disco con la VM encendida:

1. Con la VM **apagada**, en *Configuración → Almacenamiento*, selecciona `raid2.vdi` y marca **"Conectable en caliente"** (*Hot-pluggable*).
2. Enciende la VM y, durante la grabación, abre en VirtualBox *Configuración → Almacenamiento* de la VM encendida y **quita** `raid2.vdi`. Solo funciona si el puerto quedó marcado como "Conectable en caliente".
3. `cat /proc/mdstat` mostrará el arreglo degradado.
4. Vuelve a conectar el disco y ejecuta: `sudo mdadm --manage /dev/md0 --re-add /dev/sde` (o `--add`).

## Después de grabar

- Guarda los logs de `logs/`: son entregables del repositorio. Desde Windows los puedes copiar por Samba (ver README) o subirlos desde la VM.
- Toma las capturas para el reporte: `mdadm --detail` normal, degradado y reconstruido; `testparm`; Windows en la carpeta compartida; `lpq` con prioridades; el PDF impreso desde Windows.
