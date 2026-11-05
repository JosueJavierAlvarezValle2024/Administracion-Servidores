# Guion del video — Tarea 3.1 (≈ 8–10 min)

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: los bloques **🎙️ Qué decir** están en el mismo orden que la grabación. Léelos como apoyo y dilo con tus palabras.

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

## 🎙️ Qué decir en cada paso

Texto para cuando te grabes explicando el video. Los números corresponden a los pasos de la tabla.

**1.** Hola, soy Josué Javier Álvarez Valle, de la materia Administración de Servidores. En este video presento la Tarea 3.1: automatizar la creación y la baja de usuarios y grupos en Linux, y aplicar directivas de seguridad como privilegios de sudo, horarios de acceso y bloqueo por intentos fallidos.

**2.** Los usuarios no se crean uno por uno: se cargan desde este archivo CSV. Cada fila tiene el usuario, su nombre, el departamento, el rol y la fecha en que expira la cuenta. Hay tres departamentos: Sistemas, Finanzas y Operaciones.

**3.** Ejecuto el script principal, que hace todo en orden: crea los grupos y las carpetas de cada departamento, da de alta a los usuarios del CSV y configura sudo según el rol, los horarios de acceso y el bloqueo de cuentas. Cada paso muestra OK cuando termina bien.

**4.** Con el comando id compruebo los grupos. Ana tiene como grupo principal Sistemas y, por ser jefa, también pertenece a jefes y admin_ti. Pedro es de Finanzas y solo tiene los grupos de un empleado normal.

**5.** Con chage veo la política de contraseñas: el cambio es obligatorio en el primer inicio de sesión, la contraseña caduca a los 90 días, avisa siete días antes y la cuenta tiene fecha de expiración.

**6.** Cada carpeta personal tiene permisos 700: solo su dueño puede entrar, así ningún usuario puede leer los archivos de otro.

**7.** Las contraseñas temporales que generó el script quedan en este archivo, que solo root puede leer. Son las que se entregarían a cada empleado.

**8.** Inicio sesión como luis.rios con su contraseña temporal. El sistema no me deja continuar hasta que la cambio por una nueva, así nadie se queda con la contraseña que le dio el administrador.

**9.** Como Luis intento entrar a la carpeta de Pedro y a la de Finanzas, y en ambos casos aparece Permiso denegado. En cambio, sí puedo crear un archivo en la carpeta de Sistemas, que es su departamento.

**10.** Luis es técnico, así que sudo solo le permite comandos de soporte, como actualizar la lista de paquetes. Cuando intenta leer el archivo de contraseñas /etc/shadow, sudo se lo niega.

**11.** Ana es jefa de Sistemas y pertenece a admin_ti, que tiene sudo completo. Por eso ella sí puede leer /etc/shadow.

**12.** Pedro, de Finanzas, no tiene ningún privilegio de sudo: el sistema indica que no puede ejecutar nada como administrador.

**13.** Las reglas de horario están en /etc/security/time.conf. Finanzas solo puede entrar de lunes a viernes de 8 a 18 horas, y el grupo horario_prueba no puede entrar nunca. Por eso, aunque escribo la contraseña correcta de Jorge, el acceso se niega.

**14.** Ahora pruebo el bloqueo: escribo tres veces una contraseña incorrecta para Ana. En el cuarto intento, aunque la contraseña es correcta, la cuenta ya está bloqueada. Con faillock veo los intentos fallidos y, como administrador, la desbloqueo para que pueda volver a entrar.

**15.** Para dar de baja a Sofía, el script bloquea su cuenta en lugar de borrarla, así se conservan sus archivos. passwd muestra la letra L de bloqueada, y si intento entrar como ella, no puedo.

**16.** Por último, el script de validación hace pruebas automáticas de aislamiento y permisos, y todas aparecen como PASA.

**17.** Con esto queda automatizada la administración de usuarios y grupos, y aplicadas las directivas de seguridad: privilegios por rol, horarios de acceso y bloqueo de cuentas. Gracias.

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
