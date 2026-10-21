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

# Temas conocidos para nombrar y describir los tópicos de LDA. Cada tópico recibe
# el tema cuyas palabras clave coinciden más con sus 15 palabras principales
# (las primeras pesan más). Así la descripción sigue sirviendo si cambian los datos.
temas_conocidos <- tibble::tribble(
  ~tema_nombre, ~descripcion, ~claves,
  "Muerte y oscuridad", "Muerte, sangre, noche y oscuridad: el imaginario del metal y del post-punk más sombrío.",
  c("death", "die", "dead", "blood", "dark", "darkness", "night", "kill", "grave", "eyes", "light", "pain", "sangre", "muerte", "morir", "oscuridad"),
  "Amor y desamor", "Amor, deseo, besos y despedidas: canciones de pareja, de las que empiezan y de las que terminan.",
  c("love", "heart", "baby", "kiss", "tonight", "leave", "miss", "girl", "boy", "friends", "cold", "falling"),
  "Amor y deseo en español", "Querer, el corazón y las ganas, en español: el lado romántico de mis canciones en castellano.",
  c("amor", "quiero", "querer", "corazón", "besos", "quieres", "ganas", "beso", "gusta", "noche", "sol"),
  "El cuerpo y lo cotidiano", "Lo físico y lo de todos los días: manos, cuerpo, casa, mar y cielo.",
  c("manos", "cuerpo", "casa", "mar", "piel", "ojos", "calle", "vida", "vivir", "cielo"),
  "La vida y el paso del tiempo", "Reflexiones sobre la vida, los días que pasan y las ganas de cambiar.",
  c("life", "live", "time", "days", "change", "left", "mother", "day", "tiempo", "años"),
  "La cabeza: mente, sueño y ansiedad", "La mente, el insomnio, los sueños y las sensaciones: canciones hacia adentro.",
  c("mind", "sleep", "dream", "feel", "feeling", "head", "think", "care", "lost", "smile", "sueño", "cabeza"),
  "Fe y lo sagrado", "Dios, el cielo, el alma y la redención, a veces con fe y a veces con ironía.",
  c("god", "heaven", "pray", "soul", "hold", "hands", "dios", "alma", "jesus", "lord"),
  "Rabia y crítica social", "Enojo, violencia y crítica a la sociedad: el lado punk.",
  c("fuck", "shit", "war", "fight", "hate", "burn", "guerra", "fuego", "police", "rabia", "bad"),
  "Miedo y deseo, en chileno", "Lenguaje coloquial chileno mezclado con miedo, deseo y mirada: acá, dale, frente, ojos.",
  c("acá", "dale", "miedo", "frente", "mirar", "atrás", "veo", "quieres", "corazón")
)

describir_temas <- function(terminos) {
  # terminos: matriz de palabras (filas = rango, columnas = tópicos), como la de topicmodels::terms()
  puntajes <- sapply(seq_len(ncol(terminos)), \(j) {
    pesos <- rev(seq_len(nrow(terminos)))
    sapply(temas_conocidos$claves, \(cl) sum(pesos[terminos[, j] %in% cl]))
  })
  mejor <- apply(puntajes, 2, \(s) if (max(s) == 0) NA else which.max(s))
  nombre <- ifelse(is.na(mejor), "Tema mixto", temas_conocidos$tema_nombre[mejor])
  # Si dos tópicos reciben el mismo tema, se numeran
  nombre <- ave(nombre, nombre, FUN = \(x) if (length(x) > 1) paste0(x, " (", seq_along(x), ")") else x)
  tibble::tibble(
    tema = seq_len(ncol(terminos)),
    tema_nombre = nombre,
    descripcion = ifelse(is.na(mejor), "Mezcla de palabras sin un tema claro.", temas_conocidos$descripcion[mejor])
  )
}
