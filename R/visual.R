# 0. Cargo paquetes ------
pacman::p_load(
  reactable
  ,plotly
  ,htmltools
)

# 1. Tema de las tablas ------
verde_tabla  <- "#2f7d4a"
rampa_tabla  <- c("#f1f5f1", "#d4e5d8", "#a7cbb0", "#72a982", "#428556", "#27613a")

tema_tabla <- reactableTheme(
  color = "#1f1f1f",
  backgroundColor = "#ffffff",
  borderColor = "#ecebe7",
  stripedColor = "#f7f9f7",
  highlightColor = "#e6f0e8",
  cellPadding = "7px 10px"
  ,style = list(fontSize = "13.5px")
  ,headerStyle = list(
    background = "#2f2f2f", color = "#ffffff", fontWeight = 600,
    fontSize = "12.5px", borderBottom = "none"
  )
  ,searchInputStyle = list(width = "100%", marginBottom = "8px")
  ,paginationStyle = list(fontSize = "12.5px")
)

idioma_tabla <- reactableLang(
  searchPlaceholder = "Buscar…", noData = "Sin resultados"
  ,pageInfo = "{rowStart}–{rowEnd} de {rows}", pagePrevious = "Anterior"
  ,pageNext = "Siguiente", pageNumbers = "{page} de {pages}"
)

# 2. Tablas ------
tabla <- function(datos, columnas = list(), titulo = NULL, subtitulo = NULL
                  ,filas = 12, clase = NULL, ...) {
  larga <- nrow(datos) > filas
  if (any(vapply(columnas, function(col) isTRUE(col$minWidth >= 180), logical(1)))) clase <- c(clase, "tabla-texto")
  id <- paste0("tabla-", paste(sample(c(letters, 0:9), 10, replace = TRUE), collapse = ""))
  datos$.orden <- seq_len(nrow(datos))
  columnas$.orden <- colDef(show = FALSE)
  t <- reactable(
    datos, columns = columnas, theme = tema_tabla, language = idioma_tabla
    ,striped = TRUE, highlight = TRUE, sortable = TRUE, compact = TRUE
    ,searchable = larga, pagination = larga, defaultPageSize = filas
    ,showSortIcon = TRUE, elementId = id, ...
  )
  boton <- htmltools::tags$button(
    class = "tabla-reset", type = "button"
    ,onclick = sprintf("Reactable.toggleSortBy('%s', '.orden', false); Reactable.setSearch('%s', '')", id, id)
    ,"↺ Orden original"
  )
  div(class = paste(c("tabla", unique(clase)), collapse = " ")
      ,if (!is.null(titulo)) div(class = "tabla-titulo", titulo)
      ,if (!is.null(subtitulo)) div(class = "tabla-subtitulo", subtitulo)
      ,div(class = "tabla-ayuda", "↕ Haz clic en el nombre de una columna para ordenar", boton)
      ,t)
}

## 2.1 Columna con barra ------
col_barra <- function(nombre, maximo, formato = function(x) format(x, big.mark = ".", decimal.mark = ",")
                      ,color = verde_tabla, ...) {
  colDef(name = nombre, align = "left", minWidth = 140, ..., cell = function(valor) {
    ancho <- if (is.na(valor)) 0 else max(2, round(100 * valor / maximo))
    div(style = "display:flex;align-items:center;gap:8px"
        ,div(style = "flex:1;background:#eef3ef;border-radius:3px;height:10px",
            div(style = sprintf("width:%s%%;background:%s;height:10px;border-radius:3px", ancho, color)))
        ,span(style = "min-width:52px;text-align:right;font-variant-numeric:tabular-nums"
             ,if (is.na(valor)) "" else formato(valor)))
  })
}

## 2.2 Columna con escala de verdes ------
col_calor <- function(nombre, rango, formato = function(x) format(x, big.mark = ".", decimal.mark = ","), ...) {
  escala <- colorRamp(rampa_tabla)
  colDef(name = nombre, align = "center", ..., cell = function(valor) if (is.na(valor)) "" else formato(valor)
         ,style = function(valor) {
           if (is.na(valor)) return(NULL)
           t <- min(max((valor - rango[1]) / diff(rango), 0), 1)
           rgb_v <- escala(t)
           list(background = rgb(rgb_v[1], rgb_v[2], rgb_v[3], maxColorValue = 255)
                ,color = if (t > 0.6) "#ffffff" else "#1f1f1f", fontWeight = 600)
         })
}

