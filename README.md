# escuchas_last

Descarga y analiza mi historial de escuchas de Last.fm.

## Uso

1. Crear `.Renviron` en la raíz:
   ```
   LASTFM_API_KEY=...
   LASTFM_USER=...
   ```
   (API key en https://www.last.fm/api/account/create)
2. Ejecutar `Rscript descargar_escuchas.R` → genera `data/escuchas.parquet` (incremental).
3. `Rscript descargar_tags.R` → géneros (tags) y oyentes de los 500 artistas principales.
4. `quarto render analisis_escuchas.qmd` → reporte general.
5. `Rscript generar_reporte_mensual.R [AAAA-MM]` → `reportes/reporte_AAAA-MM.html` (por defecto, el mes anterior).

## Actualización automática

`actualizar.bat` corre los pasos 1 a 5. Una tarea del Programador de tareas de Windows ("Last.fm escuchas") lo ejecuta el día 1 de cada mes a las 10:00, o en cuanto se prenda el computador si ese día estaba apagado. El log queda en `data/actualizacion.log`.
