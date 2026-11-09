remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,httr2
)
source("R/datos.R")

# 1. Credenciales ------
#### LASTFM_API_KEY y LASTFM_USER van en .Renviron
api_key <- Sys.getenv("LASTFM_API_KEY")
usuario <- Sys.getenv("LASTFM_USER")
if (api_key == "" || usuario == "") {
  stop("Faltan LASTFM_API_KEY y/o LASTFM_USER en .Renviron")
}

# 2. Punto de partida ------
archivo <- "data/escuchas.parquet"
dir.create("data", showWarnings = FALSE)

previas <- if (file.exists(archivo)) leer_parquet(archivo) else NULL
desde <- if (is.null(previas) || nrow(previas) == 0) 0 else max(previas$uts) + 1

# 3. Funciones de descarga ------
pedir_pagina <- function(pagina) {
  request("https://ws.audioscrobbler.com/2.0/") %>%
    req_url_query(
      method = "user.getrecenttracks"
      ,user = usuario
      ,api_key = api_key
      ,format = "json"
      ,limit = 200
      ,page = pagina
      ,from = desde
    ) %>%
    req_retry(max_tries = 5) %>%
    req_throttle(rate = 4) %>%
    req_timeout(30) %>%
    req_perform() %>%
    resp_body_json()
}

procesar_pagina <- function(resp) {
  tracks <- resp$recenttracks$track
  tracks <- keep(tracks, function(t) !is.null(t$date))
  map(tracks, function(t) tibble(
    uts       = as.numeric(t$date$uts)
    ,fecha_utc = as.POSIXct(as.numeric(t$date$uts), origin = "1970-01-01", tz = "UTC")
    ,artista   = t$artist$`#text`,
    album     = t$album$`#text`,
    cancion   = t$name
    ,mbid_cancion = t$mbid
    ,mbid_artista = t$artist$mbid
    ,mbid_album   = t$album$mbid
  )) %>%
    list_rbind()
}

# 4. Descarga y guardado ------
primera <- pedir_pagina(1)
total_paginas <- as.integer(primera$recenttracks$`@attr`$totalPages)
message("Páginas por descargar: ", total_paginas)

if (total_paginas == 0) {
  message("No hay escuchas nuevas.")
} else {
  paginas <- c(
    list(primera)
    ,map(seq_len(total_paginas)[-1], function(p) {
      message("Página ", p, "/", total_paginas)
      pedir_pagina(p)
    })
  )
  nuevas <- map(paginas, procesar_pagina) %>% list_rbind()

  escuchas <- bind_rows(previas, nuevas) %>%
    distinct(uts, artista, cancion, .keep_all = TRUE) %>%
    arrange(uts)

  guardar_parquet(escuchas, archivo)
  message("Escuchas nuevas: ", nrow(nuevas), " | total: ", nrow(escuchas))
}
