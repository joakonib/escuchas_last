# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,stopwords
)

# 1. Palabras vacías ------
palabras_vacias <- unique(c(
  stopwords("es", source = "snowball"), stopwords("en", source = "snowball")
  ,stopwords("es", source = "stopwords-iso"), stopwords("en", source = "stopwords-iso")
  ,"oh", "ooh", "ah", "yeah", "hey", "na", "la", "uh", "whoa", "eh", "ay", "yo", "da", "mmm"
  ,"gonna", "wanna", "gotta", "ya", "ey", "pa", "pal", "nah", "yeh", "huh", "ha", "hmm"
  ,"chorus", "verse", "coro", "x2", "x3", "x4", "don", "ll", "ve", "re", "ain", "cause"
))

# 2. Idioma y palabras ------
## 2.1 Idioma de cada letra ------
detectar_idioma <- function(texto) {
  palabras <- str_split(str_to_lower(texto), "[^\\p{L}']+")
  es <- c("que", "de", "el", "la", "y", "en", "no", "me", "se", "los", "por", "un", "una", "mi", "con", "para")
  en <- c("the", "and", "you", "i", "to", "a", "of", "it", "me", "my", "in", "is", "that", "we", "your", "on")
  vapply(palabras, function(p) {
    n_es <- sum(p %in% es); n_en <- sum(p %in% en)
    if (n_es + n_en < 5) NA_character_ else if (n_es > n_en) "Español" else "Inglés"
  }, "")
}

## 2.2 Una fila por palabra y canción ------
tokenizar_letras <- function(letras) {
  letras %>%
    filter(!is.na(letra)) %>%
    mutate(cancion_id = paste(artista, cancion, sep = " — ")) %>%
    select(cancion_id, artista, cancion, idioma, letra) %>%
    mutate(palabra = str_split(str_to_lower(letra), "[^\\p{L}]+")) %>%
    select(-letra) %>%
    tidyr::unnest(palabra) %>%
    filter(str_length(palabra) >= 3, !palabra %in% palabras_vacias)
}

# 3. Sentimiento con léxico NRC ------
#### se estandariza por idioma: el léxico en español es una traducción
#### en este léxico value siempre es 1, el signo lo da sentiment
sentimiento_letras <- function(tokens, min_palabras = 15) {
  lexico <- function(lengua, idioma) {
    syuzhet::get_sentiment_dictionary("nrc", language = lengua) %>%
      filter(sentiment %in% c("positive", "negative")) %>%
      group_by(palabra = word) %>%
      summarise(valor = mean(ifelse(sentiment == "negative", -1, 1)), .groups = "drop") %>%
      filter(valor != 0) %>%
      mutate(idioma = idioma)
  }
  tokens %>%
    filter(!is.na(idioma)) %>%
    inner_join(bind_rows(lexico("english", "Inglés"), lexico("spanish", "Español"))
               ,by = c("palabra", "idioma")) %>%
    group_by(artista, cancion, idioma) %>%
    summarise(sent_letra = mean(valor), palabras_lexico = n(), .groups = "drop") %>%
    filter(palabras_lexico >= min_palabras) %>%
    group_by(idioma) %>%
    mutate(z_letra = as.numeric(scale(sent_letra))) %>%
    ungroup()
}

