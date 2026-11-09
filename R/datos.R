# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,arrow
)

# 1. Lectura y escritura ------
#### readBin evita que Windows deje bloqueado el archivo
leer_parquet <- function(f) read_parquet(readBin(f, "raw", file.size(f)))

#### escribe a un temporal: un corte no daña el archivo anterior
guardar_parquet <- function(x, f) {
  temporal <- paste0(f, ".tmp")
  write_parquet(x, temporal)
  if (!file.rename(temporal, f)) stop("No se pudo reemplazar ", f)
  invisible(f)
}

# 2. Escuchas ------
#### excluye las escuchas sin fecha (01-01-1970)
leer_escuchas <- function(zona = "America/Santiago") {
  leer_parquet("data/escuchas.parquet") %>%
    filter(uts >= as.numeric(as.POSIXct("2002-01-01", tz = "UTC"))) %>%
    mutate(fecha = with_tz(as_datetime(uts), zona))
}
