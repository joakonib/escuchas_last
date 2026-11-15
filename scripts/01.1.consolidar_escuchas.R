remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,arrow
)
source("R/datos.R")

# 1. Configuración ------
#### Last.fm manda; Spotify solo rellena los momentos en que Last.fm no registró nada
zip_spotify <- Sys.getenv("SPOTIFY_ZIP", "data/my_spotify_data.zip")
salida <- "data/escuchas_consolidadas.parquet"
ventana_par <- 10 * 60         # misma canción a menos de 10 min: la misma escucha
ventana_corrida <- 6 * 3600    # scrobbles guardados con la hora corrida
ventana_hueco <- 10 * 60       # sin nada en Last.fm a 10 min: hueco del scrobbler

lastfm <- leer_parquet("data/escuchas.parquet") %>%
  mutate(id_lf = row_number())

if (!file.exists(zip_spotify)) {
  message("No está ", zip_spotify, ": la base consolidada queda igual a Last.fm")
  guardar_parquet(lastfm %>% select(-id_lf) %>% mutate(fuente = "lastfm"), salida)
  quit(save = "no")
}

#### Spotify marca el fin de la canción; Last.fm, el inicio
spotify <- leer_spotify(zip_spotify, zona = "UTC") %>%
  filter(cuenta) %>%
  mutate(id_sp = row_number(), uts = round(as.numeric(fecha) - ms / 1000))

# 2. Llaves de cruce ------
llaves <- function(d) mutate(d, ka = normalizar(artista), kc = normalizar(limpiar_titulo(cancion)))
lf_k <- lastfm %>% filter(uts >= min(spotify$uts) - ventana_corrida) %>% llaves()
sp_k <- llaves(spotify)

## 2.1 Alias de artistas ------
#### misma canción al mismo tiempo con otro nombre de artista (p. ej. Anri / 杏里)
alias <- inner_join(
  select(sp_k, ka_sp = ka, kc, uts)
  ,select(lf_k, ka_lf = ka, kc, uts_lf = uts)
  ,by = "kc", relationship = "many-to-many"
) %>%
  filter(abs(uts_lf - uts) <= 120, ka_sp != ka_lf) %>%
  count(ka_sp, ka_lf, sort = TRUE) %>%
  filter(n >= 3, !ka_sp %in% lf_k$ka) %>%
  distinct(ka_sp, .keep_all = TRUE)
sp_k <- sp_k %>%
  left_join(select(alias, ka = ka_sp, ka_lf), by = "ka") %>%
  mutate(ka = coalesce(ka_lf, ka)) %>%
  select(-ka_lf)

# 3. Cruce uno a uno ------
#### primero la pareja más cercana; cada escucha se usa una sola vez
emparejar <- function(sp, lf, ventana) {
  inner_join(
    select(sp, id_sp, ka, kc, uts)
    ,select(lf, id_lf, ka, kc, uts_lf = uts)
    ,by = c("ka", "kc"), relationship = "many-to-many"
  ) %>%
    mutate(d = abs(uts_lf - uts)) %>%
    filter(d <= ventana) %>%
    arrange(d) %>%
    filter(!duplicated(id_sp)) %>%
    filter(!duplicated(id_lf)) %>%
    select(id_sp, id_lf)
}
pares <- reduce(c(ventana_par, ventana_corrida), function(acumulado, v) {
  bind_rows(acumulado, emparejar(
    filter(sp_k, !id_sp %in% acumulado$id_sp)
    ,filter(lf_k, !id_lf %in% acumulado$id_lf)
    ,v
  ))
}, .init = tibble(id_sp = integer(), id_lf = integer()))

# 4. Escuchas que solo tiene Spotify ------
lf_t <- sort(lastfm$uts)
hay_lastfm_cerca <- function(t, v) {
  i <- findInterval(t, lf_t)
  pmin(abs(t - lf_t[pmax(i, 1)]), abs(lf_t[pmin(i + 1, length(lf_t))] - t)) <= v
}
sin_pareja <- sp_k %>%
  filter(!id_sp %in% pares$id_sp) %>%
  mutate(hueco = !hay_lastfm_cerca(uts, ventana_hueco))

## 4.1 Nombres, disco y mbid según Last.fm ------
#### si la canción o el artista ya existen en Last.fm, se usa ese nombre
lf_todo <- llaves(lastfm)
canon_cancion <- lf_todo %>%
  count(ka, kc, artista, cancion, album, mbid_cancion, mbid_artista, mbid_album) %>%
  arrange(desc(!is.na(album) & album != ""), desc(n)) %>%
  distinct(ka, kc, .keep_all = TRUE) %>%
  select(-n)
