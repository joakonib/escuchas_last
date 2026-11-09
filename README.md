# escuchas_last

Proyecto en donde se descarga mi historial de escuchas de [Last.fm](https://www.last.fm/user/jgaldamesh), se enriquece con géneros, países, ánimo, popularidad, imágenes, letras y clima, y se generan reportes interactivos en HTML sobre lo que escucho desde 2013.

## 🌐 Ver los reportes

- 🏠 **Portada:** https://joakonib.github.io/escuchas_last/docs/
- 📈 **Reporte general:** https://joakonib.github.io/escuchas_last/docs/analisis_escuchas.html
- 📆 **Reporte del mes:** https://joakonib.github.io/escuchas_last/docs/reporte_mensual.html
- 🔧 **Cómo está hecho (metodología):** https://joakonib.github.io/escuchas_last/docs/metodologia.html

## Cómo fluyen los datos

Los archivos se numeran según el orden en que corren.

```
Last.fm API ─► scripts/00.descargar_escuchas.R ─► data/escuchas.parquet
                      01.verificar_escuchas.R     (compara contra el respaldo)
Last.fm API ─► scripts/02.descargar_tags.R ─────► data/tags_artistas.parquet
                                                  data/info_artistas.parquet
LRCLIB API ──► scripts/03.descargar_letras.R ───► data/letras.parquet
Open-Meteo ──► scripts/04.descargar_clima.R ────► data/clima.parquet
                      05.chequear_letras.R y 06.chequear_estilo.R (controles en el log)
Deezer API ──► R/imagenes.R ────────────────────► data/imagenes/
                                                        │
                                                        ▼
07.analisis_escuchas.qmd ──────────────────────► analisis_escuchas.html ──► docs/
08.generar_reporte_mensual.R + 08.reporte_mensual.qmd ► reporte_mensual.html ──► docs/
09.metodologia.qmd ────────────────────────────► metodologia.html ──► docs/
```

## Estructura

| Carpeta / archivo | Qué contiene |
|---|---|
| `07.analisis_escuchas.qmd` | Reporte general. También guarda los resultados clave en `data/resultados.rds`. |
| `08.reporte_mensual.qmd` | Reporte de un mes (parámetro `mes`, AAAA-MM). |
| `09.metodologia.qmd` | Recorrido de los datos, procesamiento y cada técnica utilizada. |
| `actualizar.bat` | Flujo mensual automático: descarga, reportes y publicación. |
| `scripts/` | Scripts numerados y `flujo_nocturno.sh`, la corrida completa con revisión de textos. |
| `R/` | Funciones de apoyo (detalle más abajo). |
| `assets/` | `estilo.css`, `redibujar.html` (gráficos dentro de pestañas) e ilustraciones de Ciro, la mascota. |
| `docs/` | Lo que se publica en GitHub Pages. |
| `FLUJO_DE_TRABAJO.txt` | Paso a paso de los dos flujos, criterios de diseño y de análisis, e historial de cambios. |
| `FUENTES.md` | Maestro de fuentes: APIs, papers y decisiones propias. |
| `ESTILO.md` | Cómo se escriben los textos y el código del proyecto. |

No se suben a GitHub (`.gitignore`): `data/`, `reportes/`, `input/`, `.Renviron` (credenciales) y los HTML de la raíz.

### Scripts

| Script | Qué hace |
|---|---|
| `00.descargar_escuchas.R` | Baja las escuchas con `user.getRecentTracks`. Incremental: solo pide lo posterior a la última escucha guardada. |
| `01.verificar_escuchas.R` | Compara la base con un respaldo (total no menor, rango, meses sin escuchas y duplicados). Si hay menos escuchas, se restaura el respaldo. |
| `02.descargar_tags.R` | Baja hasta 30 etiquetas, oyentes y reproducciones globales de cada artista. Incremental, guarda cada 200 artistas (tope con `N_ARTISTAS`). |
| `03.descargar_letras.R` | Baja de LRCLIB las letras de las canciones con 3 escuchas o más (`MIN_ESCUCHAS`). Incremental, guarda cada 100 canciones; con una segunda pasada de títulos limpios. |
| `04.descargar_clima.R` | Baja de Open-Meteo el clima diario de Santiago. Incremental. |
| `05.chequear_letras.R` | Resume las letras: filas, % encontradas, instrumentales, duplicadas, vacías y % de escuchas con letra. |
| `06.chequear_estilo.R` | Revisa que los textos del reporte sigan `ESTILO.md`. Solo informa. |
| `08.generar_reporte_mensual.R` | Renderiza el reporte de un mes (por defecto, el anterior), lo guarda en `reportes/` y lo copia a la raíz. |
| `flujo_nocturno.sh` | Corrida completa: `[--mes AAAA-MM] [--desde-cero] [--reentrenar] [--apagar]`. |

Si una consulta falla por la red, la canción o el artista no se registra y se reintenta en la próxima corrida.

### Funciones

| Archivo | Qué contiene |
|---|---|
| `R/datos.R` | Lectura y escritura segura de los datos, compartida por scripts y reportes. |
| `R/etiquetas.R` | Diccionarios de países y ánimo, y género y país de cada artista. |
| `R/letras.R` | Idioma, separación en palabras, sentimiento y nombres de los temas. |
| `R/modelos_estables.R` | LDA congelado para temas y playlists: lo nuevo se clasifica sin mover los temas. |
| `R/acm.R` | Análisis de correspondencias múltiples de los artistas. |
| `R/imagenes.R` | Fotos y portadas desde Deezer. |
| `R/visual.R` | Tablas, gráficos interactivos y navegación entre páginas. |

## Qué hay en los reportes

**General:** perfil musical, transiciones entre géneros, popularidad y huella en Last.fm, línea de tiempo, ritmo (franjas, sesiones, aperturas y cierres, discos o canciones), artistas y discos, exploración y omnivorismo, genealogía de descubrimientos, momentos (estaciones y pandemia), ánimo musical, clima, eras musicales, laboratorio (correspondencias múltiples, playlists ocultas, supervivencia y clasificación), letras (idioma, palabras, temas, y letra frente a sonido), lectura psicológica, obsesiones, flechazos, reencuentros, hitos y explorador de artistas.

**Mensual:** lo mejor del mes, artistas, discos, canciones y descubrimientos, géneros y países, ritmo, día a día y una comparación del mes con toda mi historia.

## Uso

1. Crear `.Renviron` en la raíz con `LASTFM_API_KEY=...` y `LASTFM_USER=...` (API key en https://www.last.fm/api/account/create).
2. Instalar `pacman`: los demás paquetes se cargan, y se instalan si faltan, con `pacman::p_load`.
3. Correr `actualizar.bat`, o los pasos por separado:
   ```
   Rscript scripts/00.descargar_escuchas.R
   Rscript scripts/02.descargar_tags.R
   Rscript scripts/03.descargar_letras.R
   Rscript scripts/04.descargar_clima.R
   quarto render 07.analisis_escuchas.qmd
   Rscript scripts/08.generar_reporte_mensual.R [AAAA-MM]
   quarto render 09.metodologia.qmd
   ```

## Actualización

- **Mensual automática:** la tarea **"Last.fm escuchas"** del Programador de tareas de Windows corre `actualizar.bat` el día 1 de cada mes a las 10:00, o en cuanto se prenda el computador si ese día estaba apagado. El log queda en `data/actualizacion.log`.
- **Corrida completa:** `scripts/flujo_nocturno.sh` agrega una pausa para revisar datos y textos antes de publicar. El log queda en `data/noche.log`.
- **Candado:** `data/flujo.lock` impide que los dos flujos corran a la vez.
- **Modelos:** los temas y playlists solo se reentrenan si lo nuevo supera el 15 % o con `--reentrenar`, y en ese caso hay que revisar sus textos.

El detalle está en `FLUJO_DE_TRABAJO.txt`.
