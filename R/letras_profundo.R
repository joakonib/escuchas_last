# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,syuzhet
)

# 1. Texto base ------
#### quita las marcas de sección de Genius y otras fuentes ([Chorus], [Verso 1], (x2))
limpiar_marcas <- function(x) {
  x %>%
    str_remove_all("\\[[^\\]]*\\]") %>%
    str_remove_all(regex("\\((x|×)\\s*\\d+\\)", ignore_case = TRUE))
}

#### palabras en minúsculas, conservando apóstrofos (i'm, don't) y tildes
palabras_crudas <- function(x) {
  map(str_split(str_to_lower(limpiar_marcas(x)), "[^\\p{L}']+"), function(p) p[p != "" & p != "'"])
}

# 2. Las ocho emociones del léxico NRC ------
#### NRC (Mohammad y Turney, 2013): cada palabra puede tener varias emociones de Plutchik.
#### La tasa es emociones por cada 100 palabras de la letra (sin palabras vacías), y se
#### estandariza dentro de cada idioma porque el léxico en español es una traducción.
emociones_es <- c(anger = "Rabia", anticipation = "Anticipación", disgust = "Asco", fear = "Miedo"
                  ,joy = "Alegría", sadness = "Tristeza", surprise = "Sorpresa", trust = "Confianza")

emociones_letras <- function(tokens, min_palabras = 30) {
  lexico <- function(lengua, idioma) {
    syuzhet::get_sentiment_dictionary("nrc", language = lengua) %>%
      filter(sentiment %in% names(emociones_es)) %>%
      distinct(palabra = word, emocion = sentiment) %>%
      mutate(idioma = idioma)
  }
  lex <- bind_rows(lexico("english", "Inglés"), lexico("spanish", "Español"))
  #### solo español e inglés: para otros idiomas no hay léxico (tasas en 0 y z indefinido)
  largo <- tokens %>% filter(idioma %in% c("Español", "Inglés")) %>% count(artista, cancion, idioma, name = "palabras")
  tokens %>%
    filter(!is.na(idioma)) %>%
    inner_join(lex, by = c("palabra", "idioma"), relationship = "many-to-many") %>%
    count(artista, cancion, idioma, emocion) %>%
    right_join(largo %>% filter(palabras >= min_palabras) %>%
                 crossing(emocion = names(emociones_es)), by = c("artista", "cancion", "idioma", "emocion")) %>%
    mutate(n = coalesce(n, 0L), tasa = 100 * n / palabras) %>%
    group_by(idioma, emocion) %>%
    mutate(z = as.numeric(scale(tasa))) %>%
    ungroup() %>%
    mutate(emocion = emociones_es[emocion])
}

# 3. Quién habla: pronombres ------
#### Al estilo del LIWC (Pennebaker): proporción de pronombres de cada persona sobre el
#### total de pronombres personales de la letra. "Me" está en ambas listas, por eso se
#### usa la lista del idioma detectado de la letra.
pronombres <- list(
  Inglés = list(
    Yo = c("i", "me", "my", "mine", "myself", "i'm", "i've", "i'll", "i'd")
    ,Tú = c("you", "your", "yours", "yourself", "you're", "you've", "you'll", "you'd", "ya")
    ,Nosotros = c("we", "us", "our", "ours", "ourselves", "we're", "we've", "we'll", "we'd")
    ,Ellos = c("they", "them", "their", "theirs", "themselves", "they're", "they've", "they'll", "he", "she", "him", "her", "his")
  )
  ,Español = list(
    Yo = c("yo", "me", "mí", "mi", "mis", "conmigo", "mío", "mía", "míos", "mías")
    ,Tú = c("tú", "tu", "tus", "te", "ti", "contigo", "vos", "usted", "tuyo", "tuya", "tuyos", "tuyas")
    ,Nosotros = c("nosotros", "nosotras", "nos", "nuestro", "nuestra", "nuestros", "nuestras")
    #### sin "los" ni "las", que casi siempre son artículos
    ,Ellos = c("ellos", "ellas", "él", "ella", "les")
  )
)

pronombres_letras <- function(letras, min_pronombres = 10) {
  base <- letras %>% filter(idioma %in% names(pronombres)) %>% select(artista, cancion, idioma, letra)
  base$palabras <- palabras_crudas(base$letra)
  base %>%
    select(-letra) %>%
    mutate(conteo = map2(palabras, idioma, function(p, id) {
      map_int(pronombres[[id]], function(lista) sum(p %in% lista))
    })) %>%
    select(-palabras) %>%
    unnest_wider(conteo) %>%
    mutate(total = Yo + Tú + Nosotros + Ellos) %>%
    filter(total >= min_pronombres) %>%
    mutate(across(c(Yo, Tú, Nosotros, Ellos), ~ .x / total))
}

# 4. Riqueza del vocabulario (MTLD) ------
#### MTLD (McCarthy y Jarvis, 2010): largo promedio de los tramos de texto que mantienen
#### una proporción de palabras distintas sobre 0,72. A diferencia de la razón simple de
#### palabras distintas, no depende del largo de la letra. Se promedia en ambos sentidos.
mtld_sentido <- function(w, umbral = 0.72) {
  factores <- 0; i <- 1; n <- length(w)
  while (i <= n) {
    tramo <- w[i:n]
    ttr <- cumsum(!duplicated(tramo)) / seq_along(tramo)
    k <- which(ttr <= umbral)[1]
    if (is.na(k)) {
      factores <- factores + (1 - ttr[length(ttr)]) / (1 - umbral)
      break
    }
    factores <- factores + 1
    i <- i + k
  }
  if (factores == 0) NA_real_ else n / factores
}

mtld <- function(w, min_palabras = 80) {
  if (length(w) < min_palabras) return(NA_real_)
  mean(c(mtld_sentido(w), mtld_sentido(rev(w))))
}

# 5. Versos y coros ------
#### proporción de versos que se repiten en la letra y cuántas veces suena el verso más
#### repetido (el coro). Solo letras con al menos 8 versos. Va vectorizado sobre todas
#### las letras a la vez (letra por letra tardaba más de 30 s).
versos_letras <- function(letras, min_versos = 8) {
  letras %>%
    select(artista, cancion, letra) %>%
    mutate(verso = str_split(limpiar_marcas(letra), "\n")) %>%
    select(-letra) %>%
    unnest(verso) %>%
    mutate(verso = str_squish(str_replace_all(str_to_lower(verso), "[^\\p{L}\\p{N}' ]", " "))) %>%
    filter(verso != "") %>%
    count(artista, cancion, verso, name = "veces_verso") %>%
    group_by(artista, cancion) %>%
    summarise(versos = sum(veces_verso)
              ,repetidos = sum(veces_verso[veces_verso >= 2]) / sum(veces_verso)
              ,coro = max(veces_verso), .groups = "drop") %>%
    filter(versos >= min_versos)
}

# 6. Similitud con vectores ------
#### los vectores de 03.2 y 03.4 vienen normalizados: el producto punto es el coseno
matriz_vectores <- function(df) {
  m <- as.matrix(select(df, matches("^e[0-9]+$")))
  m / sqrt(rowSums(m^2))
}

#### centroide (promedio normalizado) de un grupo de vectores, con pesos
centroide <- function(m, pesos = rep(1, nrow(m))) {
  v <- colSums(m * pesos) / sum(pesos)
  v / sqrt(sum(v^2))
}
