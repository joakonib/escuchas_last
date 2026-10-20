# Genera reportes/reporte_AAAA-MM.html con lo escuchado en un mes.
#
# Uso: Rscript generar_reporte_mensual.R            -> mes anterior
#      Rscript generar_reporte_mensual.R 2026-09    -> mes indicado

library(lubridate)

args <- commandArgs(trailingOnly = TRUE)
mes <- if (length(args) > 0) args[1] else format(floor_date(today(), "month") - months(1), "%Y-%m")

dir.create("reportes", showWarnings = FALSE)
salida <- paste0("reporte_", mes, ".html")

quarto <- Sys.which("quarto")
if (quarto == "") quarto <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe"

estado <- system2(quarto, c("render", "reporte_mensual.qmd", "-P", paste0("mes:", mes),
                            "--output", salida))
if (estado != 0) stop("Falló el render del reporte de ", mes)

file.rename(salida, file.path("reportes", salida))
message("Reporte listo: reportes/", salida)
