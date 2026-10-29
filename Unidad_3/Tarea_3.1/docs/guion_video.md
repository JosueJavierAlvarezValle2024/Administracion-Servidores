# Guion del video — Tarea 3.1 (≈ 8 min)

**Antes de grabar:**

- Snapshot de la VM.
- Cámara en la esquina inferior derecha.
- Ten abierta una terminal extra con `sudo -i` (por si te bloqueas).
- Si grabas fuera de 08:00–18:00, el horario de Finanzas te rechazará: es la prueba, úsalo a tu favor.

| # | Tiempo | Qué mostrar | Comandos |
|---|---|---|---|
| 1 | 0:00 | Presentación y esquema (diagrama del README) | — |
| 2 | 0:45 | CSV del lote | `cat data/usuarios.csv` |
| 3 | 1:15 | **Creación por lotes** | `sudo bash scripts/00_ejecutar_todo.sh` |
| 4 | 3:00 | Cuentas, grupos y caducidad | `id pedro.ruiz` · `sudo chage -l pedro.ruiz` · `getent group finanzas` |
| 5 | 3:45 | **Contraseña temporal forzada** | `sudo cat /root/tarea31_credenciales.csv` · `su - laura.mena` (pide cambiarla) |
| 6 | 4:30 | **Aislamiento de directorios** | `ls -ld /home/*` · como laura: `ls /home/pedro.ruiz` → Permiso denegado |
| 7 | 5:15 | **Permisos de ejecución / sudo** | como laura: `sudo apt update` ✓ y `sudo cat /etc/shadow` ✗ · como ana.torres: `sudo cat /etc/shadow` ✓ |
| 8 | 6:00 | **Horario restringido** | `su - jorge.cano` → denegado · `grep -A8 TAREA31 /etc/security/time.conf` |
| 9 | 6:45 | **Bloqueo por intentos** | 3 contraseñas incorrectas en `su - carlos.vega` · `sudo faillock --user carlos.vega` · `--reset` |
| 10 | 7:30 | Baja de usuario | `sudo bash scripts/03_baja_usuarios.sh sofia.diaz` · `su - sofia.diaz` → falla |
| 11 | 8:00 | Cierre: `99_validar.sh` con todas las pruebas en PASA | `sudo bash scripts/99_validar.sh` |
