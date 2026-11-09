# Revisa que los textos interpretativos del reporte sigan la guía de ESTILO.md.
# Solo informa en el log: no detiene el flujo, porque el criterio final es de lectura.
#
# Uso: Rscript scripts/chequear_estilo.R [archivo.qmd]

library(stringr)

args <- commandArgs(trailingOnly = TRUE)
archivo <- if (length(args) > 0) args[1] else "analisis_escuchas.qmd"

lineas <- readLines(archivo, encoding = "UTF-8", warn = FALSE)
cerca <- cumsum(str_starts(lineas, "```")) %% 1 == 0 & cumsum(str_starts(lineas, "```")) %% 2 == 1
prosa <- lineas[!cerca & !str_starts(lineas, "```|:::|#|<|- |---") & str_length(lineas) > 80]
prosa <- str_remove_all(prosa, "`r [^`]*`")
prosa <- str_remove(prosa, "^\\*\\*[^*]+\\*\\* ?")

texto <- paste(prosa, collapse = " ")
palabras <- str_count(texto, "\\S+")
por_mil <- \(n) round(1000 * n / palabras, 1)

oraciones <- str_split(texto, "(?<=[.!?])\\s+")[[1]]
largo <- str_count(oraciones, "\\S+")

cat("Palabras:", palabras, "\n")
cat("Mediana de palabras por oración:", median(largo), "(referencia: 26)\n")
cat("Negritas por 1.000 palabras:", por_mil(str_count(texto, "\\*\\*") / 2), "(referencia: 0)\n")
cat("Dos puntos por 1.000 palabras:", por_mil(str_count(texto, ":")), "(referencia: 4)\n")

patrones <- c(
  "contraste no/sino" = "\\bno (es|son|fue|era) [^.,;]{1,40}, sino\\b",
  "raya como pausa" = " — ",
  "coloquialismo" = "\\b(Ojo:|con todo)",
  "título ingenioso" = "^[A-ZÁÉÍÓÚ][^.]{3,45}\\. "
)
for (nombre in names(patrones)) {
  aciertos <- prosa[str_detect(prosa, patrones[[nombre]])]
  if (nombre == "título ingenioso") aciertos <- aciertos[str_count(str_extract(aciertos, "^[^.]+"), "\\S+") <= 5]
  cat(nombre, ":", length(aciertos), "\n")
  for (a in head(aciertos, 5)) cat("   >", str_sub(a, 1, 90), "\n")
}
