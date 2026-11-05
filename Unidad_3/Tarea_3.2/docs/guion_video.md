# Guion del video — Tarea 3.2 (≈ 8–10 min)

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: los bloques **🎙️ Qué decir** están en el mismo orden que la grabación. Léelos como apoyo y dilo con tus palabras.

## Antes de grabar

- Snapshot de la VM.
- OBS: captura de la ventana de VirtualBox. Audio silenciado si el video va sin voz.
- Terminal con letra grande (*Editar → Preferencias → Apariencia*, tamaño 14 o más).
- Ya deben estar aplicados los scripts `00` a `03`, con al menos un respaldo completo (`sudo backup.sh completo`).
- Si vas a mostrar el cron en vivo (paso 9, opción B), crea antes el calendario de prueba.
- Entra a la carpeta y limpia la pantalla:
  ```bash
  cd Administracion-Servidores/Unidad_3/Tarea_3.2
  git status        # debe decir que no hay cambios
  clear
  ```

## Consejos para no perder tiempo

- Ten este guion abierto en Windows y copia los comandos de aquí.
- Si te equivocas, usa **Pausar grabación** en OBS, corrige y continúa.
- La **flecha ↑** repite comandos anteriores.
- **Video sin audio:** antes de cada paso escribe un letrero con `#` (no ejecuta nada), por ejemplo:
  ```bash
  # PASO 7: Logica del script de respaldo backup.sh
  ```

## Pasos

| # | Tiempo | Qué mostrar | Comandos |
|---|---|---|---|
| 1 | 0:00 | Presentación: nombre, tarea y qué se va a demostrar | `# TAREA 3.2 - Permisos avanzados, cuotas y respaldos` |
| 2 | 0:30 | Discos: datos con cuotas y medio de respaldos | `lsblk -f` · `grep TAREA32 /etc/fstab` |
| 3 | 1:15 | Permisos especiales (s = SGID, t = sticky) | `ls -ld /srv/empresa/*` |
| 4 | 2:00 | ACL y herencia | `getfacl /srv/empresa/finanzas/reportes` · `getfacl /srv/empresa/buzon_ti` |
| 5 | 3:00 | Pruebas automáticas de permisos y cuotas | `sudo bash scripts/99_validar.sh` (señala PASA/FALLA) |
| 6 | 4:00 | Cuotas | `sudo repquota -ugsv /srv/empresa` · `sudo quota -us sofia.diaz` |
| 7 | 4:45 | **Lógica del script** (ver detalle abajo) | `nano -v scripts/backup.sh` → salir con **Ctrl + X** |
| 8 | 6:00 | **Ejecución manual** | `sudo backup.sh diferencial` · `sudo restaurar.sh --listar` |
| 9 | 6:45 | **Ejecución calendarizada** (ver detalle abajo) | `cat /etc/cron.d/tarea32-respaldos` · `systemctl status cron` · `sudo restaurar.sh --listar` |
| 10 | 7:45 | **Recuperación de archivos borrados** | `sudo bash scripts/04_simulacro_restauracion.sh` |
| 11 | 9:00 | Cierre: RPO de 24 h, RTO objetivo y tiempo medido (3 s) | `# Fin - RPO 24h, RTO medido 3 segundos` |

## 🎙️ Qué decir en cada paso

Texto para cuando te grabes explicando el video. Los números corresponden a los pasos de la tabla.

**1.** Hola, soy Josué Javier Álvarez Valle. Presento la Tarea 3.2: permisos avanzados con ACL, cuotas de disco y una política de respaldos automatizados con su prueba de recuperación.

**2.** La máquina tiene dos discos extra: uno de datos, montado en /srv/empresa con las cuotas activadas, y otro que funciona como medio de respaldo secundario. Los dos están en el fstab para montarse al arrancar.

**3.** Las carpetas de los departamentos tienen permisos especiales. La s en el grupo es SGID: todo lo que se crea adentro hereda el grupo del departamento. La t de la carpeta general es el sticky bit: cada quien solo puede borrar sus propios archivos.

**4.** Con getfacl muestro las ACL, que dan permisos más precisos que los tradicionales. Aquí un grupo adicional tiene solo lectura, y las entradas default hacen que los archivos nuevos hereden esos permisos.

**5.** El script de validación prueba como cada usuario lo que puede y lo que no puede hacer con los permisos y las cuotas, y todas las pruebas pasan.

**6.** repquota muestra las cuotas por usuario y por grupo: el espacio usado, el límite suave, que da un periodo de gracia, y el límite duro, que no se puede pasar. Cuando un usuario lo supera, el sistema responde Disk quota exceeded.

**7.** Este es el script de respaldo. Primero monta el disco de respaldos, decide si el respaldo es completo, diferencial o incremental, y usa tar conservando los permisos y las ACL. Después verifica el archivo, lo lista y calcula su suma SHA-256. Al final borra los respaldos viejos según la política de retención y desmonta el disco.

**8.** Ejecuto un respaldo diferencial a mano. Al terminar aparece RESPALDO CORRECTO, y con restaurar.sh listar veo todos los respaldos guardados, con su tipo y su fecha.

