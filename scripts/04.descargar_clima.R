remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(httr2)
source("R/datos.R")

# 1. Punto de partida ------
#### se repiten los últimos 10 días porque el histórico tarda en consolidarse
archivo <- "data/clima.parquet"

previo <- if (file.exists(archivo)) leer_parquet(archivo) else NULL
desde <- if (is.null(previo)) as.Date("2013-09-01") else max(previo$dia) - 10
hasta <- Sys.Date() - 2

# 2. Descarga desde Open-Meteo ------
resp <- request("https://archive-api.open-meteo.com/v1/archive") %>%
  req_url_query(
    latitude = -33.45, longitude = -70.67
    ,start_date = format(desde), end_date = format(hasta)
    ,daily = "temperature_2m_mean,precipitation_sum,sunshine_duration"
    ,timezone = "America/Santiago"
  ) %>%
  req_timeout(60) %>%
  req_retry(max_tries = 3) %>%
  req_perform() %>%
  resp_body_json(simplifyVector = TRUE)

nuevo <- tibble(
  dia = as.Date(resp$daily$time)
  ,temperatura = as.numeric(resp$daily$temperature_2m_mean)
  ,lluvia_mm = as.numeric(resp$daily$precipitation_sum)
  ,sol_horas = as.numeric(resp$daily$sunshine_duration) / 3600
) %>%
  filter(!is.na(temperatura), !is.na(lluvia_mm))

# 3. Guardado ------
clima <- bind_rows(filter(previo %||% nuevo[0, ], dia < min(nuevo$dia)), nuevo) %>% arrange(dia)
guardar_parquet(clima, archivo)
message("Clima listo: ", nrow(clima), " días, hasta ", max(clima$dia))
