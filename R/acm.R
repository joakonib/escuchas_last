# 0. Cargo paquetes ------
pacman::p_load(tidyverse)

# 1. Familias de género ------
familia_de <- function(genero) {
  g <- str_to_lower(genero)
  case_when(
    is.na(g) ~ NA_character_
    ,str_detect(g, "hip.hop|rap\\b|trap|reggaeton|urban|grime") ~ "Hip-hop y urbano"
    ,str_detect(g, "cumbia|tropical|salsa|\\bska\\b|reggae|ranchera|bolero") ~ "Tropical y ska"
    ,str_detect(g, "post-punk|new wave|goth|darkwave|coldwave|synthpop") ~ "Post-punk y gótico"
    ,str_detect(g, "metal|sludge|stoner|doom|grind|\\bdjent") ~ "Metal"
    ,str_detect(g, "punk|hardcore|\\bemo\\b|\\boi\\b") ~ "Punk y hardcore"
    ,str_detect(g, "electro|techno|house|ambient|experimental|\\bidm\\b|dance|drone|industrial") ~ "Electrónica y experimental"
    ,str_detect(g, "jazz|blues|classical|soul|funk|r&b") ~ "Jazz, soul y clásica"
    ,str_detect(g, "folk|trova|songwriter|country|cancion|canción") ~ "Folk y trova"
    ,str_detect(g, "pop") ~ "Pop"
    ,str_detect(g, "rock|indie|shoegaze|grunge|alternative|noise") ~ "Rock e indie"
    ,TRUE ~ "Otros géneros"
  )
}

