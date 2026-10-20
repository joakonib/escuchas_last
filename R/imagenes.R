# Fotos de artistas y portadas de discos desde la API pública de Deezer.
# Se guardan en data/imagenes/ y solo se descargan una vez. Si Deezer no tiene
# una coincidencia exacta, se deja un archivo .none para no volver a buscarla.

library(httr2)

dir_imagenes <- "data/imagenes"

# Nombre de archivo seguro a partir de un texto
slug <- function(x) {
  s <- iconv(x, to = "ASCII//TRANSLIT")
  s[is.na(s)] <- x[is.na(s)]
  substr(tolower(gsub("[^A-Za-z0-9]+", "_", s)), 1, 80)
}

normalizar <- function(x) tolower(trimws(gsub("[^[:alnum:] ]", "", iconv(x, to = "ASCII//TRANSLIT"))))

buscar_deezer <- function(tipo, q) {
  resp <- tryCatch(
    request(paste0("https://api.deezer.com/search/", tipo)) |>
      req_url_query(q = q, limit = 5) |>
      req_throttle(rate = 8) |>
      req_retry(max_tries = 3) |>
      req_perform() |>
      resp_body_json(),
    error = \(e) NULL
  )
  resp$data
}

descargar <- function(url, archivo) {
  ok <- tryCatch({
    download.file(url, archivo, mode = "wb", quiet = TRUE)
    TRUE
  }, error = \(e) FALSE, warning = \(w) FALSE)
  if (ok) archivo else NA_character_
}

# Ruta local de la imagen (o NA si no hay), buscando en Deezer si hace falta
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
  # Solo se acepta una coincidencia exacta del nombre, para no mostrar la foto de otro
  elegido <- Find(\(r) {
    if (tipo == "artist") normalizar(r$name) == normalizar(artista)
    else normalizar(r$artist$name) == normalizar(artista)
  }, resultados)
  url <- if (tipo == "artist") elegido$picture_medium else elegido$cover_medium
  # Deezer usa una imagen genérica cuando el artista no tiene foto
  if (is.null(url) || grepl("/artist//", url, fixed = TRUE)) {
    file.create(paste0(base, ".none"))
    return(NA_character_)
  }
  descargar(url, paste0(base, ".jpg"))
}

imagen_artista <- function(artistas) vapply(artistas, \(a) imagen("artist", a), "", USE.NAMES = FALSE)
imagen_disco <- function(artistas, albumes) {
  mapply(\(a, b) imagen("album", a, b), artistas, albumes, USE.NAMES = FALSE)
}

# Grilla de tarjetas con imagen, título y detalle. Sin imagen, muestra las iniciales.
galeria <- function(imagenes, titulos, detalles) {
  tarjetas <- Map(\(img, titulo, detalle) {
    visual <- if (is.na(img)) {
      iniciales <- paste(substr(strsplit(titulo, " ")[[1]], 1, 1)[1:min(2, lengths(strsplit(titulo, " ")))], collapse = "")
      htmltools::div(class = "galeria-vacia", toupper(iniciales))
    } else {
      htmltools::img(src = img, alt = titulo, loading = "lazy")
    }
    htmltools::div(class = "galeria-item", visual,
                   htmltools::div(class = "galeria-titulo", titulo),
                   htmltools::div(class = "galeria-detalle", detalle))
  }, imagenes, titulos, detalles)
  htmltools::div(class = "galeria", tarjetas)
}
