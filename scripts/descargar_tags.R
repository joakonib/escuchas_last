# Descarga los tags (géneros) y oyentes de Last.fm de los artistas más escuchados a
# data/tags_artistas.parquet y data/info_artistas.parquet. Requiere haber corrido antes descargar_escuchas.R.
#
# Es incremental: solo consulta artistas que aún no están en el archivo.

library(httr2)
library(dplyr)
library(purrr)
library(arrow)

# Lee el parquet completo a memoria: así Windows no deja el archivo bloqueado
# y se puede sobrescribir al final
leer_parquet <- function(f) read_parquet(readBin(f, "raw", file.size(f)))

api_key <- Sys.getenv("LASTFM_API_KEY")
if (api_key == "") stop("Falta LASTFM_API_KEY en .Renviron")

n_artistas <- as.integer(Sys.getenv("N_ARTISTAS", "5000"))  # tope; 5000 cubre a todos los artistas (3.271 al 23-10-2026)
archivo <- "data/tags_artistas.parquet"

top <- leer_parquet("data/escuchas.parquet") |>
  count(artista, sort = TRUE) |>
  slice_head(n = n_artistas)

previos <- if (file.exists(archivo)) {
  leer_parquet(archivo)
} else {
  tibble(artista = character(), tag = character(), peso = numeric())
}
pendientes <- setdiff(top$artista, previos$artista)
message("Artistas por consultar: ", length(pendientes))

pedir_tags <- function(artista) {
  resp <- request("https://ws.audioscrobbler.com/2.0/") |>
    req_url_query(
      method = "artist.gettoptags",
      artist = artista,
      api_key = api_key,
      format = "json",
      autocorrect = 1
    ) |>
    req_retry(max_tries = 5) |>
    req_throttle(rate = 4) |>
    req_error(is_error = \(r) FALSE) |>
    req_perform() |>
    resp_body_json()
  tags <- resp$toptags$tag
  # Artistas sin tags quedan registrados con tag NA para no volver a consultarlos
  if (length(tags) == 0) return(tibble(artista = artista, tag = NA_character_, peso = NA_real_))
  map(tags[seq_len(min(30, length(tags)))], \(t) tibble(
    artista = artista,
    tag     = tolower(t$name),
    peso    = as.numeric(t$count)
  )) |>
    list_rbind()
}

nuevos <- imap(pendientes, \(a, i) {
  if (i %% 50 == 0) message("Artista ", i, "/", length(pendientes))
  pedir_tags(a)
}) |>
  list_rbind()

bind_rows(previos, nuevos) |> write_parquet(archivo)
message("Listo: ", n_distinct(bind_rows(previos, nuevos)$artista), " artistas con tags")

# Oyentes y reproducciones globales de cada artista, para medir qué tan de
# nicho es lo que escucho
archivo_info <- "data/info_artistas.parquet"
previos_info <- if (file.exists(archivo_info)) {
  leer_parquet(archivo_info)
} else {
  tibble(artista = character(), oyentes = numeric(), reproducciones = numeric())
}
pendientes_info <- setdiff(top$artista, previos_info$artista)
message("Artistas por consultar (oyentes): ", length(pendientes_info))

pedir_info <- function(artista) {
  resp <- request("https://ws.audioscrobbler.com/2.0/") |>
    req_url_query(
      method = "artist.getinfo",
      artist = artista,
      api_key = api_key,
      format = "json",
      autocorrect = 1
    ) |>
    req_retry(max_tries = 5) |>
    req_throttle(rate = 4) |>
    req_error(is_error = \(r) FALSE) |>
    req_perform() |>
    resp_body_json()
  tibble(
    artista        = artista,
    oyentes        = as.numeric(resp$artist$stats$listeners %||% NA),
    reproducciones = as.numeric(resp$artist$stats$playcount %||% NA)
  )
}

nuevos_info <- imap(pendientes_info, \(a, i) {
  if (i %% 50 == 0) message("Artista ", i, "/", length(pendientes_info))
  pedir_info(a)
}) |>
  list_rbind()

bind_rows(previos_info, nuevos_info) |> write_parquet(archivo_info)
message("Listo: oyentes de ", nrow(bind_rows(previos_info, nuevos_info)), " artistas")
