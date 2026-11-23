remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,httr2
  ,jsonlite
)
source("R/datos.R")

# 1. Canciones con identificador de Spotify ------
#### Spotify cerró sus características de audio en noviembre de 2024. ReccoBeats las
#### entrega a partir del identificador de Spotify de cada canción, y el único lugar
#### donde la exportación de la cuenta trae esos identificadores son las playlists
#### (Playlist1.json). Es incremental: solo consulta lo que no está en data/audio.parquet.
zip_spotify <- Sys.getenv("SPOTIFY_ZIP", "data/my_spotify_data.zip")
archivo <- "data/audio.parquet"
if (!file.exists(zip_spotify)) {
  message("No está ", zip_spotify, ": no hay identificadores de Spotify para el audio")
  quit(status = 0)
}

listas <- unzip(zip_spotify, list = TRUE)$Name %>% str_subset("Playlist\\d*\\.json$")
canciones <- map(listas, function(f) {
  con <- unz(zip_spotify, f); on.exit(close(con))
  fromJSON(paste(readLines(con, encoding = "UTF-8", warn = FALSE), collapse = "\n"), simplifyVector = FALSE)$playlists
}) %>%
  purrr::list_flatten() %>%
  map(function(p) map(p$items, "track")) %>%
  purrr::list_flatten() %>%
  compact() %>%
  keep(function(t) !is.null(t$trackUri) && str_starts(t$trackUri, "spotify:track:")) %>%
  map_dfr(function(t) tibble(artista = t$artistName, cancion = t$trackName
                             ,id = str_remove(t$trackUri, "spotify:track:"))) %>%
  distinct(id, .keep_all = TRUE)

previo <- if (file.exists(archivo)) leer_parquet(archivo) else NULL
pendientes <- if (is.null(previo)) canciones else anti_join(canciones, previo, by = "id")
message("Canciones con identificador: ", nrow(canciones), " | por consultar: ", nrow(pendientes))
#### sin pendientes no hay nada que consultar (la tabla vacía no trae la columna id y el cruce fallaba)
if (nrow(pendientes) == 0) {
  message("Audio al día: no hay canciones nuevas por consultar")
  quit(status = 0)
}

# 2. Consulta a ReccoBeats en lotes de 40 ------
consultar <- function(ids) {
  r <- request("https://api.reccobeats.com/v1/audio-features") %>%
    req_url_query(ids = paste(ids, collapse = ",")) %>%
    req_user_agent("escuchas_last (https://github.com/joakonib/escuchas_last)") %>%
    req_throttle(rate = 1) %>%
    req_timeout(30) %>%
    req_retry(max_tries = 4, backoff = function(i) 2^i) %>%
    req_perform() %>%
    resp_body_json()
  map_dfr(r$content, function(x) tibble(
    id = str_extract(x$href, "[A-Za-z0-9]+$")
    ,energia = x$energy, valencia = x$valence, bailable = x$danceability
    ,acustica = x$acousticness, tempo = x$tempo, volumen = x$loudness
  ))
}

nuevo <- split(pendientes$id, ceiling(seq_along(pendientes$id) / 40)) %>%
  map_dfr(consultar)

#### las que ReccoBeats no conoce quedan con NA para no volver a consultarlas
audio <- pendientes %>%
  left_join(nuevo, by = "id") %>%
  bind_rows(previo) %>%
  distinct(id, .keep_all = TRUE)

guardar_parquet(audio, archivo)
message("Audio listo: ", sum(!is.na(audio$energia)), " de ", nrow(audio), " canciones con características")
