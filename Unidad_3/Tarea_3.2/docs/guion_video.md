# Guion del video — Tarea 3.2 (≈ 8–10 min)

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: la columna **🎙️ Qué decir** de la tabla de pasos está junto a cada comando, en el mismo orden que la grabación. Léela como apoyo y dilo con tus palabras.

## Antes de grabar

- Snapshot de la VM.
- OBS: captura de la ventana de VirtualBox. Audio silenciado si el video va sin voz.
- Terminal con letra grande (*Editar → Preferencias → Apariencia*, tamaño 14 o más).
- Ya deben estar aplicados los scripts `00` a `03`, con al menos un respaldo completo (`sudo backup.sh completo`).
- Crea el **calendario de demostración** (paso 9), al menos 10 minutos antes de grabar, para que cron ya haya hecho algún respaldo:
  ```bash
  sudo nano /etc/cron.d/tarea32-demo
  ```
  Escribe esta línea (con los espacios tal cual), guarda con **Ctrl + O**, **Enter**, y sal con **Ctrl + X**:
  ```
  */5 * * * * root /usr/local/sbin/backup.sh incremental
  ```
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
- Fíjate en las rutas: es `/srv` (no `/svr`) y `/srv/empresa/*` lleva **barra antes del asterisco**.
- **Video sin audio:** antes de cada paso escribe un letrero con `#` (no ejecuta nada), por ejemplo:
  ```bash
  # PASO 7: Logica del script de respaldo backup.sh
  ```

## Pasos

| # | Tiempo | Comandos | Qué debe aparecer | 🎙️ Qué decir |
|---|---|---|---|---|
| 1 | 0:00 | `# TAREA 3.2 - Permisos avanzados, cuotas y respaldos` | — | **Presentación.** Hola, soy Josué Javier Álvarez Valle. Presento la Tarea 3.2: permisos avanzados con ACL, cuotas de disco y una política de respaldos automatizados con su prueba de recuperación. |
| 2 | 0:30 | `lsblk -f` · `grep TAREA32 /etc/fstab` | Un disco montado en `/srv/empresa` y otro **sin** punto de montaje (el de respaldos, desconectado a propósito) · 2 líneas: una con `usrquota,grpquota` y otra con `noauto` | **Discos.** La máquina tiene dos discos extra. Uno es el de datos, montado en /srv/empresa con las cuotas de usuario y de grupo activadas. El otro es el medio de respaldos: en lsblk aparece sin punto de montaje porque en el fstab tiene la opción noauto. Solo se conecta mientras se hace un respaldo, así queda protegido si algo le pasa al sistema. |
| 3 | 1:15 | `ls -ld /srv/empresa/*` | `drwxrws---` en los departamentos y `drwxrws--T` en `general` y `buzon_ti`. Un `+` al final indica que tiene ACL | **Permisos especiales.** Las carpetas de los departamentos tienen permisos especiales. La s en el grupo es SGID: todo lo que se crea adentro hereda el grupo del departamento. La T de la carpeta general y del buzón es el sticky bit: cada quien solo puede borrar sus propios archivos. El signo más indica que la carpeta tiene ACL. |
| 4 | 2:00 | `getfacl /srv/empresa/finanzas/reportes/` · `getfacl /srv/empresa/buzon_ti` | `group:jefes:r-x` y líneas `default:` (herencia) · `group:empleados:-wx` y `flags: -st` | **ACL y herencia.** Con getfacl muestro las ACL, que dan permisos más precisos que los tradicionales. En reportes de Finanzas, el grupo jefes tiene solo lectura, aunque sean de otro departamento. Las líneas que empiezan con default son la herencia: los archivos nuevos reciben esos permisos automáticamente. En el buzón de TI, los empleados tienen escritura y paso, pero no lectura: pueden dejar archivos, pero no ver lo que hay adentro. |
| 5 | 3:00 | `sudo bash scripts/99_validar.sh` | 20 líneas `[PASA]` y `Pruebas que pasaron: 20   Pruebas que fallaron: 0` | **Pruebas automáticas.** El script de validación prueba como cada usuario lo que puede y lo que no puede hacer con los permisos y las cuotas: el SGID, el sticky bit, las ACL, el buzón y el límite de espacio. Las veinte pruebas pasan. |
| 6 | 4:00 | `sudo repquota -ugsv /srv/empresa` · `sudo quota -us sofia.diaz` | Tablas de usuarios y grupos con usado / blando / duro / gracia · sofia: límite blando **50M** y duro **60M** | **Cuotas.** repquota muestra las cuotas por usuario y por grupo: el espacio usado, el límite suave, que da un periodo de gracia, y el límite duro, que no se puede pasar. Con quota veo el caso de Sofía: 50 megas de límite suave y 60 de duro. Si lo supera, el sistema responde Disk quota exceeded, como se comprobó en la validación. |
| 7 | 4:45 | `nano -v scripts/backup.sh` → salir con **Ctrl + X** (ver detalle abajo) | El código del script (solo lectura) | **Lógica del script.** Este es el script de respaldo. Primero monta el disco de respaldos, decide si el respaldo es completo, diferencial o incremental, y usa tar conservando los permisos y las ACL. Después verifica el archivo, lo lista y calcula su suma SHA-256. Al final borra los respaldos viejos según la política de retención y desmonta el disco. |
| 8 | 6:00 | `sudo backup.sh diferencial` · `sudo restaurar.sh --listar` | Líneas `[OK]` y al final `RESPALDO CORRECTO \| tipo=diferencial` · tabla `RESPALDO  TIPO  TAMANO` con el diferencial nuevo | **Ejecución manual.** Ejecuto un respaldo diferencial a mano, que guarda lo que cambió desde el último completo. Al terminar aparece RESPALDO CORRECTO, y con restaurar.sh listar veo todos los respaldos guardados, con su fecha, su tipo y su tamaño. |
| 9 | 6:45 | `cat /etc/cron.d/tarea32-respaldos /etc/cron.d/tarea32-demo` · `sudo restaurar.sh --listar` (ver detalle abajo) | El calendario real (`0 2 * * 0` y `0 2 * * 1-6`) y el de demostración (`*/5`) · la tabla ahora incluye respaldos `incremental` que hizo cron solo | **Ejecución calendarizada.** Los respaldos no dependen de que alguien se acuerde: cron los ejecuta solo. El calendario real hace un respaldo completo el domingo a las 2 de la mañana y uno diferencial de lunes a sábado. Para la demostración agregué un segundo calendario que hace un incremental cada 5 minutos. Al listar otra vez, aparecen respaldos incrementales que hizo cron sin que yo ejecutara nada. |
| 10 | 7:45 | `sudo bash scripts/04_simulacro_restauracion.sh` | Pasos 1 a 6, `[PASA] Contenido (SHA-256), dueno, permisos y ACL identicos`, `Simulacro: EXITOSO` y el tiempo en segundos | **Recuperación de archivos borrados.** El simulacro de restauración crea archivos de prueba, hace un respaldo, los borra, los recupera desde el respaldo y comprueba que el contenido, el dueño, los permisos y las ACL sean idénticos. El resultado es EXITOSO y se mide cuánto tardó la recuperación. |
| 11 | 9:00 | `# Fin - RPO 24h, RTO medido N segundos` | — | **Cierre.** Con esta política, el RPO es de 24 horas, porque como máximo se perdería un día de trabajo, y el tiempo de recuperación medido fue de unos segundos, muy por debajo del objetivo de 15 minutos. Gracias. |

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

