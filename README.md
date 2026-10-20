# escuchas_last

Descarga y analiza mi historial de escuchas de Last.fm.

## Uso

1. Crear `.Renviron` en la raíz:
   ```
   LASTFM_API_KEY=...
   LASTFM_USER=...
   ```
   (API key en https://www.last.fm/api/account/create)
2. Ejecutar `Rscript descargar_escuchas.R` → genera `data/escuchas.csv` (incremental).