# 3. Gráficos interactivos ------
#### título como HTML: plotly no muestra subtítulos; sin zoom para el celular
interactivo <- function(p, tooltip = "text") {
  titulo <- p$labels$title
  subtitulo <- p$labels$subtitle
  p <- p + labs(title = NULL, subtitle = NULL)
  alto <- (knitr::opts_current$get("fig.height") %||% 5) * 90
  g <- ggplotly(p, tooltip = tooltip, height = alto) %>%
    config(displayModeBar = FALSE, locale = "es", scrollZoom = FALSE, responsive = TRUE) %>%
    layout(
      hoverlabel = list(bgcolor = "#ffffff", bordercolor = "#cfcfcb",
                        font = list(color = "#1f1f1f", size = 12)),
      legend = list(orientation = "h", x = 0, y = 1.08)
      ,margin = list(t = 10),
      dragmode = FALSE
      ,hovermode = "closest"
    )
  g <- plotly_build(g)
  ejes <- grep("^[xy]axis", names(g$x$layout), value = TRUE)
  g$x$layout[ejes] <- purrr::map(g$x$layout[ejes], function(eje) {
    eje$fixedrange <- TRUE
    eje
  })
  #### borde blanco entre barras para separar los tonos claros
  g$x$data <- purrr::map(g$x$data, function(traza) {
    if (identical(traza$type, "bar")) traza$marker$line <- list(color = "#ffffff", width = 1.5)
    traza
  })
  g$width <- "100%"
  div(class = "grafico"
      ,if (!is.null(titulo)) div(class = "tabla-titulo", titulo)
      ,if (!is.null(subtitulo)) div(class = "tabla-subtitulo", subtitulo)
      ,g)
}

# 4. Navegación ------
navegacion <- function(actual = c("general", "mensual", "metodologia", "flujo")) {
  actual <- match.arg(actual)
  paginas <- list(
    portada     = c("index.html", "🏠 Portada")
    ,general     = c("analisis_escuchas.html", "📈 General")
    ,mensual     = c("reporte_mensual.html", "📆 Del mes")
    ,metodologia = c("metodologia.html", "🔧 Metodología")
    ,flujo       = c("flujo.html", "🔄 Flujo")
  )
  htmltools::tags$nav(class = "nav-reportes", `aria-label` = "Reportes"
           ,lapply(names(paginas), function(id) {
             if (id == actual) htmltools::tags$span(class = "nav-actual", `aria-current` = "page", paginas[[id]][2])
             else htmltools::tags$a(href = paginas[[id]][1], paginas[[id]][2])
           }))
}

## 4.1 Botón para volver ------
boton_volver <- function() {
  div(class = "volver"
      ,htmltools::tags$a(class = "volver-principal", href = "analisis_escuchas.html", "← Reporte general")
      ,htmltools::tags$a(class = "volver-portada", href = "index.html", title = "Portada", `aria-label` = "Portada", "🏠"))
}

## 4.2 Fecha de generación ------
linea_generacion <- function(zona = "America/Santiago") {
  ahora <- format(lubridate::with_tz(Sys.time(), zona), "%d-%m-%Y, %H:%M")
  div(class = "generado", paste0("🕒 Fecha y hora de generación: ", ahora, " (hora de Chile)"))
}

