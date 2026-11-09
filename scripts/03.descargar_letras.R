remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,httr2
)
source("R/datos.R")

# 1. Configuración ------
#### MIN_ESCUCHAS define qué canciones se buscan
n_canciones <- as.integer(Sys.getenv("N_CANCIONES", "20000"))  # tope; se puede bajar para cortar antes
min_escuchas <- as.integer(Sys.getenv("MIN_ESCUCHAS", "3"))    # solo canciones escuchadas al menos estas veces
archivo <- "data/letras.parquet"

top <- leer_parquet("data/escuchas.parquet") %>%
  count(artista, cancion, sort = TRUE) %>%
  filter(n >= min_escuchas) %>%
  slice_head(n = n_canciones)

previas <- if (file.exists(archivo)) {
  leer_parquet(archivo)
} else {
  tibble(artista = character(), cancion = character(), letra = character()
         ,instrumental = logical(), fuente = character())
}
pendientes <- anti_join(top, previas, by = c("artista", "cancion"))
message("Canciones por buscar: ", nrow(pendientes))

# 2. Funciones de búsqueda ------
#### el tope de 30 s evita que una conexión abierta congele la descarga
consulta <- function(ruta, ...) {
  tryCatch(
    request(paste0("https://lrclib.net/api/", ruta)) %>%
      req_url_query(...) %>%
      req_user_agent("escuchas_last (https://github.com/joakonib/escuchas_last)") %>%
      req_throttle(rate = 2) %>%
      req_timeout(30) %>%
      req_retry(max_tries = 6, is_transient = function(r) resp_status(r) %in% c(429, 503)
                ,retry_on_failure = TRUE, backoff = function(i) 2^i) %>%
      req_error(is_error = function(r) FALSE) %>%
      req_perform() %>%
      resp_body_json()
    ,error = function(e) list(fallo_red = TRUE)
  )
}

## 2.1 Comparación de textos ------
parecido <- function(a, b) {
  normalizar <- function(x) str_squish(str_replace_all(str_to_lower(iconv(x, "UTF-8", "ASCII//TRANSLIT")), "[^a-z0-9 ]", " "))
  a <- normalizar(a); b <- normalizar(b)
  1 - as.numeric(adist(a, b)) / max(nchar(a), nchar(b), 1)
}

## 2.2 Mejor resultado de la búsqueda ------
mejor_resultado <- function(resultados, artista, cancion, umbral = 0.8) {
  if (length(resultados) == 0 || !is.list(resultados[[1]])) return(NULL)
  con_letra <- keep(resultados, function(r) !is.null(r$plainLyrics) && nzchar(r$plainLyrics))
  if (length(con_letra) == 0) return(NULL)
  puntaje <- map_dbl(con_letra, function(r) min(parecido(r$artistName, artista), parecido(r$trackName, cancion)))
  if (max(puntaje) >= umbral) con_letra[[which.max(puntaje)]] else NULL
}

## 2.3 Búsqueda de una canción ------
#### un fallo de red no se registra: se reintenta en la próxima corrida
buscar_letra <- function(artista, cancion) {
  r <- consulta("get", artist_name = artista, track_name = cancion)
  fuente <- "get"
  if (is.null(r$plainLyrics) && !isTRUE(r$instrumental) && !isTRUE(r$fallo_red)) {
    resultados <- consulta("search", track_name = cancion, artist_name = artista)
    if (isTRUE(resultados$fallo_red)) r <- resultados
    else r <- mejor_resultado(resultados, artista, cancion) %||% r
    fuente <- "search"
  }
  if (isTRUE(r$fallo_red)) return(NULL)
  tibble(
    artista = artista, cancion = cancion
    ,letra = r$plainLyrics %||% NA_character_
    ,instrumental = isTRUE(r$instrumental)
    ,fuente = if (is.null(r$plainLyrics)) NA_character_ else fuente
  )
}

# 3. Primera pasada ------
lotes <- split(pendientes, ceiling(seq_len(nrow(pendientes)) / 100))
previas <- reduce(seq_along(lotes), function(acumulado, i) {
  nuevas <- pmap(select(lotes[[i]], artista, cancion), buscar_letra) %>% list_rbind()
  acumulado <- bind_rows(acumulado, nuevas)
  guardar_parquet(acumulado, archivo)
  message("Lote ", i, "/", length(lotes), ": ", sum(!is.na(acumulado$letra)), " letras encontradas en total")
  acumulado
}, .init = previas)

# 4. Segunda pasada con título y artista limpios ------
limpiar_titulo <- function(x) {
  x %>%
    str_remove_all("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]") %>%
    str_remove(regex("\\s+-\\s+.*(remaster|live|version|versión|mix|edit|mono|stereo|demo|acoustic|bonus|deluxe|en vivo|single).*$", ignore_case = TRUE)) %>%
    str_remove(regex("\\s+(feat\\.?|ft\\.?|featuring)\\s.*$", ignore_case = TRUE)) %>%
    str_squish()
}
limpiar_artista <- function(x) {
  x %>%
    str_remove(regex("\\s*(\\bfeat\\.?|\\bft\\.?|\\bfeaturing|&|,|\\sx\\s).*$", ignore_case = TRUE)) %>%
    str_squish()
}

por_limpiar <- previas %>%
  filter(is.na(letra), !instrumental, is.na(fuente)) %>%
  mutate(cancion_limpia = limpiar_titulo(cancion), artista_limpio = limpiar_artista(artista)) %>%
  filter(cancion_limpia != "", artista_limpio != ""
         ,cancion_limpia != cancion | artista_limpio != artista)
message("Segunda pasada (título y artista limpios): ", nrow(por_limpiar), " canciones")

if (nrow(por_limpiar) > 0) {
  lotes <- split(por_limpiar, ceiling(seq_len(nrow(por_limpiar)) / 100))
  previas <- reduce(seq_along(lotes), function(acumulado, i) {
    l <- lotes[[i]]
    #### un fallo de red devuelve NULL: esa canción queda para la próxima corrida
    nuevas <- map(seq_len(nrow(l)), function(n) {
      r <- buscar_letra(l$artista_limpio[n], l$cancion_limpia[n])
      if (is.null(r)) return(NULL)
      mutate(r, artista = l$artista[n], cancion = l$cancion[n]
             ,fuente = if_else(is.na(letra), "limpio_sin_letra", "limpio"))
    }) %>%
      list_rbind()
    if (nrow(nuevas) > 0) acumulado <- rows_update(acumulado, nuevas, by = c("artista", "cancion"))
    guardar_parquet(acumulado, archivo)
    message("Segunda pasada, lote ", i, "/", length(lotes), ": "
            ,sum(!is.na(acumulado$letra)), " letras encontradas en total")
    acumulado
  }, .init = previas)
}
message("Listo: ", sum(!is.na(previas$letra)), " de ", nrow(previas), " canciones con letra")
