# Política formal de respaldos

**Organización:** Empresa de práctica (Sistemas, Finanzas, Operaciones)
**Servidor:** Xubuntu 25.10 · **Responsable:** Jefe de Sistemas (`ana.torres`)
**Versión:** 1.0 · **Revisión:** semestral

## 1. Objetivo

Garantizar que la información del servidor se pueda recuperar ante:

- borrado accidental;
- falla de disco;
- daño por software malicioso;
- error de configuración.

Los tiempos y la pérdida máxima de datos están definidos en la sección 6.

## 2. Alcance

| Origen | Contenido | Criticidad |
|---|---|---|
| `/srv/empresa` | Carpetas de departamentos, general, dirección y buzón de TI | **Alta** |
| `/home` | Archivos personales de los empleados | Media |
| `/etc` | Configuración del sistema: usuarios, sudoers, PAM, fstab, cron | **Alta** |

**Exclusiones:**

- cachés (`.cache`);
- papeleras;
- paquetes `snap`;
- imágenes `.iso`;
- `lost+found`.

## 3. Tipos de respaldo

| Tipo | Qué copia | Ventaja | Desventaja | Para restaurar se necesita |
|---|---|---|---|---|
| **Completo** | Todo | Restauración más simple y rápida | Más tiempo y espacio | Solo ese archivo |
| **Diferencial** | Cambios desde el último **completo** | Restauración con solo 2 archivos | Crece cada día de la semana | Completo + último diferencial |
| **Incremental** | Cambios desde el **último respaldo** de cualquier tipo | El más rápido y pequeño | Restauración más larga; si falla un eslabón se rompe la cadena | Completo + todos los incrementales |

**Implementación:**

- Se usa GNU `tar --listed-incremental`.
- Los archivos de estado (`.snar`) se guardan en `/var/lib/tarea32`.
- Cada respaldo conserva permisos, dueños, **ACL** y atributos extendidos (`--acls --xattrs`).

## 4. Calendario

| Día | Hora | Tipo | Programado en |
|---|---|---|---|
| Domingo | 02:00 | Completo | `/etc/cron.d/tarea32-respaldos` |
| Lunes a sábado | 02:00 | Diferencial | `/etc/cron.d/tarea32-respaldos` |
| Día 1 de cada mes | 04:00 | Simulacro automático de restauración | `/etc/cron.d/tarea32-respaldos` |
| *Demostración* | cada 5 min | Incremental | `/etc/cron.d/tarea32-demo` (solo para el video) |

Se eligió **diferencial** para los días normales. Así, en el peor caso solo hacen falta 2 archivos para restaurar, lo que reduce el RTO.

## 5. Almacenamiento y retención

**Medio secundario:** disco dedicado `RESPALDOS` (`/dev/sdc1`) montado en `/mnt/respaldos`.

- Está marcado como `noauto` en fstab: **solo se monta durante el respaldo** y luego se desmonta.
- Así queda protegido contra borrados accidentales y contra malware que cifre las unidades montadas.

**Copia externa (opcional):** `rsync` por SSH hacia un servidor de almacenamiento (variable `REMOTO`).

**Retención:** se conservan los **4 últimos ciclos semanales**, es decir, cerca de un mes. Lo anterior se rota de forma automática.

**Estructura:**

```
/mnt/respaldos/tarea32/<equipo>/AAAAMMDD_HHMMSS_<tipo>.tar.gz
                               AAAAMMDD_HHMMSS_<tipo>.tar.gz.sha256
                               AAAAMMDD_HHMMSS_<tipo>.lst   (listado de archivos)
                               AAAAMMDD_HHMMSS_<tipo>.log   (log de la ejecución)
```

**Regla 3-2-1:**

- **3** copias: los datos originales y el disco de respaldos, más el servidor remoto si se configura.
- **2** medios distintos: el disco de datos y el disco de respaldos.
- **1** copia fuera del sitio: el servidor remoto.

*Limitación del laboratorio:* los discos virtuales están en el mismo equipo físico.

## 6. Objetivos de recuperación

| Indicador | Definición | Objetivo | Justificación |
|---|---|---|---|
| **RPO** (Recovery Point Objective) | Pérdida máxima de datos aceptable | **24 horas** | Hay un respaldo cada noche. Si Finanzas lo requiere en cierre de mes, se baja a **1 hora** con incrementales horarios |
| **RTO** archivo individual | Tiempo para recuperar un archivo o carpeta | **≤ 15 minutos** | `restaurar.sh --ruta ... --en-sitio` |
| **RTO** `/srv/empresa` completo | Tiempo para recuperar todas las carpetas departamentales | **≤ 1 hora** | Completo + 1 diferencial |
| **RTO** servidor completo | Reinstalación + `/etc` + datos | **≤ 4 horas** | Incluye reinstalar el sistema operativo |

**Tiempo medido en el simulacro (30/10/2026):** **3 segundos** para recuperar una carpeta de Finanzas borrada (≈ 2 MB), aplicando la cadena completo + incrementales. Contenido, dueño, permisos y ACL quedaron idénticos al original. El objetivo de RTO para archivos individuales (≤ 15 min) se cumple con amplio margen.

## 7. Verificación

Cada respaldo se valida de forma automática:

1. `gzip -t`: integridad de la compresión.
2. `tar --list`: lectura completa del archivo; se guarda el listado.
3. `sha256sum`: huella digital. Se vuelve a comprobar **antes de cada restauración**.
4. Registro en `/var/log/tarea32_backup.log`, en `syslog` (`journalctl -t backup.sh`) y en `/var/lib/tarea32/ultimo_estado`.

## 8. Procedimiento de restauración

```bash
sudo restaurar.sh --listar                                   # ver respaldos
sudo restaurar.sh --ultimo                                   # todo, a /var/tmp/restauracion_<fecha>
sudo restaurar.sh --respaldo 20261028_020000                 # a un punto en el tiempo
sudo restaurar.sh --ultimo --ruta srv/empresa/finanzas/x.txt --en-sitio   # un archivo, a su lugar
```

El script arma la cadena correcta (completo + diferencial o incrementales) y verifica los checksums antes de extraer.

## 9. Responsabilidades

| Rol | Responsabilidad |
|---|---|
| Jefe de Sistemas | Aprobar la política y revisar el log semanalmente |
| Técnico de Sistemas | Atender fallas de respaldo y ejecutar restauraciones solicitadas |
| Jefes de área | Solicitar restauraciones por escrito e indicar la ruta y la fecha |
