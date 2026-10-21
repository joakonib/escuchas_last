# Diccionarios para interpretar las etiquetas (tags) de Last.fm. Los usan
# analisis_escuchas.qmd y reporte_mensual.qmd, para que ambos apliquen las mismas reglas.

# Etiquetas de nacionalidad -> país
paises <- c(
  chilean = "Chile", chile = "Chile", argentine = "Argentina", argentina = "Argentina",
  argentinian = "Argentina", mexican = "México", mexico = "México", spanish = "España",
  spain = "España", colombian = "Colombia", colombia = "Colombia", peruvian = "Perú",
  uruguayan = "Uruguay", venezuelan = "Venezuela", cuban = "Cuba", "puerto rico" = "Puerto Rico",
  "puerto rican" = "Puerto Rico", brazilian = "Brasil", brazil = "Brasil",
  american = "EE.UU.", usa = "EE.UU.", british = "Reino Unido", uk = "Reino Unido",
  english = "Reino Unido", scottish = "Reino Unido", welsh = "Reino Unido", irish = "Irlanda",
  canadian = "Canadá", australian = "Australia", french = "Francia", german = "Alemania",
  swedish = "Suecia", icelandic = "Islandia", norwegian = "Noruega", japanese = "Japón",
  korean = "Corea del Sur", "k-pop" = "Corea del Sur", italian = "Italia", belgian = "Bélgica",
  dutch = "Países Bajos", danish = "Dinamarca", finnish = "Finlandia", "new zealand" = "Nueva Zelanda"
)
voces <- c("female vocalists", "female vocalist", "male vocalists", "male vocalist")
basura <- c(
  "seen live", "favorites", "favourite", "favourites", "favorite", "love", "awesome",
  "beautiful", "amazing", "cool", "good", "best", "fav", "my favorite", "all", "music",
  "under 2000 listeners", "spotify", "albums i own", "vocalists", "male", "female",
  "singer-songwriter", "00s", "10s", "90s", "80s", "70s", "60s", "2000s", "2010s", "2020s",
  "latin", "latino", "español", "spanish language", "english", "instrumental", "composer",
  "producer", "dj", "band", "rapper", "legend", "genius", "classic", "american", "british"
)

# Etiquetas de ánimo: valencia (-1 triste, +1 alegre) y energía (-1 calma, +1 intensa),
# según el modelo circunflejo de Russell (1980)
animo_tags <- tribble(
  ~tag,               ~valencia, ~energia,
  "happy",                  1,    0.4,
  "upbeat",                 1,    0.6,
  "fun",                    0.9,  0.5,
  "feel good",              1,    0.3,
  "uplifting",              0.9,  0.4,
  "party",                  0.8,  0.8,
  "summer",                 0.7,  0.3,
  "love",                   0.6,  0,
  "romantic",               0.5, -0.3,
  "dance",                  0.6,  0.7,
  "cumbia",                 0.6,  0.5,
  "pop",                    0.4,  0.2,
  "power pop",              0.6,  0.5,
  "ska",                    0.6,  0.6,
  "funk",                   0.6,  0.5,
  "sad",                   -1,   -0.3,
  "melancholic",           -0.9, -0.4,
  "melancholy",            -0.9, -0.4,
  "depressive",            -1,   -0.2,
  "depressing",            -1,   -0.3,
  "dark",                  -0.8,  0.2,
  "gloomy",                -0.8, -0.3,
  "bleak",                 -0.8,  0,
  "lonely",                -0.8, -0.4,
  "heartbreak",            -0.8, -0.2,
  "emotional",             -0.4,  0,
  "haunting",              -0.5, -0.2,
  "misanthropic",          -0.8,  0.7,
  "angry",                 -0.6,  0.9,
  "aggressive",            -0.4,  1,
  "energetic",              0.3,  1,
  "intense",               -0.2,  0.9,
  "heavy",                 -0.3,  0.8,
  "loud",                   0,    0.8,
  "brutal",                -0.5,  1,
  "noise",                 -0.3,  0.8,
  "chaotic",               -0.3,  0.9,
  "powerful",               0.2,  0.8,
  "calm",                   0.3, -1,
  "chill",                  0.4, -0.9,
  "chillout",               0.4, -0.9,
  "mellow",                 0.2, -0.8,
  "relaxing",               0.4, -1,
  "soft",                   0.2, -0.8,
  "peaceful",               0.5, -1,
  "dreamy",                 0.2, -0.7,
  "ambient",                0,   -0.9,
  "atmospheric",           -0.2, -0.4,
  "acoustic",               0.2, -0.6,
  "slowcore",              -0.6, -0.9,
  "doom metal",            -0.7,  0.4,
  "black metal",           -0.7,  0.9,
  "death metal",           -0.5,  1,
  "thrash metal",          -0.2,  1,
  "hardcore",              -0.3,  1,
  "punk",                   0,    0.9,
  "post-punk",             -0.4,  0.5,
  "gothic",                -0.7,  0.2,
  "darkwave",              -0.7,  0.3,
  "shoegaze",              -0.2, -0.2,
  "post-rock",             -0.2, -0.2,
  "sludge",                -0.6,  0.8,
  "folk",                   0.2, -0.5,
  "singer-songwriter",     -0.1, -0.5
)

