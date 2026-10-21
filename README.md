# escuchas_last

Descarga mi historial de escuchas de [Last.fm](https://www.last.fm/user/jgaldamesh), lo enriquece con géneros, países, ánimo, popularidad e imágenes, y genera dos reportes en HTML:

- **Reporte general** (`analisis_escuchas.html`): toda la historia desde 2013. Perfil musical, personalidad de oyente, géneros, ritmo diario, artistas, eras, ánimo y más.
- **Reporte mensual** (`reportes/reporte_AAAA-MM.html`): solo lo escuchado en un mes.

Todo se actualiza solo el día 1 de cada mes.

## Cómo fluyen los datos

```
Last.fm API ──► descargar_escuchas.R ──► data/escuchas.parquet ─────────────┐
                                                                            │
Last.fm API ──► descargar_tags.R ──────► data/tags_artistas.parquet ────────┤
                                         data/info_artistas.parquet ────────┤
                                                                            ▼
Deezer API ───► R/imagenes.R ──────────► data/imagenes/ ──────► analisis_escuchas.qmd ──► analisis_escuchas.html
                                                          └───► reporte_mensual.qmd ────► reportes/reporte_AAAA-MM.html
                                                                (vía generar_reporte_mensual.R)
```

## Archivos

| Archivo | Qué hace |
|---|---|
| `descargar_escuchas.R` | Descarga las escuchas con `user.getRecentTracks` (200 por página, 4 consultas por segundo). Es **incremental**: solo pide lo posterior a la última escucha guardada. Guarda en Parquet; si encuentra un CSV de versiones antiguas, lo migra y lo borra. |
| `descargar_tags.R` | Para los 500 artistas más escuchados baja hasta 30 etiquetas (`artist.getTopTags`) y los oyentes globales (`artist.getInfo`). Incremental: solo consulta artistas nuevos. |
| `R/imagenes.R` | Busca fotos de artistas y portadas de discos en Deezer. Solo acepta coincidencias exactas de nombre; si no hay, deja un archivo `.none` para no volver a buscar y la galería muestra las iniciales. Cada imagen se descarga una sola vez. |
| `analisis_escuchas.qmd` | Reporte general (ver secciones abajo). |
| `reporte_mensual.qmd` | Reporte de un mes: cifras, artistas y discos con imagen, canciones, álbumes, escuchas por día y descubrimientos. Recibe el mes como parámetro `mes` (AAAA-MM). |
| `generar_reporte_mensual.R` | Renderiza el reporte mensual (por defecto, del mes anterior) y lo deja en `reportes/`. |
| `actualizar.bat` | Corre todo en orden; lo usa la tarea programada. |
| `estilo.css` | Estilos de ambos reportes (grises y verdes, sin azul). |
| `FUENTES.md` | Maestro de fuentes: APIs, papers y decisiones propias. |

Carpetas que **no** se suben a GitHub (`.gitignore`): `data/` (escuchas, tags, imágenes, log), `reportes/`, `input/` (historial de Spotify, pendiente), `.Renviron` (credenciales) y el HTML del reporte general.

## Qué hay en el reporte general

| Sección | Qué muestra | Cómo se calcula |
|---|---|---|
| Cifras | Escuchas, horas, artistas, canciones, racha más larga | Horas = escuchas × 3,5 min |
| Mi perfil musical | Texto escrito a mano a partir de los resultados + géneros y países | Género = etiqueta de mayor peso del artista, sin etiquetas genéricas ("seen live"); país = etiqueta de nacionalidad |
| Personalidad de oyente | Familiar/Explorador, Variado/Leal, Rotador/Repetidor, Popular/De nicho | Últimos 12 meses, con umbrales propios (ver `FUENTES.md`) |
| Nicho y joyas escondidas | Popularidad de lo que escucho | Oyentes globales del artista en Last.fm |
| Modelo MUSIC | Peso de 5 dimensiones de preferencia musical | Etiquetas asignadas a cada dimensión |
| Línea de tiempo y calendario | Escuchas por mes y por día | — |
| Mi ritmo | Hora y día de la semana, sesiones | Sesión = escuchas separadas por menos de 30 minutos |
| Mis artistas y discos | Galerías con imagen, ranking anual, artista y canción de cada año | — |
| Explorar o volver a lo conocido | Diversidad por año, géneros en el tiempo | Artista "nuevo" = primera escucha ese año |
| Momentos | Artistas de madrugada y de fin de semana, géneros por estación, pandemia | Estaciones del hemisferio sur; pandemia = estado de catástrofe en Chile |
| Mi ánimo musical | Valencia y energía por año, por hora y días extremos | Etiquetas de ánimo ubicadas en el modelo de Russell |
| Mis eras musicales | Etapas según la mezcla de géneros | k-means (k = 5) sobre la proporción mensual de géneros |
| Lectura psicológica | Interpretación lúdica de mis gustos | Investigación sobre música y personalidad (ver `FUENTES.md`) |
| Obsesiones, olvidados, hitos | Canciones en loop, artistas abandonados, escuchas n.º 1, 10.000… | — |
| Explorador de artistas | Tabla con buscador | Artistas con al menos 20 escuchas |

**Limpieza de datos:** se excluyen escuchas con fecha anterior a 2002 (Last.fm guarda algunas sin fecha válida como 01-01-1970). Las horas se analizan en hora de Chile (`America/Santiago`).

## Uso

1. Crear `.Renviron` en la raíz:
   ```
   LASTFM_API_KEY=...
   LASTFM_USER=...
   ```
   (API key en https://www.last.fm/api/account/create)
2. `Rscript descargar_escuchas.R`
3. `Rscript descargar_tags.R`
4. `quarto render analisis_escuchas.qmd`
5. `Rscript generar_reporte_mensual.R [AAAA-MM]` (sin argumento: mes anterior)

Paquetes de R: `httr2`, `dplyr`, `tidyr`, `purrr`, `readr`, `arrow`, `lubridate`, `ggplot2`, `forcats`, `stringr`, `scales`, `gt`, `reactable`, `htmltools`.

## Actualización automática

`actualizar.bat` corre los pasos 2 a 5. Una tarea del Programador de tareas de Windows (**"Last.fm escuchas"**) lo ejecuta el **día 1 de cada mes a las 10:00**, o en cuanto se prenda el computador si ese día estaba apagado. El resultado de cada ejecución queda en `data/actualizacion.log`.

## Pendiente

- Consolidar con el historial ampliado de Spotify para rellenar meses sin registro en Last.fm (agosto y septiembre de 2026).
