# Little Anti-Cheat: Resumen funcional

Little Anti-Cheat es un anti-trampa gratuito y de código abierto para juegos basados en Source, y funciona sobre SourceMod.

Originalmente fue desarrollado para servidores privados. Más adelante fue publicado para ayudar a la comunidad. No es un anti-cheat perfecto y puede ser evadido en cierta medida, pero sigue siendo una herramienta útil para reducir el impacto de jugadores con trampas.

## Detecciones actuales

- Trampas de ángulo.
  - Incluye casos como anti-backstab ilegítimo en TF2, anti-aim básico y `duckspeed`.
- Limpieza de chat.
  - Detecta cuando cheats manipulan o limpian el chat.
- Detector básico de ConVars inválidas.
  - Comprueba valores como `sv_cheats` y otras variables anómalas.
- BunnyHop (`Bhop`).
- Aimbot básico para proyectiles e impactos instantáneos.
- Aimlock básico.
- Anti-Duck-Delay / FastDuck.
  - Solo para CS:GO.
- Saltos de línea en nombres de jugador.

## Funcionalidades adicionales

- Parche de trampas de ángulo.
- Expulsión por interpolación anómala.
  - Por ejemplo, intentos de explotar `cl_interp 0.5`.
- Expulsión por ping excesivo.
  - Desactivada por defecto.
- Parche contra backtrack.
  - Desactivado por defecto.
- Detección de macros.
- Detección de nombres inválidos.
- Filtro de caracteres inválidos en chat.
  - Incluye correcciones para abusos relacionados con limpieza de chat.

## Integración con BanSystem

Cuando `lilac_bansystem` está habilitado, Lilac solicita el ban mediante
`BSAccess_RequestLilacBan`, enviando sólo jugador, detección, minutos y motivo.
El bool retornado sólo indica admisión en memoria.

BanSystem aplica permisos, inmunidad y validaciones del caller real `lilac.smx`.
Core aplica sólo tras confirmar durabilidad. Si SAN está apagado o falta el
proveedor/ABI, la integración falla cerrado: Lilac no arma un kick diferido ni
prueba otro proveedor. Con `lilac_bansystem=0`, los otros proveedores conservan
su selección propia. Este corte no cambia flags ni instala binarios.

### Seguimiento de Aimbot y Aimlock

`lilac_cheater_detected(client, cheat)` se emite desde la primera detección
normalizada, incluso si no llega a sospecha ni a ban. Aimbot/Aimlock notifican
antes de actualizar su contador; los consumidores no deben inferir ese contador
desde el forward. Aimlock normaliza dos señales cercanas antes de emitirlo.
BanSystem Demo puede conservar cada evento como metadata privada, con identidad
y tick propios, sin cambiar avisos o umbrales de Lilac.

El include público `lilac.inc` expone `lilac_aim_tracking_started` y
`lilac_aim_tracking_ended`. Lilac inicia un seguimiento al alcanzar dos
detecciones normalizadas del mismo jugador y cheat dentro de sus ventanas de
sospecha de diez minutos. La detección que cruza el umbral primero dispara
`lilac_cheater_detected` y luego `lilac_aim_tracking_started`. La identidad del
seguimiento usa Steam account ID y SteamID64; el índice `client` solo identifica
el slot mientras está conectado. BanSystem Demo consume esos eventos y mantiene
sus propias claves de evidencia; no entrega esas claves a Lilac.

El cierre informa uno de cuatro motivos: `Expired`, `Disconnected`,
`BanRequested` o `PluginUnload`. En un ban, el orden es
`lilac_cheater_banned`, solicitud a Access si BanSystem está seleccionado y
`lilac_aim_tracking_ended(BanRequested)`. Así BanSystem puede consultar su propio
contexto mientras el seguimiento sigue activo. Ningún forward confirma que una
sanción se haya guardado o aplicado. Sin BanSystem se conserva la selección de
los demás proveedores, sin incorporar lógica de correlación a Lilac.

