# Guion del video — Tarea 3.3 (≈ 10 min)

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: la columna **🎙️ Qué decir** de la tabla de pasos está junto a cada comando, en el mismo orden que la grabación. Léela como apoyo y dilo con tus palabras.

## Antes de grabar

- Snapshot de la VM ("3.3 lista").
- Ya debe estar aplicado: `00_crear_raid.sh`, `02_compartir_samba_nfs.sh` y `03_impresion_cups.sh`.
- Ten a mano la contraseña de Samba de pedro.ruiz: `sudo cat /root/tarea33_samba.csv`.
- En Windows, abre el Explorador de archivos. Si ya habías entrado antes a la carpeta compartida, en `cmd` ejecuta `net use * /delete` para que Windows olvide la sesión anterior.
- OBS: captura de **pantalla completa**, para mostrar la VM y Windows.
- Terminal con letra grande. Video sin audio: escribe letreros con `#` antes de cada paso.
- Si te equivocas, usa **Pausar grabación** en OBS.

## Pasos

Los pasos 2 a 4 usan rutas completas y funcionan desde cualquier carpeta. A partir del paso 5 hay que estar en la carpeta de la tarea, porque se usan `scripts/` y `logs/`.

| # | Comandos / acciones | Qué debe aparecer | 🎙️ Qué decir |
|---|---|---|---|
| 1 | `# TAREA 3.3 - RAID 5, Samba/NFS y servidor de impresion CUPS` | — | **Presentación.** Hola, soy Josué Javier Álvarez Valle. En la Tarea 3.3 configuro almacenamiento redundante con un RAID 5, lo comparto en red con Samba y NFS, e instalo un servidor de impresión CUPS con colas, prioridades y permisos. |
| 2 | `lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS` | `sdd`, `sde` y `sdf` de **1G** cada uno; debajo de cada uno, `md0` de **2G**, tipo `raid5`, montado en `/srv/raid` | **Discos del arreglo.** Para el RAID agregué tres discos de 1 GB: sdd, sde y sdf. Juntos forman el dispositivo md0, que está montado en /srv/raid. |
| 3 | `cat /proc/mdstat` · `sudo mdadm --detail /dev/md0` | `md0 : active raid5 sdf[3] sde[1] sdd[0]` y `[3/3] [UUU]` · `Raid Level : raid5`, `State : clean`, `Active Devices : 3` y tres discos `active sync` | **Estado del RAID.** Aquí se ve el RAID 5 en estado clean, con los tres discos en active sync. Las tres U significan que los tres discos funcionan. Tiene 2 GB útiles, porque el equivalente a un disco se usa para la paridad, que es lo que permite recuperar los datos si uno falla. |
| 4 | `grep ARRAY /etc/mdadm/mdadm.conf` · `grep TAREA33 /etc/fstab` · `df -h /srv/raid` | `ARRAY /dev/md0 ... UUID=...` · una línea con `/srv/raid` y `nofail` · `/dev/md0` de unos **2,0G** montado en `/srv/raid` | **Persistencia.** Para que el arreglo siga funcionando después de reiniciar, está registrado en mdadm.conf y se monta solo desde el fstab en /srv/raid. Con df veo su tamaño y cuánto espacio está ocupado. |
| 5 | `cd ~/Administracion-Servidores/Unidad_3/Tarea_3.3` · `ls -lh /srv/raid/compartido/general` | Los archivos de la carpeta general, entre ellos `prueba_raid.bin` de **50M** | **Datos en el RAID.** Entro a la carpeta de la tarea y reviso la carpeta general del RAID. Aquí está el archivo de prueba de 50 megas que uso para comprobar que los datos no se dañan. |
| 6 | ⚠️ `sudo bash scripts/01_simular_fallo.sh --fallo` (**no está en tu lista**, ver nota abajo) | `State : clean, degraded`, `[3/2] [U_U]`, `DATOS INTACTOS` y `hot removed /dev/sde` | **Simulación de falla.** Ahora simulo que un disco falla. El arreglo pasa a clean, degraded y muestra U guion bajo U: falta un disco, pero sigue funcionando. El script compara la huella del archivo de prueba y confirma DATOS INTACTOS. |
| 7 | `sudo bash scripts/01_simular_fallo.sh --reconstruir` | Líneas `recovery = 12.5%`… que suben hasta `Reconstruccion TERMINADA`; luego `State : clean`, `[3/3] [UUU]` y `DATOS INTACTOS` | **Reconstrucción.** Agrego un disco de reemplazo y el RAID se reconstruye solo: el porcentaje avanza hasta terminar y el arreglo vuelve a clean con los tres discos. El archivo de prueba sigue idéntico. |
| 8 | `ls logs/` · `cat logs/degradacion_*.log` | Archivos `raid_creacion_…`, `degradacion_…` y `reconstruccion_…` · el log con fecha y hora: `clean`, `Disco /dev/sde marcado como FALLIDO`, `clean, degraded` y los mensajes del kernel | **Logs.** Cada etapa quedó registrada en un log con fecha y hora: la creación, la degradación y la reconstrucción. En el de degradación se ve el estado antes y después de la falla, y el aviso del kernel de que el arreglo siguió funcionando con dos discos. |
| 9 | `testparm -s` · `sudo exportfs -v` | `Loaded services file OK.` y las secciones `[general]`, `[sistemas]`, `[finanzas]`, `[operaciones]`, cada una con su `valid users = @grupo` · `general` con `rw` y `operaciones` con `ro`, ambas con `root_squash` | **Samba y NFS.** testparm valida la configuración de Samba: hay una carpeta por departamento y solo entra el grupo correspondiente. exportfs muestra las carpetas que se comparten por NFS para equipos con Linux: general con lectura y escritura, y operaciones solo de lectura. |
| 10 | **En Windows:** Explorador → `\\192.168.56.101\finanzas` → usuario `pedro.ruiz` y su contraseña de Samba → crear un documento `.txt` | La carpeta de Finanzas se abre y aparece el archivo nuevo | **Carpeta de red desde Windows.** Desde el Explorador de Windows escribo la dirección del servidor y la carpeta de Finanzas. Me pide usuario y contraseña; entro como pedro.ruiz y creo un documento de texto. |
| 11 | **En Windows:** Explorador → `\\192.168.56.101\operaciones` → volver a iniciar sesión | Mensaje de **acceso denegado** (*No tiene permiso para acceder…*) | **Acceso denegado.** Ahora intento abrir la carpeta de Operaciones. Aunque vuelvo a iniciar sesión, Windows me niega el acceso, porque Pedro no pertenece a ese departamento. |
| 12 | `ls -l /srv/raid/compartido/finanzas` | El `.txt` creado desde Windows, con dueño `pedro.ruiz`, grupo `finanzas` y permisos `-rw-rw----` | **Archivo en el servidor.** En el servidor se ve el archivo que creé desde Windows, guardado dentro del RAID, con Pedro como dueño y el grupo finanzas. |
| 13 | `lpstat -t` · `lpinfo -m \| grep -i pdf` | `scheduler is running`, las colas `PDF_General`, `PDF_Finanzas`, `PDF_Direccion` con `cups-pdf:/`, la clase `Oficina` y `accepting requests` · una línea con el controlador `CUPS-PDF` | **Colas y controlador.** lpstat muestra que el servicio de impresión está activo y las colas: una general, una de Finanzas y una de Dirección, agrupadas en la clase Oficina. lpinfo muestra el controlador que usan, CUPS-PDF, que convierte cada trabajo en un archivo PDF. |
| 14 | `sudo bash scripts/04_prueba_impresion.sh` | `lpq` con `prioridad_ALTA_90` en **1st** aunque se envió al último · la lista de trabajos completados · 5 líneas `[PASA]` de permisos | **Prioridades y permisos.** Este script pausa una cola y envía tres trabajos con prioridad 10, 50 y 90. Aunque el de prioridad 90 se envió al último, queda en primer lugar. También comprueba que cada usuario solo puede imprimir en las colas que tiene permitidas: por ejemplo, Laura no puede usar la de Finanzas. |
| 15 | `sudo bash scripts/99_validar.sh` | 16 líneas `[PASA]` y `Pruebas que pasaron: 16   Pruebas que fallaron: 0` | **Validación final.** La validación final comprueba el RAID, Samba, NFS y CUPS: que el arreglo esté limpio, que cada usuario entre solo a sus carpetas, que NFS proteja al root y que las colas respeten los permisos. Todas las pruebas pasan. |
| 16 | `# Fin - RAID 5 tolera 1 disco, recursos por grupo, impresion por IPP` | — | **Cierre.** En resumen: el RAID 5 tolera la falla de un disco sin perder datos, las carpetas de red respetan los grupos de cada departamento y la impresión se comparte en red con prioridades y permisos. Gracias. |

