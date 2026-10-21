# Descarga las letras de las canciones más escuchadas desde LRCLIB
# (https://lrclib.net, base abierta y sin clave) a data/letras.parquet.
#
# Es incremental: solo busca canciones que aún no están en el archivo, y guarda
# cada 100 canciones para no perder avances. Las canciones sin letra quedan con
# letra NA para no volver a buscarlas. Las letras son solo para análisis local:
# data/ no se sube a GitHub y el reporte muestra solo palabras y tópicos agregados.

library(httr2)
library(dplyr)
library(purrr)
library(arrow)

n_canciones <- 8000
archivo <- "data/letras.parquet"

leer_parquet <- function(f) read_parquet(readBin(f, "raw", file.size(f)))

top <- leer_parquet("data/escuchas.parquet") |>
  count(artista, cancion, sort = TRUE) |>
  slice_head(n = n_canciones)

previas <- if (file.exists(archivo)) {
  leer_parquet(archivo)
} else {
  tibble(artista = character(), cancion = character(), letra = character(),
         instrumental = logical(), fuente = character())
}
pendientes <- anti_join(top, previas, by = c("artista", "cancion"))
message("Canciones por buscar: ", nrow(pendientes))

consulta <- function(ruta, ...) {
  tryCatch(
    request(paste0("https://lrclib.net/api/", ruta)) |>
      req_url_query(...) |>
      req_user_agent("escuchas_last (https://github.com/joakonib/escuchas_last)") |>
      req_throttle(rate = 2) |>
      req_retry(max_tries = 6, is_transient = \(r) resp_status(r) %in% c(429, 503),
                backoff = \(i) 2^i) |>
      req_error(is_error = \(r) FALSE) |>
      req_perform() |>
      resp_body_json(),
    error = \(e) NULL
  )
}

buscar_letra <- function(artista, cancion) {
  r <- consulta("get", artist_name = artista, track_name = cancion)
  fuente <- "get"
  # Si no hay coincidencia exacta, se intenta con la búsqueda general
  if (is.null(r$plainLyrics) && !isTRUE(r$instrumental)) {
    resultados <- consulta("search", track_name = cancion, artist_name = artista)
    r <- if (length(resultados) > 0 && !is.null(resultados[[1]]$plainLyrics)) resultados[[1]] else r
    fuente <- "search"
  }
  tibble(
    artista = artista, cancion = cancion,
    letra = r$plainLyrics %||% NA_character_,
    instrumental = isTRUE(r$instrumental),
    fuente = if (is.null(r$plainLyrics)) NA_character_ else fuente
  )
}

lotes <- split(pendientes, ceiling(seq_len(nrow(pendientes)) / 100))
for (i in seq_along(lotes)) {
  nuevas <- pmap(select(lotes[[i]], artista, cancion), buscar_letra) |> list_rbind()
  previas <- bind_rows(previas, nuevas)
  write_parquet(previas, archivo)
  message("Lote ", i, "/", length(lotes), ": ", sum(!is.na(previas$letra)), " letras encontradas en total")
}
message("Listo: ", sum(!is.na(previas$letra)), " de ", nrow(previas), " canciones con letra")
