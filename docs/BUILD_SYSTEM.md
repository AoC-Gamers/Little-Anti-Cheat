# Build System

Este repositorio usa el flujo homologado de AoC para proyectos solo-`smx`.

## Flujo

1. `make deps-smx`
2. `make build-smx`
3. `make package-smx`
4. `make release`

## Targets

- `deps-smx`: descarga el compilador de SourceMod para el sistema actual.
- `build-smx`: compila `lilac.sp` y genera un árbol local en `.build/smx`.
- `package-smx`: arma el paquete intermedio en `.build/package-smx`.
- `release`: genera `dist/sourcemod/artifact` y el ZIP final en `dist/release/`.

## Manifiesto

El archivo [plugin-package-map.json](../plugin-package-map.json) define:

- qué plugins se compilan
- qué archivos fuente se adjuntan
- qué include público se publica
- qué directorios de traducción se copian al artifact

## CI

La CI usa el mismo camino local:

1. `deps-smx`
2. `build-smx`
3. `package`

El job `package` reutiliza el output compilado, genera el artefacto final y lo
valida antes de publicarlo. Cada ejecución conserva un ZIP identificado por el
SHA completo del commit. En eventos `push`, las ramas mantienen además los
canales móviles consumidos por el instalador:

- `develop` publica `little-anti-cheat-develop.zip` en `channel/develop`.
- `main` publica `little-anti-cheat-latest.zip` en `channel/latest`.

El asset se publica antes de avanzar la etiqueta del canal, evitando que una
falla de subida deje la etiqueta apuntando a un commit sin ZIP utilizable. Los
pull requests y ejecuciones manuales validan y conservan su artefacto, pero no
modifican los canales móviles. Las versiones semánticas `vX.Y.Z` continúan en
el workflow de release independiente.
