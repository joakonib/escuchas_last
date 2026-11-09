remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(tidyverse)

# 1. Mes del reporte ------
#### sin argumento usa el mes anterior
args <- commandArgs(trailingOnly = TRUE)
mes <- if (length(args) > 0) args[1] else format(floor_date(today(), "month") - months(1), "%Y-%m")

dir.create("reportes", showWarnings = FALSE)
salida <- paste0("reporte_", mes, ".html")

# 2. Render y copia ------
quarto <- Sys.which("quarto")
if (quarto == "") quarto <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe"

estado <- system2(quarto, c("render", "08.reporte_mensual.qmd", "-P", paste0("mes:", mes)
                            ,"--output", salida))
if (estado != 0) stop("Falló el render del reporte de ", mes)

file.rename(salida, file.path("reportes", salida))
file.copy(file.path("reportes", salida), "reporte_mensual.html", overwrite = TRUE)
message("Reporte listo: reportes/", salida, " (copia en reporte_mensual.html)")
