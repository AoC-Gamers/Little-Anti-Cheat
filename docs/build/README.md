# Compilación y distribución

GNU Make y Python 3.10 o posterior ejecutan las mismas fases en local y en
[GitHub Actions](../../.github/workflows/sourcemod-build.yml).

```sh
make deps-smx
make build-smx
make package-smx
make release
make validate-artifact
```

- `deps-smx` descarga `spcomp` y sus includes en `.deps/smx/`. `SOURCEMOD_VERSION` selecciona la rama publicada de SourceMod. El valor predeterminado es `1.12` y el build concreto depende del SDK descargado.
  `SPCOMP` permite seleccionar un compilador ya instalado.
- `build-smx` deja los binarios y recursos en `.build/smx/` y el diagnóstico en
  `.build/build-smx-compile.log`.
- `package-smx` prepara y valida el árbol en `.build/package-smx/`.
- `release` prepara `dist/sourcemod/artifact/`, lo valida y genera el ZIP local
  en `dist/release/`. `RELEASE_BASENAME` permite cambiar el nombre.
- `validate-artifact` compara el árbol final con el mapa y las fuentes actuales.
  `SOURCEMOD_ARTIFACT_DIR` permite seleccionar otro árbol.
- `clean` limpia `.build/` y `dist/`. `clean-all` también limpia `.deps/`.

Desde otro directorio se puede usar `make -f "/ruta/al repositorio/Makefile" <target>`.
Las rutas relativas de las opciones de build y paquete se resuelven desde el
repositorio. Las variables se pueden pasar a Make o heredar del entorno.

## Contenido

El [mapa de paquete](../../scripts/package/package-map.json) declara los
entrypoints, sus destinos y los archivos que acompañan a cada plugin.

- `lilac.sp` → `addons/sourcemod/plugins/lilac.smx`

Consulta los términos y la autoría de Little Anti-Cheat en el encabezado de `lilac.sp` y el texto GPL en `LICENSE`.
El ZIP incluye las fuentes SourcePawn de producto, los recursos seleccionados, el
README y los textos legales disponibles. El mapa, las guías técnicas y el log de
compilación se consultan por separado.

## Dependencias

El build utiliza los includes de SourceMod y los que están versionados en
`addons/sourcemod/scripting/include/`. Consulta [Integraciones de Little Anti-Cheat](../detections/README.md)
para los proveedores del juego y los requisitos de ejecución.

## Pruebas

Usa `make test-ci` para la regresión del banner de inicio. `make build-smx` ejecuta la misma prueba mediante `check-startup-print`.

## CI

GitHub Actions usa la variable de organización `SOURCEMOD_VERSION` para
seleccionar la rama del SDK. La preparación falla si la variable falta o tiene
un formato distinto de `mayor.menor`.

GitHub Actions ejecuta las fases de Make y conserva un ZIP por SHA. En eventos `push`, `publish-channel` publica el ZIP con el nombre del canal y después avanza su etiqueta. Las pull requests generan artefactos temporales.

El [workflow de releases versionadas](../../.github/workflows/release.yml) conserva el prefijo de tags y los nombres de ZIP del proyecto.
