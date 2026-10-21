# Tablas interactivas (reactable) y gráficos interactivos (plotly) con el
# estilo común de los reportes: grises y verdes, sin azul.

library(reactable)
library(plotly)
library(htmltools)

verde_tabla  <- "#2f7d4a"
rampa_tabla  <- c("#f1f5f1", "#d4e5d8", "#a7cbb0", "#72a982", "#428556", "#27613a")

tema_tabla <- reactableTheme(
  color = "#1f1f1f",
  backgroundColor = "#ffffff",
  borderColor = "#ecebe7",
  stripedColor = "#f7f9f7",
  highlightColor = "#e6f0e8",
  cellPadding = "7px 10px",
  style = list(fontSize = "13.5px"),
  headerStyle = list(
    background = "#2f2f2f", color = "#ffffff", fontWeight = 600,
    fontSize = "12.5px", borderBottom = "none"
  ),
  searchInputStyle = list(width = "100%", marginBottom = "8px"),
  paginationStyle = list(fontSize = "12.5px")
)

idioma_tabla <- reactableLang(
  searchPlaceholder = "Buscar…", noData = "Sin resultados",
  pageInfo = "{rowStart}–{rowEnd} de {rows}", pagePrevious = "Anterior",
  pageNext = "Siguiente", pageNumbers = "{page} de {pages}"
)

# Tabla con título, subtítulo, orden por columnas y, si es larga, buscador y páginas
tabla <- function(datos, columnas = list(), titulo = NULL, subtitulo = NULL,
                  filas = 12, clase = NULL, ...) {
  larga <- nrow(datos) > filas
  # Tablas con columnas de texto anchas: en el celular se ajustan al ancho y el texto
  # baja de línea, en vez de obligar a deslizar de lado
  if (any(vapply(columnas, \(col) isTRUE(col$minWidth >= 180), logical(1)))) clase <- c(clase, "tabla-texto")
  # Columna oculta con el orden original, para poder volver a él con un botón
  id <- paste0("tabla-", paste(sample(c(letters, 0:9), 10, replace = TRUE), collapse = ""))
  datos$.orden <- seq_len(nrow(datos))
  columnas$.orden <- colDef(show = FALSE)
  t <- reactable(
    datos, columns = columnas, theme = tema_tabla, language = idioma_tabla,
    striped = TRUE, highlight = TRUE, sortable = TRUE, compact = TRUE,
    searchable = larga, pagination = larga, defaultPageSize = filas,
    showSortIcon = TRUE, elementId = id, ...
  )
  boton <- htmltools::tags$button(
    class = "tabla-reset", type = "button",
    onclick = sprintf("Reactable.toggleSortBy('%s', '.orden', false); Reactable.setSearch('%s', '')", id, id),
    "↺ Orden original"
  )
  div(class = paste(c("tabla", unique(clase)), collapse = " "),
      if (!is.null(titulo)) div(class = "tabla-titulo", titulo),
      if (!is.null(subtitulo)) div(class = "tabla-subtitulo", subtitulo),
      div(class = "tabla-ayuda", "↕ Haz clic en el nombre de una columna para ordenar", boton),
      t)
}

# Columna numérica con una barra horizontal proporcional al valor
col_barra <- function(nombre, maximo, formato = \(x) format(x, big.mark = ".", decimal.mark = ","),
                      color = verde_tabla, ...) {
  colDef(name = nombre, align = "left", minWidth = 140, ..., cell = function(valor) {
    ancho <- if (is.na(valor)) 0 else max(2, round(100 * valor / maximo))
    div(style = "display:flex;align-items:center;gap:8px",
        div(style = "flex:1;background:#eef3ef;border-radius:3px;height:10px",
            div(style = sprintf("width:%s%%;background:%s;height:10px;border-radius:3px", ancho, color))),
        span(style = "min-width:52px;text-align:right;font-variant-numeric:tabular-nums",
             if (is.na(valor)) "" else formato(valor)))
  })
}