Los vencimientos usan timers individuales vinculados a account ID, cheat,
generación del registro e ID de detección; un cambio de mapa o de slot no los
deja huérfanos. En L4D2, `map_transition` conserva el registro al desconectar
clientes para el cambio de capítulo. Lilac restaura sus contadores al autorizar
la identidad en el mapa nuevo. Hay una gracia de 120 segundos desde `OnMapStart`
para que los jugadores vuelvan; si una identidad del capítulo anterior no
reingresa, el seguimiento termina como `Disconnected`. Una desconexión normal
cierra el seguimiento y limpia sus sospechas. La validación real de una
transición de capítulo queda pendiente de smoke test en SRCDS.

Las detecciones previas a la autorización conservan contador y deadline
legacy por userid. Si Steam autoriza antes del vencimiento, Lilac las migra al
registro estable con el tiempo restante. Si ocurre `map_transition` primero,
Lilac descarta solo esas detecciones sin identidad estable; no extiende su
ventana ni las atribuye a un slot reutilizado. No se emite un tracking sin una
identidad de Steam válida. Una desconexión real dentro de `map_transition` no
se puede distinguir de la desconexión sintética del cambio de capítulo; se
conserva como carry y se cierra como `Disconnected` si no vuelve en 120 segundos.

El include también ofrece `lilac_GetAimTrackingCount()` y
`lilac_GetAimTrackingInfo(index, client, cheat, accountId, steamId64, maxlen)`
para que consumidores cargados tarde recuperen una instantánea estable. `client`
vale `0` si la identidad no está conectada. `lilac_IsAimTracking(client, cheat)`
consulta el estado desde un slot conectado.

## Juegos compatibles

- `[TF2]` Team Fortress 2
- `[CS:GO]` Counter-Strike: Global Offensive
- `[CS:S]` Counter-Strike: Source
- `[L4D2]` Left 4 Dead 2
- `[L4D]` Left 4 Dead
- `[DoD:S]` Day of Defeat: Source

## Preguntas frecuentes

### ¿Qué es Autoshoot?

Autoshoot es cuando un cheat dispara un tiro perfecto de un solo tick. Es común en ciertos aimbots.

La detección busca disparos perfectos de un tick que terminan en una muerte dos veces seguidas. También puede quedar registrado si al mismo tiempo se detecta otro tipo de aimbot.

Puede existir un falso positivo, pero debería ser raro. Un caso conocido es usar binds como `bind mwheeldown +attack`, porque la rueda del mouse puede generar entradas extremadamente precisas de un tick.

Además, como esta función dispara por el jugador, no es fácil verificarla observando al sospechoso o revisando demos de STV. Autoshoot no se ve claramente en demos ni para espectadores.

### ¿Qué es Anti-Duck-Delay / FastDuck?

Es una técnica de cheat en CS:GO que manipula entradas del `usercmd` de una forma imposible para un jugador legítimo.

Es extremadamente común en cheats de CS:GO, por eso una gran parte de los castigos de Lilac en ese juego suelen venir de esta detección. Si alguien es castigado por esta vía, en términos prácticos se considera una señal muy fuerte de trampa real.

### ¿Qué es NoLerp?

`NoLerp` es cuando un cheat fuerza la interpolación a `0 ms` o a valores inferiores al mínimo posible.

Eso suele hacerse para mejorar la precisión del aimbot.

### ¿Qué son las trampas de ángulo?

Son manipulaciones de ángulos de visión más allá de los límites válidos del juego.

Esto puede usarse para:
- desincronizar modelo e hitbox
- dificultar que otros jugadores impacten disparos
- ejecutar otros abusos, como `duckspeed` en TF2

Nota: Lilac no cubre todos los casos posibles de desincronización. En especial, hay escenarios ligados a `yaw` que no necesariamente quedan detectados.

### ¿Las macros cuentan como trampas?

No en el mismo sentido que un cheat interno.

Una macro es, por ejemplo:
- un script externo como AutoHotKey
- un uso de rueda del mouse para spamear inputs

Por eso sus castigos suelen ser más acotados que los de un cheat tradicional. También están desactivadas por defecto en muchos entornos porque no todos los servidores quieren tratarlas como una infracción fuerte.

### ¿Lilac castiga por ping alto?

No exactamente como castigo permanente.

El módulo opcional de ping alto aplica una expulsión temporal corta, para evitar que un jugador con latencia extrema vuelva a entrar de inmediato tras un simple kick. Está pensado más como una medida operativa que como una detección de cheat.