# 5. Ciro, la mascota ------
#### si la imagen aún no existe no se muestra nada (los Ciros nuevos se suman al llegar)
ciro <- function(cual = c("metal", "postpunk", "rapero", "encuestas", "natural", "cafe"
                          ,"audifonos", "flujo", "letras", "hardcore", "ozzy"
                          ,"lluvia", "crooner", "cumbia", "explorador", "colocolo", "eras", "neblina"
                          ,"nicho", "mundo", "fan", "genealogia", "laboratorio", "archivo", "limpieza", "guardia")
                 ,clase = "ciro-saludo") {
  cual <- match.arg(cual)
  archivo <- paste0("assets/ciro/ciro_", cual, ".webp")
  if (!file.exists(archivo)) return(NULL)
  alt <- c(metal    = "Ciro, mi gato gris y blanco, con muñequeras de púas y una guitarra de black metal"
           ,postpunk = "Ciro, mi gato gris y blanco, con chaqueta de pana, chapitas y un ramo de flores, cara de post-punk"
           ,rapero   = "Ciro, mi gato gris y blanco, con buzo verde y jockey, micrófono en mano, como rapero de Kneecap"
           ,encuestas = "Ciro, mi gato gris y blanco, con chaleco verde, lápiz y una tablilla que dice «Ciro encuestas»"
           ,natural  = "Ciro, mi gato gris y blanco de pelo largo, parado en dos patas"
           ,cafe     = "Ciro, mi gato gris y blanco, con camisa hawaiana de flores y los ojos cerrados de gusto, tomando una taza de café"
           ,audifonos = "Ciro, mi gato gris y blanco, con audífonos verdes y polerón, sentado sobre un vinilo con un café, disfrutando la música con los ojos cerrados"
           ,flujo    = "Ciro, mi gato gris y blanco, con casco de obra y chaleco verde, cuidando una máquina de tubos que convierte notas y vinilos en un gráfico de barras"
           ,letras   = "Ciro, mi gato gris y blanco, de detective con sombrero, gabardina y lupa, revisando un cuaderno de partituras"
           ,hardcore = "Ciro, mi gato gris y blanco, gritando al micrófono con polera negra con una dinamita, bandana y muñequera de tachas, como cantante de hardcore"
           ,ozzy     = "Ciro, mi gato gris y blanco, como Ozzy Osbourne: peluca negra, lentes redondos morados, cruz plateada, chaqueta con flecos y un murciélago en el hombro"
           ,lluvia   = "Ciro, mi gato gris y blanco, con impermeable verde, botas de agua, paraguas y audífonos, caminando feliz bajo una lluvia de gotas y notas musicales"
           ,crooner  = "Ciro, mi gato gris y blanco, de cantante de bar con traje negro y sombrero, apoyado en un piano viejo junto a un micrófono antiguo, con cara melancólica"
           ,cumbia   = "Ciro, mi gato gris y blanco, con camisa floreada verde y naranja, bailando cumbia con un güiro entre serpentinas y notas musicales"
           ,explorador = "Ciro, mi gato gris y blanco, de explorador con sombrero safari, mochila y brújula, mirando entusiasmado un mapa lleno de vinilos"
           ,colocolo = "Ciro, mi gato gris y blanco, con la camiseta y la bufanda de Colo-Colo, celebrando un gol con el puño en alto y una pata sobre la pelota"
           ,eras     = "Ciro, mi gato gris y blanco, sentado sobre una torre de cassettes, CDs y vinilos, abrazando un walkman con audífonos naranjas al cuello"
           ,neblina  = "Ciro, mi gato gris y blanco, con polera negra y los ojos cerrados, sereno frente a una pared de amplificadores envuelta en neblina dorada"
           ,nicho    = "Ciro, mi gato gris y blanco, buscando discos raros en un cajón de vinilos a la luz de una vela"
           ,mundo    = "Ciro, mi gato gris y blanco, con mochila y pasaporte, abrazando un globo terráqueo lleno de banderitas"
           ,fan      = "Ciro, mi gato gris y blanco, en primera fila de un concierto, feliz con una púa de guitarra en alto"
           ,genealogia = "Ciro, mi gato gris y blanco, junto a un árbol cuyas ramas terminan en discos de vinilo"
           ,laboratorio = "Ciro, mi gato gris y blanco, con delantal de laboratorio y lentes de seguridad, mirando un tubo de ensayo con notas musicales"
           ,archivo  = "Ciro, mi gato gris y blanco, de bibliotecario frente a un fichero de madera lleno de fichas de artistas"
           ,limpieza = "Ciro, mi gato gris y blanco, con delantal y escoba, barriendo notas musicales sueltas"
           ,guardia  = "Ciro, mi gato gris y blanco, de guardia con casco y escudo, cuidando una caja fuerte llena de discos")[[cual]]
  #### ancho/alto de cada imagen en assets/ciro (todas miden 360 px de alto)
  proporcion <- c(metal = 286, postpunk = 266, rapero = 275, encuestas = 284, natural = 283, cafe = 282
                  ,audifonos = 349, flujo = 351, letras = 342, hardcore = 321, ozzy = 323
                  ,lluvia = 324, crooner = 346, cumbia = 334, explorador = 329, colocolo = 327, eras = 350, neblina = 362
                  ,nicho = 371, mundo = 347
                  #### los que aún no tienen imagen quedan con 340 hasta que lleguen (no se muestran)
                  ,fan = 338, genealogia = 408, laboratorio = 379, archivo = 340, limpieza = 340, guardia = 340)[[cual]] / 360
  ancho <- if (clase == "ciro-saludo") 96 else 90
  htmltools::tags$img(src = archivo, alt = alt, class = clase, width = ancho, height = round(ancho / proporcion))
}