**9.** Los respaldos no dependen de que alguien se acuerde: cron los ejecuta solo. Hace un respaldo completo el domingo a las 2 de la mañana y uno diferencial de lunes a sábado, y el servicio cron está activo. (Si usas la opción B:) Para que se vea en vivo, agregué un calendario de prueba cada 5 minutos; al llegar el minuto, cron ejecuta el respaldo sin que yo haga nada y en el log aparece RESPALDO CORRECTO.

**10.** El simulacro de restauración borra archivos, los recupera desde el último respaldo y comprueba que sean idénticos. El resultado es EXITOSO y se mide cuánto tardó la recuperación.

**11.** Con esta política, el RPO es de 24 horas, porque como máximo se perdería un día de trabajo, y el tiempo de recuperación medido fue de 3 segundos, muy por debajo del objetivo. Gracias.

## Detalle del paso 7: explicar `backup.sh` con nano

Ábrelo en **solo lectura** (`-v`) para no modificarlo por accidente:

```bash
nano -v scripts/backup.sh
```

| Tecla | Hace |
|---|---|
| Flechas ↑ ↓ | Moverse línea por línea |
| **Av Pág / Re Pág** | Bajar o subir una pantalla |
| **Ctrl + W** | Buscar texto (ej. `listed-incremental`, `sha256sum`, `Rotacion`) |
| **Ctrl + X** | **Salir** |

En la barra inferior de nano, `^` significa **Ctrl** (`^X Salir` = Ctrl + X). Si al salir pregunta **"¿Guardar el búfer modificado?"**, presiona **N**.

**Qué señalar en el script:**

1. El **encabezado**, con los pasos 1 a 8 del flujo.
2. **Montaje** del medio secundario (`mount "$PUNTO_MONTAJE"`).
3. **Tipo de respaldo** y archivos `.snar` (`--listed-incremental`).
4. Comando **`tar`** con `--acls --xattrs`.
5. **Verificación:** `gzip -t`, `tar --list`, `sha256sum`.
6. **Rotación** (`RETENER_COMPLETOS`).
7. **Desmontaje** al final (`al_salir`).

Si crees que modificaste algo sin querer:

```bash
git status                       # si aparece "modified: scripts/backup.sh"...
git checkout scripts/backup.sh   # ...lo regresa a la version original
```

## Detalle del paso 9: ejecución calendarizada

**Opción A (rápida, sin esperar).** Muestra el calendario real y que cron está activo:

```bash
cat /etc/cron.d/tarea32-respaldos     # completo el domingo 02:00, diferencial lunes a sabado 02:00
systemctl status cron                 # el servicio que lo ejecuta: active (running)
sudo restaurar.sh --listar            # respaldos guardados en el medio secundario
```

Explica cada línea del calendario: `0 2 * * 0` = minuto 0, hora 2, domingo; `0 2 * * 1-6` = lunes a sábado.

**Opción B (en vivo, con un calendario de prueba).** Antes de grabar, crea un calendario temporal que haga un respaldo **cada 5 minutos**:

```bash
sudo nano /etc/cron.d/tarea32-prueba
```

Escribe esta línea (con los espacios tal cual):

```
*/5 * * * * root /usr/local/sbin/backup.sh incremental
```

Guarda con **Ctrl + O**, **Enter**, y sal con **Ctrl + X**. Durante la grabación:

```bash
cat /etc/cron.d/tarea32-prueba        # "*/5" = cada 5 minutos
```

Mira la hora de la VM. Cuando falten 1 o 2 minutos para un múltiplo de 5 (:20, :25, :30…):

```bash
sudo tail -f /var/log/tarea32_backup.log
```

- `tail -f` **nunca termina solo**: se queda mostrando el log en vivo.
- **Pausa OBS** mientras esperas y reanuda justo antes del minuto.
- Cuando aparezca **"RESPALDO CORRECTO"**, presiona **Ctrl + C** para salir. Eso no interrumpe ningún respaldo.
- Después, `sudo restaurar.sh --listar` muestra el incremental que hizo cron sin que nadie lo ejecutara.

## Recuperación manual (opcional, más visual que el simulacro)

```bash
ls /srv/empresa/finanzas/reportes
sudo rm /srv/empresa/finanzas/reportes/reporte_T3.txt
ls /srv/empresa/finanzas/reportes          # ya no está
sudo restaurar.sh --ultimo --ruta srv/empresa/finanzas/reportes/reporte_T3.txt --en-sitio
cat /srv/empresa/finanzas/reportes/reporte_T3.txt
getfacl /srv/empresa/finanzas/reportes/reporte_T3.txt   # ACL intactas
```

## Después de grabar

Si usaste la opción B del paso 9, borra el calendario de prueba para que no siga haciendo respaldos cada 5 minutos:

```bash
sudo rm /etc/cron.d/tarea32-prueba
```

El calendario real (`/etc/cron.d/tarea32-respaldos`) se queda como está.

## Capturas para el PDF

- Salida de `00_preparar_discos.sh` (lsblk y fstab).
- `ls -ld /srv/empresa/*` y `getfacl`.
- Las 20 pruebas PASA de `99_validar.sh`.
- `repquota` y el error "Disk quota exceeded".
- `backup.sh` terminando con "RESPALDO CORRECTO".
- `restaurar.sh --listar` con los incrementales del cron.
- El archivo de cron.
- El simulacro "EXITOSO" con el tiempo medido.
