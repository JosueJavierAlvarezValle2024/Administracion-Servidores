# Tarea 3.2 — Permisos avanzados, cuotas de disco y respaldos automatizados

**Materia:** Administración de Servidores · **Unidad 3**
**Sistema:** Xubuntu 25.10 en VirtualBox
**Requisito previo:** la [Tarea 3.1](../Tarea_3.1) debe estar aplicada, porque aquí se usan sus usuarios, grupos y `/srv/empresa`.

## Contenido

```
Tarea_3.2/
├── scripts/
│   ├── lib/comun.sh                 # Variables y funciones compartidas
│   ├── 00_preparar_discos.sh        # Formatea sdb (datos + cuotas) y sdc (respaldos), fstab
│   ├── 01_permisos_acl.sh           # SGID, sticky bit, ACL y herencia (ACL por defecto)
│   ├── 02_cuotas.sh                 # Cuotas por usuario y por grupo
│   ├── 03_instalar_respaldos.sh     # Instala backup.sh, restaurar.sh, cron y logrotate
│   ├── 04_simulacro_restauracion.sh # Borra archivos y los recupera (evidencia del RTO)
│   ├── 99_validar.sh                # Evidencia + 20 pruebas automáticas
│   ├── backup.sh                    # Respaldo completo/diferencial/incremental
│   └── restaurar.sh                 # Restauración con verificación SHA-256
├── config/
│   ├── backup.conf                  # Plantilla -> /etc/tarea32/backup.conf
│   ├── tarea32-respaldos.cron       # Calendario  -> /etc/cron.d/
│   ├── tarea32-demo.cron            # Cada 5 min, para el video
│   ├── logrotate-tarea32            # -> /etc/logrotate.d/tarea32
│   └── fstab.ejemplo                # Líneas que se agregan a /etc/fstab
├── docs/
│   ├── politica_respaldos.md        # Política formal (RPO/RTO, retención, 3-2-1)
│   └── guion_video.md               # Guion para grabar el video
└── evidencias/                      # Salidas de 99_validar.sh y del simulacro
```

## Diseño de permisos

| Carpeta | Modo | Dueño:Grupo | ACL | Qué demuestra |
|---|---|---|---|---|
| `/srv/empresa/<depto>` | `2770` (rwxrws---) | root:depto | `g:admin_ti:r-x` + herencia | **SGID** y auditoría de solo lectura |
| `/srv/empresa/general` | `3770` (rwxrws--T) | root:empleados | herencia `g::r-x` | **Sticky**: nadie borra lo ajeno |
| `/srv/empresa/direccion` | `2770` | root:jefes | herencia | Solo jefes |
| `/srv/empresa/buzon_ti` | `3770` | root:sistemas | `g:empleados:-wx` | Depositar **sin poder listar** |
| `finanzas/reportes` | `2770` | root:finanzas | `g:jefes:r-x` (+ `--x` en finanzas) | ACL de **grupo** |
| `operaciones/inventario` | `2770` | root:operaciones | `u:pedro.ruiz:r-x` (+ `--x` en operaciones) | ACL de **usuario** |

## Cuotas (`/srv/empresa`)

| A quién | Blando | Duro | Inodos (blando/duro) |
|---|---|---|---|
| Empleado | 50 MB | 60 MB | 2000 / 2500 |
| Jefe | 100 MB | 120 MB | 4000 / 5000 |
| Grupo sistemas | 400 MB | 500 MB | — |
| Grupos finanzas / operaciones | 300 MB | 350 MB | — |
| Grupo empleados (general, buzón) | 200 MB | 250 MB | — |
| Grupo jefes (dirección) | 100 MB | 150 MB | — |

El periodo de gracia es de 24 horas.

## Política de respaldos (resumen)

| Elemento | Valor |
|---|---|
| Completo | Domingo 02:00 |
| Diferencial | Lunes a sábado 02:00 |
| Retención | 4 ciclos semanales |
| RPO | 24 h |
| RTO | ≤ 15 min para un archivo; ≤ 1 h para `/srv/empresa` |
| Medio | Disco dedicado, montado solo durante el respaldo |

El detalle completo está en [docs/politica_respaldos.md](docs/politica_respaldos.md).

## Uso

```bash
cd Unidad_3/Tarea_3.2
sudo bash scripts/00_preparar_discos.sh          # pide escribir FORMATEAR
sudo bash scripts/01_permisos_acl.sh
sudo bash scripts/02_cuotas.sh
sudo bash scripts/03_instalar_respaldos.sh --demo
sudo backup.sh completo                          # primer respaldo manual
sudo bash scripts/04_simulacro_restauracion.sh
sudo bash scripts/99_validar.sh
sudo bash scripts/03_instalar_respaldos.sh --sin-demo   # al terminar el video
```

Si tus discos no se llaman `sdb` y `sdc`:

```bash
sudo bash scripts/00_preparar_discos.sh --datos /dev/sdX --respaldos /dev/sdY
```

## Comandos útiles para capturas

```bash
getfacl /srv/empresa/finanzas/reportes
ls -ld /srv/empresa/*
sudo repquota -ugs /srv/empresa
sudo quota -us sofia.diaz
sudo restaurar.sh --listar
sudo tail -n 30 /var/log/tarea32_backup.log
journalctl -t backup.sh --since today
cat /etc/cron.d/tarea32-respaldos
```