# Columna con fondo en escala de verdes según el valor
col_calor <- function(nombre, rango, formato = \(x) format(x, big.mark = ".", decimal.mark = ","), ...) {
  escala <- colorRamp(rampa_tabla)
  colDef(name = nombre, align = "center", ..., cell = \(valor) if (is.na(valor)) "" else formato(valor),
         style = function(valor) {
           if (is.na(valor)) return(NULL)
           t <- min(max((valor - rango[1]) / diff(rango), 0), 1)
           rgb_v <- escala(t)
           list(background = rgb(rgb_v[1], rgb_v[2], rgb_v[3], maxColorValue = 255),
                color = if (t > 0.6) "#ffffff" else "#1f1f1f", fontWeight = 600)
         })
}

# Convierte un ggplot en gráfico interactivo con tooltip. El título y subtítulo
# van como HTML encima, porque plotly no muestra subtítulos.
interactivo <- function(p, tooltip = "text") {
  titulo <- p$labels$title
  subtitulo <- p$labels$subtitle
  p <- p + labs(title = NULL, subtitle = NULL)
  alto <- (knitr::opts_current$get("fig.height") %||% 5) * 90
  g <- ggplotly(p, tooltip = tooltip, height = alto) |>
    config(displayModeBar = FALSE, locale = "es", scrollZoom = FALSE, responsive = TRUE) |>
    layout(
      hoverlabel = list(bgcolor = "#ffffff", bordercolor = "#cfcfcb",
                        font = list(color = "#1f1f1f", size = 12)),
      legend = list(orientation = "h", x = 0, y = 1.08),
      margin = list(t = 10),
      # Sin arrastre ni zoom: en el celular el dedo desliza la página en vez del gráfico
      dragmode = FALSE,
      hovermode = "closest"
    )
  # Fija todos los ejes (incluidos los de paneles múltiples) para que no se muevan al tocar
  g <- plotly_build(g)
  for (eje in grep("^[xy]axis", names(g$x$layout), value = TRUE)) {
    g$x$layout[[eje]]$fixedrange <- TRUE
  }
  # Borde blanco entre barras y segmentos apilados: separa los tonos claros entre sí y del fondo
  for (i in seq_along(g$x$data)) {
    if (identical(g$x$data[[i]]$type, "bar")) {
      g$x$data[[i]]$marker$line <- list(color = "#ffffff", width = 1.5)
    }
  }
  # Ancho adaptable: si no, hereda el ancho fijo de la figura y se sale en el celular
  g$width <- "100%"
  div(class = "grafico",
      if (!is.null(titulo)) div(class = "tabla-titulo", titulo),
      if (!is.null(subtitulo)) div(class = "tabla-subtitulo", subtitulo),
      g)
}

# Barra de navegación entre las páginas, con la actual marcada
navegacion <- function(actual = c("general", "mensual", "metodologia")) {
  actual <- match.arg(actual)
  paginas <- list(
    portada     = c("index.html", "🏠 Portada"),
    general     = c("analisis_escuchas.html", "📈 General"),
    mensual     = c("reporte_mensual.html", "📆 Del mes"),
    metodologia = c("metodologia.html", "🔧 Metodología")
  )
  htmltools::tags$nav(class = "nav-reportes", `aria-label` = "Reportes",
           lapply(names(paginas), \(id) {
             if (id == actual) htmltools::tags$span(class = "nav-actual", `aria-current` = "page", paginas[[id]][2])
             else htmltools::tags$a(href = paginas[[id]][1], paginas[[id]][2])
           }))
}

# Botón flotante para volver al reporte general (y a la portada) desde las otras páginas
boton_volver <- function() {
  div(class = "volver",
      htmltools::tags$a(class = "volver-principal", href = "analisis_escuchas.html", "← Reporte general"),
      htmltools::tags$a(class = "volver-portada", href = "index.html", title = "Portada", `aria-label` = "Portada", "🏠"))
}

# Línea con la fecha y hora en que se generó el reporte
linea_generacion <- function(zona = "America/Santiago") {
  ahora <- format(lubridate::with_tz(Sys.time(), zona), "%d-%m-%Y, %H:%M")
  div(class = "generado", paste0("🕒 Fecha y hora de generación: ", ahora, " (hora de Chile)"))
}
