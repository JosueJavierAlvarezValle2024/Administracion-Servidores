# Guion del video — Tarea 3.2 (≈ 8–10 min)

**Antes de grabar:**

- Snapshot de la VM.
- Cámara en la esquina inferior derecha (OBS: *Fuente → Dispositivo de captura de video*).
- Terminal con letra grande (`Ctrl` + `+`).
- Ya debe estar aplicado de `00` a `03`, con al menos un respaldo completo.

| # | Tiempo | Qué mostrar | Comandos |
|---|---|---|---|
| 1 | 0:00 | Presentación: nombre, tarea, qué se va a demostrar | — |
| 2 | 0:30 | Discos: datos con cuotas y medio de respaldos | `lsblk -f` · `grep TAREA32 /etc/fstab` |
| 3 | 1:15 | Permisos especiales (s y t) | `ls -ld /srv/empresa/*` |
| 4 | 2:00 | ACL y herencia | `getfacl /srv/empresa/finanzas/reportes` · `getfacl /srv/empresa/buzon_ti` |
| 5 | 3:00 | Pruebas automáticas de permisos y cuotas | `sudo bash scripts/99_validar.sh` (señala PASA/FALLA) |
| 6 | 4:00 | Cuotas | `sudo repquota -ugs /srv/empresa` · `sudo quota -us sofia.diaz` |
| 7 | 4:45 | **Lógica del script**: abre `backup.sh` y explica las secciones 1 a 8 del encabezado: montaje, tipos, `--listed-incremental`, verificación, rotación | `nano scripts/backup.sh` |
| 8 | 6:00 | **Ejecución manual** | `sudo backup.sh diferencial` · `sudo restaurar.sh --listar` |
| 9 | 6:45 | **Ejecución calendarizada**: muestra el cron y espera un múltiplo de 5 min (o enséñalo en el log) | `cat /etc/cron.d/tarea32-respaldos /etc/cron.d/tarea32-demo` · `sudo tail -f /var/log/tarea32_backup.log` |
| 10 | 7:45 | **Recuperación de archivos borrados** | `sudo bash scripts/04_simulacro_restauracion.sh` |
| 11 | 9:00 | Cierre: RPO/RTO y tiempo medido | — |

**Recuperación manual (opcional, más visual que el simulacro):**

```bash
ls /srv/empresa/finanzas/reportes
sudo rm /srv/empresa/finanzas/reportes/reporte_T3.txt
ls /srv/empresa/finanzas/reportes          # ya no está
sudo restaurar.sh --ultimo --ruta srv/empresa/finanzas/reportes/reporte_T3.txt --en-sitio
cat /srv/empresa/finanzas/reportes/reporte_T3.txt
getfacl /srv/empresa/finanzas/reportes/reporte_T3.txt   # ACL intactas
```

**Capturas para el PDF:**

- Salida de `00_preparar_discos.sh` (lsblk y fstab).
- `ls -ld /srv/empresa/*` y `getfacl`.
- Las pruebas PASA de `99_validar.sh`.
- `repquota` y el error "Disk quota exceeded".
- `backup.sh` terminando con "RESPALDO CORRECTO".
- `restaurar.sh --listar`.
- El cron.
- El simulacro "EXITOSO" con el tiempo medido (anótalo en la política, sección 6).