# 2. Base de artistas ------
#### el momento se define contra mi promedio
preparar_acm <- function(escuchas, animo_artista, info, letras, min_escuchas = 20) {
  base <- escuchas %>%
    group_by(artista) %>%
    summarise(
      total = n()
      ,genero = first(na.omit(genero))
      ,pais = first(na.omit(pais))
      ,debut = min(anio), anios_activo = n_distinct(anio)
      ,laboral = mean(!semana %in% c("sáb", "dom") & hora >= 9 & hora < 18)
      ,noche = mean(hora >= 20 | hora < 6)
      ,finde = mean(semana %in% c("sáb", "dom"))
      ,.groups = "drop"
    ) %>%
    filter(total >= min_escuchas)

  prom <- escuchas %>% summarise(laboral = mean(!semana %in% c("sáb", "dom") & hora >= 9 & hora < 18)
                                ,noche = mean(hora >= 20 | hora < 6)
                                ,finde = mean(semana %in% c("sáb", "dom")))
  idx <- cbind(base$laboral / prom$laboral, base$noche / prom$noche, base$finde / prom$finde)
  momentos <- c("Más en horario laboral", "Más de noche", "Más el fin de semana")

  idioma <- letras %>%
    filter(!is.na(idioma)) %>%
    count(artista, idioma) %>%
    group_by(artista) %>%
    slice_max(n, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(artista, idioma_letras = idioma)

  base %>%
    left_join(select(info, artista, oyentes), by = "artista") %>%
    left_join(animo_artista, by = "artista") %>%
    left_join(idioma, by = "artista") %>%
    mutate(
      Género = coalesce(familia_de(genero), "Género sin dato")
      ,Origen = case_when(
        is.na(pais) ~ "Origen sin dato"
        ,pais == "Chile" ~ "Chile"
        ,pais == "Argentina" ~ "Argentina"
        ,pais %in% c("México", "España", "Colombia", "Perú", "Uruguay", "Venezuela", "Cuba", "Puerto Rico", "Brasil") ~ "Resto de Iberoamérica"
        ,pais %in% c("EE.UU.", "Canadá") ~ "Norteamérica"
        ,pais %in% c("Reino Unido", "Irlanda") ~ "Reino Unido e Irlanda"
        ,TRUE ~ "Resto del mundo"
      )
      ,Popularidad = case_when(
        is.na(oyentes) ~ "Popularidad sin dato"
        ,oyentes < 1e5 ~ "Underground o de culto"
        ,oyentes < 1e6 ~ "Conocido"
        ,TRUE ~ "Masivo"
      )
      ,Ánimo = case_when(
        is.na(valencia) ~ "Ánimo sin dato"
        ,valencia < 0 & energia >= 0.4 ~ "Tenso"
        ,valencia < 0 ~ "Melancólico"
        ,energia >= 0.4 ~ "Eufórico"
        ,TRUE ~ "Sereno"
      )
      ,Momento = momentos[max.col(idx, ties.method = "first")]
      ,Permanencia = case_when(anios_activo <= 2 ~ "Flechazo (1 o 2 años)"
                              ,anios_activo <= 5 ~ "De varios años (3 a 5)"
                              ,TRUE ~ "De largo aliento (6 o más)")
      ,Intensidad = case_when(total < 50 ~ "Pocas escuchas (20 a 49)"
                             ,total < 200 ~ "Escuchas medias (50 a 199)"
                             ,TRUE ~ "Muchas escuchas (200 o más)")
      ,Idioma = coalesce(idioma_letras, "Sin letras")
      ,Época = cut(debut, c(2012, 2015, 2018, 2021, 2024, 2030)
                  ,labels = c("Llegó en 2013–2015", "Llegó en 2016–2018", "Llegó en 2019–2021"
                             ,"Llegó en 2022–2024", "Llegó en 2025–2026"))
    )
}

# 3. Análisis de correspondencias múltiples ------
#### tasa modificada de Benzécri; las categorías sin dato no definen los ejes
acm <- function(datos, activas, suplementarias = character(), min_n = 10, ejes = 3) {
  Z <- do.call(cbind, lapply(activas, function(v) {
    niveles <- sort(unique(as.character(datos[[v]])))
    m <- sapply(niveles, function(n) as.numeric(as.character(datos[[v]]) == n))
    colnames(m) <- paste(v, niveles, sep = "|")
    m
  }))
  excluir <- str_detect(colnames(Z), "sin dato|Sin letras") | colSums(Z) < min_n
  n <- nrow(Z); Q <- length(activas)
  c_masa <- colSums(Z) / (n * Q)
  S <- (Z / (n * Q) - (1 / n) * matrix(c_masa, n, ncol(Z), byrow = TRUE)) /
    sqrt(matrix(c_masa / n, n, ncol(Z), byrow = TRUE))
  S <- S[, !excluir]
  c_masa <- c_masa[!excluir]
  dvs <- svd(S, nu = ejes, nv = ejes)
  lambda <- dvs$d^2

  mod <- ifelse(lambda > 1 / Q, (Q / (Q - 1) * (lambda - 1 / Q))^2, 0)
  tasa <- mod / sum(mod)

  filas <- dvs$u[, 1:ejes] %*% diag(dvs$d[1:ejes]) * sqrt(n)
  columnas <- diag(1 / sqrt(c_masa)) %*% dvs$v[, 1:ejes] %*% diag(dvs$d[1:ejes])
  colnames(filas) <- colnames(columnas) <- paste0("d", 1:ejes)
  partes <- str_split_fixed(colnames(S), "\\|", 2)
  categorias <- as_tibble(columnas) %>%
    mutate(variable = partes[, 1], categoria = partes[, 2], n = round(c_masa * n * Q)
           ,ctr1 = dvs$v[, 1]^2, ctr2 = dvs$v[, 2]^2, tipo = "activa")

  sup <- bind_rows(lapply(suplementarias, function(v) {
    bind_rows(lapply(split(seq_len(n), as.character(datos[[v]])), function(i) {
      tibble(d1 = mean(filas[i, 1]) / dvs$d[1], d2 = mean(filas[i, 2]) / dvs$d[2]
             ,d3 = mean(filas[i, 3]) / dvs$d[3], n = length(i))
    }), .id = "categoria") %>% mutate(variable = v, tipo = "suplementaria")
  }))
  list(filas = filas, categorias = bind_rows(categorias, sup), tasa = tasa, lambda = lambda, Q = Q)
}
