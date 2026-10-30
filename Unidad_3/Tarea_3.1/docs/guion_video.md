# Guion del video — Tarea 3.1 (≈ 8–10 min)

Funciona a cualquier hora: las pruebas de inicio de sesión usan usuarios de **Sistemas**, que no tienen restricción de horario.

## A. Preparar OBS (en Windows)

1. Fuente **Captura de ventana**: la ventana de VirtualBox con la VM.
2. Fuente **Dispositivo de captura de video**: tu cámara web.
   - Hazla pequeña (≈ 20 % de la pantalla) y colócala en la **esquina inferior derecha**.
   - Clic derecho → *Transformar → Ajustar a pantalla* solo en la captura de ventana; la cámara la acomodas a mano.
3. Revisa que el **micrófono** marque nivel en el mezclador de audio.
4. En *Ajustes → Salida → Formato de grabación*, elige **MP4 fragmentado** (o MKV y luego *Archivo → Remezclar*).

## B. Preparar la VM (antes de grabar, sin grabar)

```bash
cd ~/Administracion-Servidores/Unidad_3/Tarea_3.1
git pull
sudo bash scripts/98_revertir.sh --si      # deja el sistema limpio para crear todo en vivo
sudo rm -f /root/tarea31_credenciales.csv
clear
```

- **Letra grande:** en la terminal, *Editar → Preferencias → Apariencia*, tamaño 14 o más.
- **Segunda pestaña** (`Ctrl+Shift+T`) con `sudo -i` abierta, por seguridad.

## C. Grabación

| # | Qué decir | Comandos |
|---|---|---|
| 1 | Nombre, materia, Tarea 3.1. "Voy a automatizar altas y bajas de usuarios y aplicar políticas de acceso." | — |
| 2 | "Este es el lote de usuarios: tres departamentos con distintos roles." | `cat data/usuarios.csv` |
| 3 | "Ejecuto la creación por lotes: grupos, usuarios, sudo, horarios y bloqueo." | `sudo bash scripts/00_ejecutar_todo.sh` |
| 4 | "Cada usuario tiene grupo primario de su departamento y grupos secundarios según su rol." | `id ana.torres` · `id pedro.ruiz` · `getent group jefes` |
| 5 | "La contraseña es temporal: caduca a los 90 días y la cuenta expira en una fecha definida." | `sudo chage -l pedro.ruiz` |
| 6 | "Los homes son privados, modo 700." | `ls -ld /home/*` |
| 7 | "Las contraseñas temporales solo las puede leer root." | `sudo cat /root/tarea31_credenciales.csv` |
| 8 | **Contraseña forzada.** "Entro como luis.rios con la temporal y el sistema me obliga a cambiarla." | `su - luis.rios`. Pega la temporal (selecciónala y usa `Ctrl+Shift+C` / `Ctrl+Shift+V`), luego otra vez la temporal y dos veces la nueva (ej. `Soporte2026#Luis`) |
| 9 | **Aislamiento.** "Como luis, no puedo entrar al home de otro ni a la carpeta de Finanzas, pero sí a la de Sistemas." | `ls /home/pedro.ruiz` ✗ · `ls /srv/empresa/finanzas` ✗ · `touch /srv/empresa/sistemas/prueba.txt` ✓ |
| 10 | **sudo limitado.** "Luis es técnico: solo tiene comandos de soporte." | `sudo -l` · `sudo apt update` ✓ · `sudo cat /etc/shadow` ✗ · `exit` |
| 11 | **sudo total.** "Ana es jefa de Sistemas, grupo admin_ti: puede todo." | `su - ana.torres` (cambia su contraseña) · `sudo head -3 /etc/shadow` ✓ · `exit` |
| 12 | **Sin sudo.** "Finanzas no tiene privilegios." | `sudo -l -U pedro.ruiz` |
| 13 | **Horario.** "jorge.cano pertenece a horario_prueba: nunca puede iniciar sesión. Finanzas solo de 8 a 18." | `grep -A8 'BEGIN TAREA31' /etc/security/time.conf` · `su - jorge.cano` → *Permiso denegado* (pon su contraseña correcta) |
| 14 | **Bloqueo.** "Tres contraseñas incorrectas bloquean la cuenta 5 minutos." | `su - ana.torres` 3 veces con contraseña mala · 4.º intento con la **correcta** → bloqueada · `sudo faillock --user ana.torres` · `sudo faillock --user ana.torres --reset` · `su - ana.torres` ✓ · `exit` |
| 15 | **Baja.** "Doy de baja a sofia.diaz: la cuenta queda bloqueada pero se conserva su información." | `sudo bash scripts/03_baja_usuarios.sh sofia.diaz` · `sudo passwd -S sofia.diaz` (muestra **L**) · `su - sofia.diaz` ✗ |
| 16 | **Validación final.** "Este script comprueba de forma automática el aislamiento." | `sudo bash scripts/99_validar.sh` |
| 17 | Cierre: "Con esto se automatizan las altas y bajas y se aplican las directivas de seguridad." | — |

## D. Después de grabar

- **Reactiva a sofia** para la Tarea 3.2: `sudo bash scripts/03_baja_usuarios.sh --reactivar sofia.diaz`.
- **Sube el video a YouTube** como **Público**, título "Tarea 3.1 – Automatización de usuarios y políticas de acceso", y copia el enlace para Teams.

**Capturas para el PDF** (puedes sacarlas del propio video):

- pasos 3, 4, 5 y 6;
- el cambio forzado (8);
- los "Permiso denegado" (9 y 13);
- `sudo -l` de los tres roles (10, 11 y 12);
- el bloqueo (14);
- la validación con 10 PASA (16).