# Agrega a las escuchas el género principal y el país de cada artista
agregar_genero_pais <- function(escuchas, tags) {
  genero_artista <- tags |>
    filter(!tag %in% c(basura, names(paises), voces)) |>
    group_by(artista) |>
    slice_max(peso, n = 1, with_ties = FALSE) |>
    ungroup() |>
    transmute(artista, genero = stringr::str_to_sentence(tag))

  pais_artista <- tags |>
    filter(tag %in% names(paises)) |>
    mutate(pais = paises[tag]) |>
    group_by(artista) |>
    slice_max(peso, n = 1, with_ties = FALSE) |>
    ungroup() |>
    select(artista, pais)

  escuchas |>
    left_join(genero_artista, by = "artista") |>
    left_join(pais_artista, by = "artista") |>
    mutate(pais = ifelse(artista %in% names(pais_manual), unname(pais_manual[artista]), pais))
}

# Valencia y energía de cada artista: promedio de sus etiquetas de ánimo, ponderado por peso
animo_por_artista <- function(tags) {
  tags |>
    inner_join(animo_tags, by = "tag") |>
    group_by(artista) |>
    summarise(valencia = weighted.mean(valencia, peso), energia = weighted.mean(energia, peso))
}

# Código ISO de cada país, para mostrar su bandera (imágenes de flagcdn.com)
codigo_pais <- c(
  "Chile" = "cl", "Argentina" = "ar", "México" = "mx", "España" = "es", "Colombia" = "co",
  "Perú" = "pe", "Uruguay" = "uy", "Venezuela" = "ve", "Cuba" = "cu", "Puerto Rico" = "pr",
  "Brasil" = "br", "EE.UU." = "us", "Reino Unido" = "gb", "Irlanda" = "ie", "Canadá" = "ca",
  "Australia" = "au", "Francia" = "fr", "Alemania" = "de", "Suecia" = "se", "Islandia" = "is",
  "Noruega" = "no", "Japón" = "jp", "Corea del Sur" = "kr", "Italia" = "it", "Bélgica" = "be",
  "Países Bajos" = "nl", "Dinamarca" = "dk", "Finlandia" = "fi", "Nueva Zelanda" = "nz"
)
bandera <- function(pais) sprintf("https://flagcdn.com/w40/%s.png", codigo_pais[pais])

# Países corregidos a mano: artistas cuyas etiquetas en Last.fm no indican (bien) su país
pais_manual <- c(
  "Marcel Duchamp" = "Chile"   # banda punk chilena; sus etiquetas se mezclan con las del artista francés
)
