# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,arrow
)

# 1. Lectura y escritura ------
#### readBin evita que Windows deje bloqueado el archivo
leer_parquet <- function(f) read_parquet(readBin(f, "raw", file.size(f)))

#### escribe a un temporal: un corte no daña el archivo anterior
guardar_parquet <- function(x, f) {
  temporal <- paste0(f, ".tmp")
  write_parquet(x, temporal)
  if (!file.rename(temporal, f)) stop("No se pudo reemplazar ", f)
  invisible(f)
}

# 2. Escuchas ------
#### la base consolidada (Last.fm + Spotify) si existe; si no, solo Last.fm
archivo_escuchas <- function() {
  consolidada <- "data/escuchas_consolidadas.parquet"
  if (file.exists(consolidada)) consolidada else "data/escuchas.parquet"
}

#### excluye las escuchas sin fecha (01-01-1970)
#### minutos: duración real de la canción (Spotify) o, si no se conoce, la mediana
leer_escuchas <- function(zona = "America/Santiago") {
  duraciones <- if (file.exists("data/duraciones.parquet")) leer_parquet("data/duraciones.parquet") else
    tibble(artista = character(), cancion = character(), minutos = numeric())
  tipica <- if (nrow(duraciones)) median(duraciones$minutos) else 3.5
  leer_parquet(archivo_escuchas()) %>%
    filter(uts >= as.numeric(as.POSIXct("2002-01-01", tz = "UTC"))) %>%
    left_join(duraciones, by = c("artista", "cancion")) %>%
    mutate(fecha = with_tz(as_datetime(uts), zona), minutos = coalesce(minutos, tipica))
}

# 3. Spotify ------
#### lee los StreamingHistory_music directo del ZIP; endTime viene en UTC
#### Lee el historial básico (StreamingHistory_music_*.json) o, si el zip trae el historial
#### ampliado (Streaming_History_Audio_*.json, que se pide aparte a Spotify), ese, que suma
#### el identificador de la canción, si se saltó y si estaba en aleatorio.
leer_spotify <- function(zip = "data/my_spotify_data.zip", zona = "America/Santiago") {
  archivos <- unzip(zip, list = TRUE)$Name
  ampliado <- str_subset(archivos, "Streaming_History_Audio_.*[.]json$")
  if (length(ampliado) > 0) {
    return(
      ampliado %>%
        map_dfr(~ jsonlite::fromJSON(unz(zip, .x))) %>%
        as_tibble() %>%
        filter(!is.na(master_metadata_track_name)) %>%
        transmute(
          fecha = with_tz(ymd_hms(ts, tz = "UTC"), zona)
          ,artista = master_metadata_album_artist_name
          ,cancion = master_metadata_track_name
          ,ms = ms_played
          ,minutos = ms_played / 60000
          ,cuenta = ms_played >= 30000
          ,id = str_remove(spotify_track_uri, "spotify:track:")
          ,saltada = as.logical(skipped)
          ,aleatorio = as.logical(shuffle)
        )
    )
  }
  archivos %>%
    str_subset("StreamingHistory_music_[0-9]+[.]json$") %>%
    map_dfr(~ jsonlite::fromJSON(unz(zip, .x))) %>%
    as_tibble() %>%
    transmute(
      fecha = with_tz(ymd_hm(endTime, tz = "UTC"), zona)
      ,artista = artistName
      ,cancion = trackName
      ,ms = msPlayed
      ,minutos = msPlayed / 60000
      ,cuenta = msPlayed >= 30000
    )
}

# 4. Limpieza de nombres ------
#### saca paréntesis, "- Remaster", "feat." y similares del título
limpiar_titulo <- function(x) {
  x %>%
    str_remove_all("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]") %>%
    str_remove(regex("\\s+-\\s+.*(remaster|live|version|versión|mix|edit|mono|stereo|demo|acoustic|bonus|deluxe|en vivo|single).*$", ignore_case = TRUE)) %>%
    str_remove(regex("\\s+(feat\\.?|ft\\.?|featuring)\\s.*$", ignore_case = TRUE)) %>%
    str_squish()
}

#### deja solo al artista principal
limpiar_artista <- function(x) {
  x %>%
    str_remove(regex("\\s*(\\bfeat\\.?|\\bft\\.?|\\bfeaturing|&|,|\\sx\\s).*$", ignore_case = TRUE)) %>%
    str_squish()
}

#### llave para cruzar fuentes: minúsculas, sin tildes ni signos
normalizar <- function(x) {
  x %>%
    str_to_lower() %>%
    stringi::stri_trans_general("Latin-ASCII") %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_squish()
}