canon_artista <- lf_todo %>%
  count(ka, artista, mbid_artista, sort = TRUE) %>%
  distinct(ka, .keep_all = TRUE) %>%
  select(ka, artista_lf = artista, mbid_artista_lf = mbid_artista)

nuevas <- sin_pareja %>%
  filter(hueco) %>%
  select(uts, ka, kc, artista_sp = artista, cancion_sp = cancion) %>%
  left_join(canon_cancion, by = c("ka", "kc")) %>%
  left_join(canon_artista, by = "ka") %>%
  transmute(
    uts
    ,fecha_utc = as.POSIXct(uts, origin = "1970-01-01", tz = "UTC")
    ,artista = coalesce(artista, artista_lf, artista_sp)
    ,album
    ,cancion = coalesce(cancion, cancion_sp)
    ,mbid_cancion
    ,mbid_artista = coalesce(mbid_artista, mbid_artista_lf)
    ,mbid_album
    ,fuente = "spotify"
  )

# 5. Base consolidada ------
consolidada <- lastfm %>%
  mutate(fuente = if_else(id_lf %in% pares$id_lf, "ambas", "lastfm")) %>%
  select(-id_lf) %>%
  bind_rows(nuevas) %>%
  arrange(uts)

## 5.1 Nombres unificados ------
#### mismo nombre salvo tildes, mayúsculas o signos: se usa la forma más escuchada
#### (p. ej. Arcangel / Arcángel, KNEECAP / Kneecap)
forma_comun <- function(d, ...) {
  d %>%
    count(..., nombre, name = "veces") %>%
    arrange(desc(veces)) %>%
    distinct(..., .keep_all = TRUE) %>%
    select(..., comun = nombre)
}
artistas <- consolidada %>%
  transmute(ka = normalizar(artista), nombre = artista) %>%
  forma_comun(ka)
consolidada <- consolidada %>%
  mutate(ka = normalizar(artista)) %>%
  left_join(artistas, by = "ka") %>%
  mutate(artista_original = artista, artista = comun) %>%
  select(-comun)
canciones <- consolidada %>%
  transmute(ka, kc = normalizar(cancion), nombre = cancion) %>%
  forma_comun(ka, kc)
consolidada <- consolidada %>%
  mutate(kc = normalizar(cancion)) %>%
  left_join(canciones, by = c("ka", "kc")) %>%
  mutate(cancion = comun) %>%
  select(-comun, -ka, -kc)
unificados <- consolidada %>%
  filter(artista != artista_original) %>%
  distinct(artista_original, artista)
consolidada <- select(consolidada, -artista_original)
guardar_parquet(consolidada, salida)

## 5.2 Duración de cada canción ------
#### percentil 90 de lo escuchado en Spotify: casi siempre la canción completa
duraciones <- leer_spotify(zip_spotify, zona = "UTC") %>%
  filter(cuenta) %>%
  llaves() %>%
  left_join(select(alias, ka = ka_sp, ka_lf), by = "ka") %>%
  mutate(ka = coalesce(ka_lf, ka)) %>%
  group_by(ka, kc) %>%
  summarise(minutos = quantile(minutos, 0.9), .groups = "drop") %>%
  inner_join(
    consolidada %>% distinct(artista, cancion) %>% llaves()
    ,by = c("ka", "kc")
  ) %>%
  distinct(artista, cancion, .keep_all = TRUE) %>%
  select(artista, cancion, minutos)
guardar_parquet(duraciones, "data/duraciones.parquet")

# 6. Resumen ------
cat("Spotify (30 s o más):", nrow(spotify), "| con pareja en Last.fm:", nrow(pares)
    ,"| sumadas:", nrow(nuevas), "| descartadas (Last.fm registró algo a esa hora):", sum(!sin_pareja$hueco), "\n")
cat("Alias de artistas:", if (nrow(alias)) paste(alias$ka_sp, "->", alias$ka_lf, collapse = "; ") else "ninguno", "\n")
cat("Base consolidada:", nrow(consolidada), "escuchas (Last.fm:", nrow(lastfm), ")\n")
cat("Duraciones reales:", nrow(duraciones), "canciones | mediana", round(median(duraciones$minutos), 2), "min\n")
cat("Artistas unificados:", nrow(unificados), "variantes |"
    ,paste(head(paste(unificados$artista_original, "->", unificados$artista), 15), collapse = "; "), "\n")
consolidada %>%
  filter(uts >= min(spotify$uts)) %>%
  count(mes = format(fecha_utc, "%Y-%m"), fuente) %>%
  pivot_wider(names_from = fuente, values_from = n, values_fill = 0) %>%
  as.data.frame() %>%
  print()