**Nota del paso 6:** `--reconstruir` solo funciona si antes se ejecutó `--fallo`. Si el arreglo está completo, el script responde *"/dev/sde ya forma parte del arreglo: no hay nada que reconstruir"* y no muestra ningún porcentaje. Si en tu video sí se ve la reconstrucción, es que el `--fallo` se ejecutó antes de empezar a grabar: en ese caso salta la fila 6 y, en la fila 3, el RAID ya debió verse `clean, degraded` y `[U_U]`.

## Simulación con desconexión "física" (opcional, más visual)

En lugar de `--fallo`, puedes quitar un disco con la VM encendida:

1. Con la VM **apagada**, en *Configuración → Almacenamiento*, selecciona `raid2.vdi` y marca **"Conectable en caliente"** (*Hot-pluggable*).
2. Enciende la VM y, durante la grabación, abre en VirtualBox *Configuración → Almacenamiento* de la VM encendida y **quita** `raid2.vdi`. Solo funciona si el puerto quedó marcado como "Conectable en caliente".
3. `cat /proc/mdstat` mostrará el arreglo degradado.
4. Vuelve a conectar el disco y ejecuta: `sudo mdadm --manage /dev/md0 --re-add /dev/sde` (o `--add`).

## Después de grabar

- Guarda los logs de `logs/`: son entregables del repositorio. Desde Windows los puedes copiar por Samba (ver README) o subirlos desde la VM.
- Toma las capturas para el reporte: `mdadm --detail` normal (3), degradado (6) y reconstruido (7); el log (8); `testparm` (9); Windows en la carpeta compartida y el acceso denegado (10 y 11); `lpq` con prioridades (14); la validación con 16 PASA (15).
