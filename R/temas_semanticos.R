# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,uwot
)

# 1. Temas por significado (al estilo BERTopic) ------
#### los embeddings vienen de scripts/03.2.embeddings_letras.py (único paso en Python)
#### UMAP reduce a 5 dimensiones, k-means agrupa y cada letra va al tema más cercano

## 1.1 Agrupación ------
#### UMAP a 5 dimensiones y k-means con n_temas grupos. Con letras de canciones HDBSCAN
#### dejaba entre 60% y 70% de letras sin grupo o lo juntaba todo en dos, ya que los
#### significados forman un continuo; k-means es la alternativa que propone BERTopic
agrupar_embeddings <- function(matriz, n_temas = 10, vecinos = 15) {
  set.seed(2026)
  reductor <- umap(matriz, n_neighbors = vecinos, n_components = 5, min_dist = 0, metric = "cosine"
                   ,ret_model = TRUE, n_threads = 1, verbose = FALSE)
  grupos <- kmeans(reductor$embedding, centers = n_temas, nstart = 25, iter.max = 100)
  list(reductor = reductor, centroides = grupos$centers
       ,separacion = grupos$betweenss / grupos$totss)
}

## 1.2 Tema de cada letra ------
#### el más cercano en el espacio reducido (también para las letras sueltas y las nuevas)
asignar_tema <- function(modelo, reducido) {
  distancias <- map(seq_len(nrow(modelo$centroides)), function(j)
    rowSums(sweep(reducido, 2, modelo$centroides[j, ])^2)) %>%
    do.call(cbind, .)
  tema <- max.col(-distancias, ties.method = "first")
  #### cercanía al centro del tema (1 = en el centro): sirve para elegir el ejemplo más representativo
  tibble(tema, cercania = 1 / (1 + sqrt(distancias[cbind(seq_along(tema), tema)])))
}

## 1.3 Modelo estable ------
#### igual que lda_estable(): se reentrena si lo nuevo supera el umbral o con REENTRENAR_MODELOS=1
temas_estables <- function(embeddings, archivo, umbral = 0.15) {
  ids <- paste(embeddings$artista, embeddings$cancion, sep = " — ")
  matriz <- as.matrix(select(embeddings, starts_with("e")))
  #### el reductor UMAP se guarda aparte con save_uwot(): con saveRDS() pierde su índice de
  #### vecinos y umap_transform() falla al reutilizarlo ("external pointer is not valid")
  archivo_umap <- sub("\\.rds$", ".uwot", archivo)
  previo <- if (file.exists(archivo) && file.exists(archivo_umap)) readRDS(archivo)
  if (!is.null(previo)) previo$reductor <- load_uwot(archivo_umap)
  entrenar <- is.null(previo) || Sys.getenv("REENTRENAR_MODELOS") == "1" ||
    mean(!ids %in% previo$ids) > umbral
  modelo <- if (entrenar) {
    m <- agrupar_embeddings(matriz)
    m$ids <- ids
    save_uwot(m$reductor, archivo_umap)
    saveRDS(m, archivo)
    message("Temas semánticos entrenados y guardados: ", archivo)
    m
  } else {
    message("Temas semánticos reutilizados (", archivo, "): ", sum(!ids %in% previo$ids), " letras nuevas clasificadas")
    previo
  }
  reducido <- umap_transform(matriz, modelo$reductor, n_threads = 4)
  list(modelo = modelo, asignacion = bind_cols(tibble(cancion_id = ids, peso = 1), asignar_tema(modelo, reducido)))
}

# 2. Palabras de cada tema (c-TF-IDF) ------
#### frecuencia de la palabra en el tema × rareza entre temas (Grootendorst, 2022)
palabras_tema <- function(tokens, asignacion, n = 15) {
  conteo <- tokens %>%
    inner_join(select(asignacion, cancion_id, tema), by = "cancion_id") %>%
    count(tema, palabra)
  promedio <- conteo %>% group_by(tema) %>% summarise(total = sum(n)) %>% pull(total) %>% mean()
  conteo %>%
    group_by(palabra) %>% mutate(f_total = sum(n)) %>%
    group_by(tema) %>% mutate(tf = n / sum(n)) %>%
    ungroup() %>%
    filter(f_total >= 10) %>%
    mutate(ctfidf = tf * log(1 + promedio / f_total)) %>%
    group_by(tema) %>%
    slice_max(ctfidf, n = n, with_ties = FALSE) %>%
    summarise(terminos = list(palabra), .groups = "drop") %>%
    arrange(tema)
}
