# escuchas_last

Descarga mi historial de escuchas de [Last.fm](https://www.last.fm/user/jgaldamesh), lo enriquece con géneros, países, ánimo, popularidad, imágenes y letras, y genera dos reportes interactivos en HTML:

- **Reporte general** (`analisis_escuchas.html`): toda la historia desde 2013.
- **Reporte mensual** (`reporte_mensual.html`, con historial en `reportes/reporte_AAAA-MM.html`): solo lo escuchado en un mes, comparado con mi historia.

## 🌐 Ver los reportes

Ambos se publican en GitHub Pages:

- 🏠 **Portada:** https://joakonib.github.io/escuchas_last/docs/
- 📈 **Reporte general:** https://joakonib.github.io/escuchas_last/docs/analisis_escuchas.html
- 📆 **Reporte del mes:** https://joakonib.github.io/escuchas_last/docs/reporte_mensual.html

Todo se actualiza solo el día 1 de cada mes.

## Cómo fluyen los datos

```
Last.fm API ─► scripts/descargar_escuchas.R ─► data/escuchas.parquet ───────────┐
Last.fm API ─► scripts/descargar_tags.R ─────► data/tags_artistas.parquet ──────┤
                                               data/info_artistas.parquet ──────┤
LRCLIB API ──► scripts/descargar_letras.R ───► data/letras.parquet ─────────────┤
Deezer API ──► R/imagenes.R ─────────────────► data/imagenes/ ──────────────────┤
                                                                                ▼
                        analisis_escuchas.qmd ──► analisis_escuchas.html ──► docs/
                        reporte_mensual.qmd ────► reporte_mensual.html ────► docs/
                        (vía scripts/generar_reporte_mensual.R)
```

## Estructura

| Carpeta / archivo | Qué contiene |
|---|---|
| `analisis_escuchas.qmd` | Reporte general. |
| `reporte_mensual.qmd` | Reporte de un mes (parámetro `mes`, AAAA-MM). |
| `actualizar.bat` | Ciclo completo: descarga, reportes y publicación. Lo corre la tarea programada. |
| `scripts/` | Scripts que se ejecutan: `descargar_escuchas.R`, `descargar_tags.R`, `descargar_letras.R` y `generar_reporte_mensual.R`. |
| `R/` | Funciones de apoyo que usan los reportes: `etiquetas.R` (países, ánimo, géneros), `imagenes.R` (Deezer), `letras.R` (texto) y `visual.R` (tablas y gráficos interactivos). |
| `assets/` | `estilo.css` (diseño de ambos reportes) y `redibujar.html` (arregla los gráficos dentro de pestañas). |
| `docs/` | Lo que se publica en GitHub Pages: portada (`index.html`) y los dos reportes. |
| `FUENTES.md` | Maestro de fuentes: APIs, papers y decisiones propias. |

No se suben a GitHub (`.gitignore`): `data/` (escuchas, tags, letras, imágenes, log), `reportes/`, `input/`, `.Renviron` (credenciales) y los HTML de la raíz.

### Qué hace cada script

| Script | Qué hace |
|---|---|
| `descargar_escuchas.R` | Baja las escuchas con `user.getRecentTracks` (200 por página). Incremental: solo pide lo posterior a la última escucha guardada. |
| `descargar_tags.R` | Para los 500 artistas más escuchados baja hasta 30 etiquetas y sus oyentes globales. Incremental. |
| `descargar_letras.R` | Baja de LRCLIB las letras de las 1.500 canciones más escuchadas. Incremental, guarda cada 100 canciones. |
| `generar_reporte_mensual.R` | Renderiza el reporte de un mes (por defecto, el anterior), lo guarda en `reportes/` y lo copia a la raíz. |

## Qué hay en los reportes

**General:** perfil musical, países con banderas, personalidad de oyente (año a año), popularidad, modelo MUSIC, línea de tiempo, ritmo, artistas y discos, omnivorismo, momentos (madrugada, fin de semana, estaciones, pandemia), ánimo musical (valencia y energía), eras musicales (clustering con restricción temporal), laboratorio (análisis de correspondencias, playlists ocultas con LDA, supervivencia de Kaplan-Meier, árbol de decisión), letras (idioma, palabras y temas con LDA), lectura psicológica, obsesiones, hitos y explorador de artistas.

**Mensual:** lo mejor del mes (artista, canción y disco), artistas, discos, canciones y descubrimientos, géneros y países del mes, ritmo, día a día, y un análisis que compara el mes con toda mi historia (rareza, subidas y bajadas, ánimo, era más parecida y proyección del año).

Las fuentes y los supuestos de cada análisis están en `FUENTES.md`.

## Uso

1. Crear `.Renviron` en la raíz con `LASTFM_API_KEY=...` y `LASTFM_USER=...` (API key en https://www.last.fm/api/account/create).
2. Correr `actualizar.bat`, o los pasos por separado:
   ```
   Rscript scripts/descargar_escuchas.R
   Rscript scripts/descargar_tags.R
   Rscript scripts/descargar_letras.R
   quarto render analisis_escuchas.qmd
   Rscript scripts/generar_reporte_mensual.R [AAAA-MM]
   ```

Paquetes de R: `httr2`, `dplyr`, `tidyr`, `purrr`, `readr`, `arrow`, `lubridate`, `ggplot2`, `ggrepel`, `forcats`, `stringr`, `scales`, `reactable`, `plotly`, `htmltools`, `topicmodels`, `slam`, `stopwords`, `survival` y `rpart`.

## Actualización automática

La tarea **"Last.fm escuchas"** del Programador de tareas de Windows corre `actualizar.bat` el **día 1 de cada mes a las 10:00**, o en cuanto se prenda el computador si ese día estaba apagado. Al final copia los reportes a `docs/` y hace commit, pull y push, así que GitHub Pages queda al día. El log queda en `data/actualizacion.log`.