```bash
cat /etc/cron.d/tarea32-respaldos /etc/cron.d/tarea32-demo
sudo restaurar.sh --listar
```

Cómo leer cada línea del calendario (`minuto hora día_mes mes día_semana usuario comando`):

- `0 2 * * 0` → minuto 0, hora 2, cualquier día y mes, **domingo** → respaldo completo.
- `0 2 * * 1-6` → lo mismo, de **lunes a sábado** → respaldo diferencial.
- `0 4 1 * *` → día 1 de cada mes a las 4:00 → simulacro de restauración automático.
- `*/5 * * * *` (archivo `tarea32-demo`) → **cada 5 minutos** → respaldo incremental, solo para la demostración.

Compara la segunda lista con la del paso 8: los renglones nuevos de tipo `incremental` los creó cron por su cuenta.

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

Borra el calendario de demostración para que no siga haciendo respaldos cada 5 minutos:

```bash
sudo rm /etc/cron.d/tarea32-demo
```

El calendario real (`/etc/cron.d/tarea32-respaldos`) se queda como está.

## Capturas para el PDF

- `lsblk -f` y las líneas del fstab (2).
- `ls -ld /srv/empresa/*` y `getfacl` (3 y 4).
- Las 20 pruebas PASA de `99_validar.sh` (5).
- `repquota` y `quota` de sofia.diaz (6).
- `backup.sh` terminando con "RESPALDO CORRECTO" (8).
- Los archivos de cron y `restaurar.sh --listar` con los incrementales del cron (9).
- El simulacro "EXITOSO" con el tiempo medido (10).
