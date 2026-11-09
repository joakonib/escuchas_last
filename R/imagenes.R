# 0. Cargo paquetes ------
pacman::p_load(httr2)

# 1. Carpeta de imágenes ------
dir_imagenes <- "data/imagenes"

# 2. Funciones auxiliares ------
slug <- function(x) {
  s <- iconv(x, to = "ASCII//TRANSLIT")
  s[is.na(s)] <- x[is.na(s)]
  substr(tolower(gsub("[^A-Za-z0-9]+", "_", s)), 1, 80)
}

normalizar <- function(x) tolower(trimws(gsub("[^[:alnum:] ]", "", iconv(x, to = "ASCII//TRANSLIT"))))

# 3. Búsqueda en Deezer ------
buscar_deezer <- function(tipo, q) {
  resp <- tryCatch(
    request(paste0("https://api.deezer.com/search/", tipo)) %>%
      req_url_query(q = q, limit = 5) %>%
      req_throttle(rate = 8) %>%
      req_retry(max_tries = 3) %>%
      req_perform() %>%
      resp_body_json()
    ,error = function(e) NULL
  )
  resp$data
}

descargar <- function(url, archivo) {
  ok <- tryCatch({
    download.file(url, archivo, mode = "wb", quiet = TRUE)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (ok) archivo else NA_character_
}

#### solo acepta coincidencia exacta; un .none evita repetir la búsqueda
imagen <- function(tipo, artista, album = NULL) {
  carpeta <- file.path(dir_imagenes, if (tipo == "artist") "artistas" else "discos")
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  base <- file.path(carpeta, slug(paste(c(artista, album), collapse = " - ")))
  if (file.exists(paste0(base, ".jpg"))) return(paste0(base, ".jpg"))
  if (file.exists(paste0(base, ".none"))) return(NA_character_)

  resultados <- if (tipo == "artist") {
    buscar_deezer("artist", artista)
  } else {
    buscar_deezer("album", sprintf('artist:"%s" album:"%s"', artista, album))
  }
  exactos <- Filter(function(r) {
    if (tipo == "artist") normalizar(r$name) == normalizar(artista)
    else normalizar(r$artist$name) == normalizar(artista)
  }, resultados)
  if (tipo == "artist" && length(exactos) > 1) {
    exactos <- exactos[order(-vapply(exactos, function(r) as.numeric(r$nb_fan %||% 0), 0))]
  }
  elegido <- if (length(exactos) > 0) exactos[[1]] else NULL
  url <- if (tipo == "artist") elegido$picture_medium else elegido$cover_medium
  if (is.null(url) || grepl("/artist//", url, fixed = TRUE)) {
    file.create(paste0(base, ".none"))
    return(NA_character_)
  }
  descargar(url, paste0(base, ".jpg"))
}

## 3.1 Vectorización ------
imagen_artista <- function(artistas) vapply(artistas, function(a) imagen("artist", a), "", USE.NAMES = FALSE)
imagen_disco <- function(artistas, albumes) {
  mapply(function(a, b) imagen("album", a, b), artistas, albumes, USE.NAMES = FALSE)
}

# 4. Galería de tarjetas ------
galeria <- function(imagenes, titulos, detalles) {
  tarjetas <- Map(function(img, titulo, detalle) {
    visual <- if (is.na(img)) {
      iniciales <- paste(substr(strsplit(titulo, " ")[[1]], 1, 1)[1:min(2, lengths(strsplit(titulo, " ")))], collapse = "")
      htmltools::div(class = "galeria-vacia", toupper(iniciales))
    } else {
      htmltools::img(src = img, alt = titulo, loading = "lazy")
    }
    htmltools::div(class = "galeria-item", visual
                   ,htmltools::div(class = "galeria-titulo", titulo)
                   ,htmltools::div(class = "galeria-detalle", detalle))
  }, imagenes, titulos, detalles)
  htmltools::div(class = "galeria", tarjetas)
}
