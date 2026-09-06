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

Cuando `lilac_bansystem` está habilitado y la native
`BSAccess_AddBanByAccountId` está disponible, Lilac solicita la sanción con
administrador `0` y el emisor explícito `Lilac Anti-Cheat`. BanSystem puede así
distinguir una detección automática de una orden escrita directamente en la
terminal, cuyo emisor por defecto es `Console`.

El nombre del emisor es información de trazabilidad; no concede permisos ni
reemplaza las validaciones de BanSystem. Si la solicitud no es aceptada, Lilac
conserva su cadena de fallback hacia los demás proveedores configurados.

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
