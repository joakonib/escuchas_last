remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,httr2
)
source("R/datos.R")

# 1. Configuración ------
api_key <- Sys.getenv("LASTFM_API_KEY")
if (api_key == "") stop("Falta LASTFM_API_KEY en .Renviron")

n_artistas <- as.integer(Sys.getenv("N_ARTISTAS", "5000"))  # tope; 5000 cubre a todos los artistas (3.282 al 08-11-2026)

top <- leer_parquet("data/escuchas.parquet") %>%
  count(artista, sort = TRUE) %>%
  slice_head(n = n_artistas)

# 2. Funciones ------
## 2.1 Consulta a Last.fm ------
#### el código 6 (artista inexistente) es una respuesta válida
pedir_lastfm <- function(metodo, artista) {
  resp <- request("https://ws.audioscrobbler.com/2.0/") %>%
    req_url_query(method = metodo, artist = artista, api_key = api_key, format = "json", autocorrect = 1) %>%
    req_retry(max_tries = 5) %>%
    req_throttle(rate = 4) %>%
    req_timeout(30) %>%
    req_error(is_error = function(r) FALSE) %>%
    req_perform() %>%
    resp_body_json()
  if (!is.null(resp$error) && resp$error != 6) stop("Last.fm respondió error ", resp$error, ": ", resp$message)
  resp
}

## 2.2 Descarga por lotes ------
#### si una consulta falla, el artista se reintenta en la próxima corrida
descargar <- function(archivo, vacio, pedir, nombre) {
  previos <- if (file.exists(archivo)) leer_parquet(archivo) else vacio
  pendientes <- setdiff(top$artista, previos$artista)
  message(nombre, ": artistas por consultar: ", length(pendientes))
  lotes <- split(pendientes, ceiling(seq_along(pendientes) / 200))
  total <- reduce(seq_along(lotes), function(acumulado, i) {
    nuevos <- map(lotes[[i]], function(a) tryCatch(pedir(a), error = function(e) {
      message("Sin respuesta para ", a, ": ", conditionMessage(e))
      NULL
    })) %>%
      list_rbind()
    acumulado <- bind_rows(acumulado, nuevos)
    guardar_parquet(acumulado, archivo)
    message(nombre, ": lote ", i, "/", length(lotes))
    acumulado
  }, .init = previos)
  message("Listo: ", nombre, " de ", n_distinct(total$artista), " artistas")
}

## 2.3 Etiquetas ------
pedir_tags <- function(artista) {
  tags <- pedir_lastfm("artist.gettoptags", artista)$toptags$tag
  if (length(tags) == 0) return(tibble(artista = artista, tag = NA_character_, peso = NA_real_))
  map(tags[seq_len(min(30, length(tags)))], function(t) tibble(
    artista = artista
    ,tag     = tolower(t$name)
    ,peso    = as.numeric(t$count)
  )) %>%
    list_rbind()
}

## 2.4 Oyentes y reproducciones ------
pedir_info <- function(artista) {
  resp <- pedir_lastfm("artist.getinfo", artista)
  tibble(
    artista        = artista
    ,oyentes        = as.numeric(resp$artist$stats$listeners %||% NA)
    ,reproducciones = as.numeric(resp$artist$stats$playcount %||% NA)
  )
}

# 3. Descarga ------
descargar("data/tags_artistas.parquet"
          ,tibble(artista = character(), tag = character(), peso = numeric()), pedir_tags, "Etiquetas")
descargar("data/info_artistas.parquet"
          ,tibble(artista = character(), oyentes = numeric(), reproducciones = numeric()), pedir_info, "Oyentes")
