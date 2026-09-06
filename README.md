# Little Anti-Cheat

Fork mantenido por AoC del proyecto original **Little Anti-Cheat**.

## Estado del fork

Este fork será mantenido por AoC con un enfoque práctico en:
- Left 4 Dead 2
- despliegue reproducible
- artefactos de SourceMod listos para instalación
- compatibilidad con el layout estándar usado en otros repositorios públicos del ecosistema AoC

## Enfoque

Aunque Lilac soporta varios juegos del motor Source, este fork prioriza:
- compatibilidad operativa con Left 4 Dead 2
- organización del repositorio para distribución
- automatización de compilación y publicación

Eso no implica eliminar el soporte existente para otros juegos, pero sí deja claro cuál es el objetivo principal del mantenimiento de AoC.

## Estructura del repositorio

El proyecto fue reorganizado al layout estándar de distribución para SourceMod dentro de `addons/sourcemod`.

Esto permite:
- compilar con un flujo uniforme
- generar artefactos consistentes
- integrarlo con el mismo sistema de instalación usado en otros proyectos AoC

## Artefactos

La CI genera artefactos listos para instalación con el plugin compilado, su include público y las traducciones necesarias para runtime.

Los pushes a `develop` actualizan `channel/develop` y los pushes a `main`
actualizan `channel/latest`. Las releases `vX.Y.Z` permanecen separadas de
estos canales móviles.

## Build local

```bash
make deps-smx
make build-smx
make package-smx
make release
```

El contenido publicado se describe en [plugin-package-map.json](C:\GitHub\Little-Anti-Cheat\plugin-package-map.json) y el flujo completo está documentado en [docs/BUILD_SYSTEM.md](C:\GitHub\Little-Anti-Cheat\docs\BUILD_SYSTEM.md).

## Créditos

- Proyecto original: **Little Anti-Cheat**
- Autor original: **J_Tanzanite**

## Documentación adicional

- [Resumen funcional en español](C:\GitHub\Little-Anti-Cheat\docs\OVERVIEW_ES.md)
- [Notas finales del autor original](C:\GitHub\Little-Anti-Cheat\docs\ORIGINAL_NOTES.md)
