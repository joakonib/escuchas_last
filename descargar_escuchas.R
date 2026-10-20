# Descarga el historial de escuchas (scrobbles) de Last.fm a data/escuchas.parquet
#
# Credenciales: crear un archivo .Renviron en la raíz del proyecto con
#   LASTFM_API_KEY=tu_api_key      (https://www.last.fm/api/account/create)
#   LASTFM_USER=tu_usuario
# y reiniciar R. .Renviron está en .gitignore.
#
# La descarga es incremental: si data/escuchas.parquet existe, solo trae las
# escuchas posteriores a la última registrada.

library(httr2)
library(dplyr)
library(purrr)
library(readr)
library(arrow)

api_key <- Sys.getenv("LASTFM_API_KEY")
usuario <- Sys.getenv("LASTFM_USER")
if (api_key == "" || usuario == "") {
  stop("Faltan LASTFM_API_KEY y/o LASTFM_USER en .Renviron")
}

archivo <- "data/escuchas.parquet"
csv_antiguo <- "data/escuchas.csv"
dir.create("data", showWarnings = FALSE)

# Punto de partida para la descarga incremental. Si solo existe el CSV de
# versiones anteriores, se usa como base y se reemplaza por el parquet.
previas <- if (file.exists(archivo)) {
  read_parquet(archivo)
} else if (file.exists(csv_antiguo)) {
  read_csv(csv_antiguo, col_types = cols(.default = "c", uts = "d")) |>
    mutate(fecha_utc = as.POSIXct(uts, origin = "1970-01-01", tz = "UTC"))
} else {
  NULL
}
desde <- if (is.null(previas) || nrow(previas) == 0) 0 else max(previas$uts) + 1

pedir_pagina <- function(pagina) {
  request("https://ws.audioscrobbler.com/2.0/") |>
    req_url_query(
      method = "user.getrecenttracks",
      user = usuario,
      api_key = api_key,
      format = "json",
      limit = 200,
      page = pagina,
      from = desde
    ) |>
    req_retry(max_tries = 5) |>
    req_throttle(rate = 4) |>
    req_perform() |>
    resp_body_json()
}

# Convierte una página de la API en un data.frame
procesar_pagina <- function(resp) {
  tracks <- resp$recenttracks$track
  # Se descarta la canción "sonando ahora", que no tiene fecha
  tracks <- keep(tracks, \(t) !is.null(t$date))
  map(tracks, \(t) tibble(
    uts       = as.numeric(t$date$uts),
    fecha_utc = as.POSIXct(as.numeric(t$date$uts), origin = "1970-01-01", tz = "UTC"),
    artista   = t$artist$`#text`,
    album     = t$album$`#text`,
    cancion   = t$name,
    mbid_cancion = t$mbid,
    mbid_artista = t$artist$mbid,
    mbid_album   = t$album$mbid
  )) |>
    list_rbind()
}

primera <- pedir_pagina(1)
total_paginas <- as.integer(primera$recenttracks$`@attr`$totalPages)
message("Páginas por descargar: ", total_paginas)

if (total_paginas == 0) {
  message("No hay escuchas nuevas.")
  if (!is.null(previas) && !file.exists(archivo)) write_parquet(previas, archivo)
} else {
  paginas <- c(
    list(primera),
    map(seq_len(total_paginas)[-1], \(p) {
      message("Página ", p, "/", total_paginas)
      pedir_pagina(p)
    })
  )
  nuevas <- map(paginas, procesar_pagina) |> list_rbind()

  escuchas <- bind_rows(previas, nuevas) |>
    distinct(uts, artista, cancion, .keep_all = TRUE) |>
    arrange(uts)

  write_parquet(escuchas, archivo)
  message("Escuchas nuevas: ", nrow(nuevas), " | total: ", nrow(escuchas))
}

if (file.exists(archivo) && file.exists(csv_antiguo)) file.remove(csv_antiguo)
