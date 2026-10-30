# Guion del video — Tarea 3.2 (≈ 8–10 min)

## Antes de grabar

- Snapshot de la VM.
- OBS: captura de la ventana de VirtualBox. Audio silenciado si el video va sin voz.
- Terminal con letra grande (*Editar → Preferencias → Apariencia*, tamaño 14 o más).
- Ya debe estar aplicado de `00` a `03 --demo` (respaldo cada 5 min), con al menos un respaldo completo.
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
| 9 | 6:45 | **Ejecución calendarizada** (ver detalle abajo) | `cat /etc/cron.d/tarea32-respaldos /etc/cron.d/tarea32-demo` · `sudo restaurar.sh --listar` |
| 10 | 7:45 | **Recuperación de archivos borrados** | `sudo bash scripts/04_simulacro_restauracion.sh` |
| 11 | 9:00 | Cierre: RPO de 24 h, RTO objetivo y tiempo medido (3 s) | `# Fin - RPO 24h, RTO medido 3 segundos` |

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

**Opción A (rápida, sin esperar).** Demuestra que cron ya trabajó solo:

```bash
cat /etc/cron.d/tarea32-demo          # "*/5 * * * *" = cada 5 minutos
sudo restaurar.sh --listar            # incrementales cada 5 min que nadie ejecutó a mano
journalctl -t backup.sh --since "30 min ago" | grep "Inicio de respaldo"
```

**Opción B (en vivo).** Mira la hora de la VM. Cuando falten 1 o 2 minutos para un múltiplo de 5 (:20, :25, :30…):

```bash
sudo tail -f /var/log/tarea32_backup.log
```

- `tail -f` **nunca termina solo**: se queda mostrando el log en vivo.
- **Pausa OBS** mientras esperas y reanuda justo antes del minuto.
- Cuando aparezca **"RESPALDO CORRECTO"**, presiona **Ctrl + C** para salir. Eso no interrumpe ningún respaldo.

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

Quita el respaldo de demostración cada 5 minutos:

```bash
sudo bash scripts/03_instalar_respaldos.sh --sin-demo
```

## Capturas para el PDF

- Salida de `00_preparar_discos.sh` (lsblk y fstab).
- `ls -ld /srv/empresa/*` y `getfacl`.
- Las 20 pruebas PASA de `99_validar.sh`.
- `repquota` y el error "Disk quota exceeded".
- `backup.sh` terminando con "RESPALDO CORRECTO".
- `restaurar.sh --listar` con los incrementales del cron.
- El archivo de cron.
- El simulacro "EXITOSO" con el tiempo medido.
