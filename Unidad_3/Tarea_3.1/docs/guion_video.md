# Guion del video — Tarea 3.1 (≈ 8–10 min)

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: los bloques **🎙️ Qué decir** están en el mismo orden que la grabación. Léelos como apoyo y dilo con tus palabras.

**Graba entre las 06:00 y las 22:00:** laura.mena y carlos.vega son de **Operaciones**, que solo puede iniciar sesión en ese horario. Fuera de él, su `su -` dará *Permiso denegado* y las pruebas no saldrán como en el guion.

**Regla del `exit`:** escribe `exit` solo cuando el `su -` **sí entró** (el prompt cambia a `laura.mena@...`). Si el `su -` falla, sigues siendo el administrador y no hay nada de qué salir: un `exit` ahí cerraría tu terminal.

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

✓ = el comando debe funcionar · ✗ = el sistema debe negarlo (eso es lo que se quiere demostrar).

| # | Qué decir | Comandos | Qué debe aparecer |
|---|---|---|---|
| 1 | Nombre, materia, Tarea 3.1. "Voy a automatizar altas y bajas de usuarios y aplicar políticas de acceso." | — | — |
| 2 | "Este es el lote de usuarios: tres departamentos con distintos roles." | `cat data/usuarios.csv` | Encabezado y 8 usuarios (ana.torres … jorge.cano) |
| 3 | "Ejecuto la creación por lotes: grupos, usuarios, sudo, horarios y bloqueo." | `sudo bash scripts/00_ejecutar_todo.sh` | Muchas líneas `[ OK ]`; al final, la validación con `Pruebas que pasaron: 10` |
| 4 | "Pedro tiene como grupo principal Finanzas y como secundario empleados." | `id pedro.ruiz` | `gid=3002(finanzas) grupos=3002(finanzas),3010(empleados)` |
| 5 | "Su contraseña es temporal, caduca a los 90 días y la cuenta tiene fecha de expiración." | `sudo chage -l pedro.ruiz` | *se debe cambiar la contraseña*, máximo **90**, mínimo **1**, aviso **7**, cuenta caduca **jun 30, 2027** |
| 6 | "El grupo Finanzas existe con el GID 3002." | `getent group finanzas` | `finanzas:x:3002:` (la lista final sale **vacía**; ver explicación 6) |
| 7 | "Las contraseñas temporales solo las puede leer root." | `sudo cat /root/tarea31_credenciales.csv` | Una línea por usuario con su contraseña temporal. **Copia la de laura.mena** |
| 8 | **Contraseña forzada.** "Entro como laura.mena y el sistema me obliga a cambiar la contraseña." | `su - laura.mena` → pega la temporal; luego otra vez la temporal y dos veces la nueva (ej. `Operacion2026#Laura`) | *Es necesario cambiar su contraseña inmediatamente*; al final el prompt cambia a `laura.mena@...` |
| 9 | **Aislamiento.** "Los homes son privados: laura no puede entrar al de pedro." | `ls -ld /home/*` · `ls /home/pedro.ruiz` ✗ | `drwx------` en cada home · *no se puede abrir el directorio '/home/pedro.ruiz': Permiso denegado* |
| 10 | **sudo limitado.** "Operaciones solo tiene permitidos comandos puntuales: actualizar paquetes sí, leer contraseñas no." | `sudo apt update` ✓ · `sudo cat /etc/shadow` ✗ · `exit` | Pide la contraseña **nueva** de laura; luego `Obj:` / `Des:` y *Leyendo lista de paquetes… Hecho* · rechazo de sudo (*I'm sorry laura.mena. I'm afraid I can't do that*) · `exit` regresa al administrador |
| 11 | **Horario.** "jorge.cano pertenece a horario_prueba: nunca puede iniciar sesión, aunque su contraseña sea correcta." | `su - jorge.cano` ✗ (pon su contraseña temporal) · `grep -A8 TAREA31 /etc/security/time.conf` | `su: Permiso denegado` · las reglas: finanzas `Wk0800-1800`, operaciones `Al0600-2200`, horario_prueba `!Al0000-2400`. **Sin `exit`** |
| 12 | **Bloqueo.** "Tres contraseñas incorrectas bloquean la cuenta 5 minutos." | `su - carlos.vega` 3 veces con contraseña **mala** · 4.º intento con la **correcta** ✗ · `sudo faillock --user carlos.vega` · `sudo faillock --user carlos.vega --reset` | `su: Fallo de autenticación` ×3 · 4.º: *la cuenta está bloqueada debido a 3 inicios de sesión fallidos* · tabla con 3 intentos · el reset no muestra nada. **Sin `exit`** |
| 13 | **Baja.** "Doy de baja a sofia.diaz: la cuenta queda bloqueada pero se conservan sus archivos." | `sudo bash scripts/03_baja_usuarios.sh sofia.diaz` · `su - sofia.diaz` ✗ | `[ OK ] sofia.diaz deshabilitado (contrasena bloqueada, cuenta expirada, shell nologin)` · `su: Fallo de autenticación`. **Sin `exit`** |
| 14 | **Validación final.** "Este script comprueba de forma automática el aislamiento y los permisos." | `sudo bash scripts/99_validar.sh` | 10 líneas `[PASA]` y `Pruebas que pasaron: 10   Pruebas que fallaron: 0` |
| 15 | Cierre: "Con esto se automatizan las altas y bajas y se aplican las directivas de seguridad." | — | — |

## 🎙️ Qué decir en cada paso

Texto para cuando te grabes explicando el video. Los números corresponden a los pasos de la tabla.

**1.** Hola, soy Josué Javier Álvarez Valle, de la materia Administración de Servidores. En este video presento la Tarea 3.1: automatizar la creación y la baja de usuarios y grupos en Linux, y aplicar directivas de seguridad como privilegios de sudo, horarios de acceso y bloqueo por intentos fallidos.

**2.** Los usuarios no se crean uno por uno: se cargan desde este archivo CSV. Cada fila tiene el usuario, su nombre, el departamento, el rol, grupos extra y la fecha en que expira la cuenta. Hay tres departamentos: Sistemas, Finanzas y Operaciones.

**3.** Ejecuto el script principal, que hace todo en orden: crea los grupos y las carpetas de cada departamento, da de alta a los usuarios del CSV y configura sudo según el rol, los horarios de acceso y el bloqueo de cuentas. Cada paso muestra OK cuando termina bien, y al final se ejecuta una primera validación.

**4.** Con el comando id reviso a Pedro: su grupo principal es finanzas, que es su departamento, y además pertenece a empleados, el grupo que tienen todos los trabajadores.

**5.** Con chage veo la política de contraseñas de Pedro: dice que debe cambiar la contraseña, porque la que le dio el sistema es temporal; la contraseña caduca a los 90 días, avisa siete días antes y la cuenta tiene una fecha de expiración.

**6.** Con getent compruebo que el grupo finanzas existe con el número 3002. La lista de integrantes sale vacía porque María, Pedro y Sofía lo tienen como grupo principal, y Linux no repite en esta línea a quienes lo tienen como principal. Lo vimos con el comando id: Pedro sí pertenece a finanzas.

**7.** Las contraseñas temporales que generó el script quedan en este archivo, que solo root puede leer. Son las que se entregarían a cada empleado. Copio la de Laura para la siguiente prueba.

**8.** Inicio sesión como laura.mena, de Operaciones, con su contraseña temporal. El sistema no me deja continuar hasta que la cambio por una nueva, así nadie se queda con la contraseña que le dio el administrador.

**9.** Ya como Laura, listo las carpetas personales: todas tienen permisos drwx------, es decir, 700, solo su dueño puede entrar. Por eso, cuando intento abrir la carpeta de Pedro, aparece Permiso denegado.

**10.** Ahora pruebo sudo. Operaciones solo tiene permitidos dos comandos de mantenimiento: reiniciar el servicio cron y actualizar la lista de paquetes. Por eso sudo apt update sí funciona. Pero cuando Laura intenta leer /etc/shadow, el archivo donde están las contraseñas cifradas, sudo se lo niega. Así cada rol tiene solo los privilegios que necesita. Con exit regreso al administrador.

**11.** Ahora intento entrar como jorge.cano. Escribo su contraseña correcta y aun así el sistema responde Permiso denegado. Esto pasa porque Jorge pertenece al grupo horario_prueba. Las reglas están en /etc/security/time.conf: Finanzas solo puede entrar de lunes a viernes de 8 a 18 horas, Operaciones todos los días de 6 a 22, y horario_prueba nunca.

**12.** Ahora pruebo el bloqueo con carlos.vega: escribo tres veces una contraseña incorrecta. En el cuarto intento, aunque la contraseña es correcta, la cuenta ya está bloqueada por cinco minutos. Como administrador, con faillock veo los tres intentos fallidos registrados, y con la opción reset desbloqueo la cuenta.

**13.** Para dar de baja a Sofía, el script bloquea su contraseña, expira la cuenta y le quita la terminal, pero no la borra, así se conservan sus archivos. Si intento entrar como ella, el sistema no lo permite.

**14.** Por último, el script de validación hace pruebas automáticas de aislamiento y permisos, por ejemplo que un usuario no pueda entrar al home de otro ni a la carpeta de otro departamento, y todas aparecen como PASA.

**15.** Con esto queda automatizada la administración de usuarios y grupos, y aplicadas las directivas de seguridad: privilegios por rol, horarios de acceso y bloqueo de cuentas. Gracias.

## D. Después de grabar

- **Reactiva a sofia** para la Tarea 3.2: `sudo bash scripts/03_baja_usuarios.sh --reactivar sofia.diaz`.
- **Sube el video a YouTube** como **Público**, título "Tarea 3.1 – Automatización de usuarios y políticas de acceso", y copia el enlace para Teams.

**Capturas para el PDF** (puedes sacarlas del propio video):

- pasos 3, 4, 5 y 6;
- el cambio forzado (8);
- los "Permiso denegado" (9 y 11);
- sudo permitido y negado (10);
- el bloqueo (12);
- la baja (13);
- la validación con 10 PASA (14).
