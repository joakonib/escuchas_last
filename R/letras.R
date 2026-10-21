# Preparación de las letras (data/letras.parquet) para el análisis de texto:
# detección de idioma, limpieza y separación en palabras.

library(dplyr)
library(stringr)
library(stopwords)

# Palabras vacías en español e inglés, más muletillas típicas de canciones
palabras_vacias <- unique(c(
  stopwords("es", source = "snowball"), stopwords("en", source = "snowball"),
  stopwords("es", source = "stopwords-iso"), stopwords("en", source = "stopwords-iso"),
  "oh", "ooh", "ah", "yeah", "hey", "na", "la", "uh", "whoa", "eh", "ay", "yo", "da", "mmm",
  "gonna", "wanna", "gotta", "ya", "ey", "pa", "pal", "nah", "yeh", "huh", "ha", "hmm",
  "chorus", "verse", "coro", "x2", "x3", "x4", "don", "ll", "ve", "re", "ain", "cause"
))

# Idioma de una letra: compara cuántas palabras frecuentes de cada idioma contiene
detectar_idioma <- function(texto) {
  palabras <- str_split(str_to_lower(texto), "[^\\p{L}']+")
  es <- c("que", "de", "el", "la", "y", "en", "no", "me", "se", "los", "por", "un", "una", "mi", "con", "para")
  en <- c("the", "and", "you", "i", "to", "a", "of", "it", "me", "my", "in", "is", "that", "we", "your", "on")
  vapply(palabras, \(p) {
    n_es <- sum(p %in% es); n_en <- sum(p %in% en)
    if (n_es + n_en < 5) NA_character_ else if (n_es > n_en) "Español" else "Inglés"
  }, "")
}

# Una fila por palabra y canción, sin palabras vacías ni palabras de menos de 3 letras
tokenizar_letras <- function(letras) {
  letras |>
    filter(!is.na(letra)) |>
    mutate(cancion_id = paste(artista, cancion, sep = " — ")) |>
    select(cancion_id, artista, cancion, idioma, letra) |>
    mutate(palabra = str_split(str_to_lower(letra), "[^\\p{L}]+")) |>
    select(-letra) |>
    tidyr::unnest(palabra) |>
    filter(str_length(palabra) >= 3, !palabra %in% palabras_vacias)
}
