# LDA estable: el modelo se entrena una vez, se guarda y los documentos nuevos solo se
# clasifican con él. Así unas pocas canciones o semanas nuevas no reordenan los temas ni
# obligan a reescribir los textos. Se reentrena si los documentos nuevos superan el umbral
# o si se pide con REENTRENAR_MODELOS=1 (flujo_nocturno.sh --reentrenar).

library(topicmodels)

# Matriz documento-término a partir de un conteo con columnas doc, term y n
matriz_dtm <- function(conteo, terminos = sort(unique(conteo$term))) {
  conteo <- conteo[conteo$term %in% terminos, ]
  d <- factor(conteo$doc)
  t <- factor(conteo$term, levels = terminos)
  dtm <- slam::simple_triplet_matrix(as.integer(d), as.integer(t), conteo$n,
                                     nrow = nlevels(d), ncol = length(terminos),
                                     dimnames = list(levels(d), terminos))
  class(dtm) <- c("DocumentTermMatrix", class(dtm))
  attr(dtm, "weighting") <- c("term frequency", "tf")
  dtm
}

# Devuelve un modelo LDA cuyos @gamma y @documents cubren los documentos actuales
lda_estable <- function(conteo, archivo, k, burnin, iter, umbral = 0.15) {
  entrenar <- function() {
    m <- LDA(matriz_dtm(conteo), k = k, method = "Gibbs",
             control = list(seed = 2026, burnin = burnin, iter = iter))
    saveRDS(m, archivo)
    message("LDA entrenado y guardado: ", archivo)
    m
  }
  if (!file.exists(archivo) || Sys.getenv("REENTRENAR_MODELOS") == "1") return(entrenar())

  m <- readRDS(archivo)
  docs <- sort(unique(conteo$doc))
  nuevos <- setdiff(docs, m@documents)
  if (length(nuevos) / length(m@documents) > umbral) return(entrenar())

  conocidos <- m@documents %in% docs
  gamma <- m@gamma[conocidos, , drop = FALSE]
  documentos <- m@documents[conocidos]

  # Los documentos nuevos se clasifican sin tocar los temas (estimate.beta = FALSE).
  # Un documento sin ninguna palabra del vocabulario del modelo queda fuera.
  conteo_nuevo <- conteo[conteo$doc %in% nuevos & conteo$term %in% m@terms, ]
  if (nrow(conteo_nuevo) > 0) {
    inferido <- LDA(matriz_dtm(conteo_nuevo, m@terms), model = m,
                    control = list(estimate.beta = FALSE, seed = 2026, burnin = 200, iter = 300))
    gamma <- rbind(gamma, inferido@gamma)
    documentos <- c(documentos, inferido@documents)
  }
  m@gamma <- gamma
  m@documents <- documentos
  message("LDA reutilizado (", archivo, "): ", length(nuevos), " documentos nuevos clasificados")
  m
}