# 4. Nombres de los temas ------
## 4.1 Diccionario de temas ------
temas_conocidos <- tibble::tribble(
  ~tema_nombre, ~descripcion, ~claves
  ,"El amor y la vida, en rock chileno y argentino", "Amor, vida, mundo y corazón, con el voseo rioplatense: el lado romántico del rock en castellano."
  ,c("amor", "vida", "vos", "mundo", "corazón", "sol", "querer", "tiempo", "cielo", "sueño", "vas", "sos")
  ,"Deseo y noche, urbano y tropical", "Ganas, noche, fiesta y coqueteo: el lenguaje del trap, el reggaetón y la cumbia."
  ,c("noche", "gusta", "mami", "quieres", "casa", "dame", "bailar", "fiesta", "ganas", "beso", "besos", "perreo", "acá", "dale")
  ,"Luz y oscuridad", "Día y noche, luz y sombra, cielo y sol: un imaginario contemplativo y melancólico."
  ,c("day", "night", "light", "black", "sun", "sky", "dark", "darkness", "mind", "hear", "moon", "cold", "rain")
  ,"Muerte, sangre y lo sagrado", "Sangre, muerte, almas y dioses: el imaginario del metal extremo."
  ,c("blood", "god", "death", "soul", "kill", "dead", "burn", "burning", "die", "grave", "hell", "pain", "sangre", "muerte")
  ,"Amor y despedidas", "Amar, sentir, quedarse o irse: canciones de pareja, de las que empiezan y de las que terminan."
  ,c("love", "heart", "feel", "leave", "stay", "hold", "miss", "kiss", "time", "people", "falling", "friends")
  ,"Noches, peleas y quiebres", "Una noche, una chica, un corte, una pelea: la tensión y el quiebre del post-punk."
  ,c("baby", "tonight", "girl", "cut", "break", "fight", "sleep", "stand", "run", "broken")
  ,"Días, noches y recuerdos", "Días y noches que pasan, recuerdos, salir a bailar y andar: la vida que se mueve."
  ,c("day", "night", "days", "remember", "dance", "ride", "living", "tonight", "girl", "summer")
  ,"Luz, cielo y lo sagrado", "Luz, sol, cielo, ojos y manos, y a veces Dios: un imaginario luminoso y espiritual."
  ,c("light", "god", "sun", "sky", "eyes", "hands", "hand", "hold", "heaven", "pray")
  ,"Abrazos, frío y espera", "Esperar, quedarse, abrazar y el frío de afuera: canciones íntimas de cercanía y distancia."
  ,c("baby", "cold", "hold", "stay", "waiting", "wait", "water", "hand", "warm", "arms", "home", "rain")
  ,"Pérdida, miedo y oscuridad", "Lo perdido, el miedo, la oscuridad y el cuerpo: el lado más sombrío e inquieto."
  ,c("lost", "fear", "dark", "darkness", "left", "kill", "body", "hear", "alone", "afraid")
  ,"La vida y el paso del tiempo", "Reflexiones sobre la vida, la pérdida, los días que pasan y las ganas de cambiar."
  ,c("life", "live", "living", "lost", "left", "eyes", "days", "change", "mother", "hand", "tiempo", "años")
  ,"Rabia, calle y dinero", "Enojo, violencia, plata y calle: el lado del hardcore y el hip-hop."
  ,c("fuck", "shit", "money", "bring", "bad", "nigga", "boy", "war", "hate", "police", "guerra", "rabia")
  ,"La cabeza: mente, sueño y ansiedad", "La mente, el insomnio, los sueños y las sensaciones: canciones hacia adentro."
  ,c("mind", "sleep", "dream", "feeling", "head", "think", "care", "smile", "sueño", "cabeza")
  ,"Fe y lo sagrado", "Dios, el cielo, el alma y la redención, a veces con fe y a veces con ironía."
  ,c("god", "heaven", "pray", "soul", "hands", "dios", "alma", "jesus", "lord")
  ,"El cuerpo y lo cotidiano", "Lo físico y lo de todos los días: manos, cuerpo, casa, mar y cielo."
  ,c("manos", "cuerpo", "casa", "mar", "piel", "ojos", "calle", "vivir", "cielo")
  ,"Miedo y deseo, en chileno", "Lenguaje coloquial chileno mezclado con miedo, deseo y mirada: acá, dale, frente, ojos."
  ,c("acá", "dale", "miedo", "frente", "mirar", "atrás", "veo", "corazón")
)

## 4.2 Asignación de nombres ------
#### cada tema se usa una sola vez
describir_temas <- function(terminos) {
  pesos <- rev(seq_len(nrow(terminos)))
  puntajes <- sapply(seq_len(ncol(terminos)), function(j)
    sapply(temas_conocidos$claves, function(cl) sum(pesos[terminos[, j] %in% cl])))
  mejor <- rep(NA_integer_, ncol(terminos))
  p <- puntajes
  while (any(is.na(mejor)) && max(p) > 0) {
    ij <- which(p == max(p), arr.ind = TRUE)[1, ]
    mejor[ij[2]] <- ij[1]
    p[ij[1], ] <- 0; p[, ij[2]] <- 0
  }
  principales <- apply(terminos[1:3, , drop = FALSE], 2, paste, collapse = ", ")
  tibble::tibble(
    tema = seq_len(ncol(terminos))
    ,tema_nombre = ifelse(is.na(mejor), paste0("Tema mixto: ", principales), temas_conocidos$tema_nombre[mejor])
    ,descripcion = ifelse(is.na(mejor), "Mezcla de palabras sin un tema claro.", temas_conocidos$descripcion[mejor])
  )
}
