# Guía de estilo de los textos

Los textos interpretativos de los reportes deben sonar como escribe Joaquín. Esta guía sale de comparar sus trabajos anteriores a 2025 (unas 25 mil palabras de tesis, tareas e informes) con los textos del reporte. `scripts/06.chequear_estilo.R` la revisa en cada corrida completa.

## Cómo escribe

- **Oraciones encadenadas**, de unas 26 palabras en la mediana, unidas con conectores en vez de frases cortas con golpe de efecto.
- **Primero la cifra y después qué significa.** "Con un 14% de mis escuchas, el post-punk...".
- **Conectores propios:** respecto a, en cuanto a, asimismo, en este sentido, por otro lado, ya que, dado que, por lo tanto, por lo cual, lo cual, cabe señalar que, cabe tener en consideración, actualmente, finalmente, a partir de, mientras que.
- **Remates con "Lo cual..." o "Por lo cual..."** como cierre de una idea.
- **Prudencia al concluir:** "indica", "da cuenta de", "se asocia a", "podría". Se señalan los límites de los datos.
- **Primera persona** en este reporte, porque es personal, sin perder ese tono.

## Qué evitar

| Evitar | Referencia |
|---|---|
| Negritas dentro de los párrafos | 0 por cada 1.000 palabras en sus textos. Solo se aceptan las etiquetas iniciales ("¿Qué me dice?", "Teoría.") y las listas |
| Dos puntos para anunciar un remate | 4 por cada 1.000 palabras en sus textos |
| Títulos ingeniosos al inicio de un párrafo | No los usa |
| Contrastes del tipo "no es X, sino Y" o "Apertura, no rabia" | Suenan a texto generado |
| Raya (—) como pausa | No la usa |
| Coloquialismos de relleno ("Ojo:", "volví con todo") | El registro es sobrio |

No se imitan los errores de tipeo ni de concordancia que aparecen en las muestras.

## Cifras

Toda cifra que dependa de los datos se calcula en el propio texto con R, para que no quede desactualizada. Solo se escriben a mano las interpretaciones y los nombres de artistas que salen de los modelos.

## Código

Sigue el estilo de `simel_eme`: `remove(list=ls())` al inicio de cada script, paquetes con `pacman::p_load`, pipe `%>%`, comas al inicio de línea, `purrr` en vez de loops `for`, títulos `# 1. Título ------` y subtítulos `## 1.1 Subtítulo ------`, y notas cortas `#### nota`. Los archivos se numeran según el orden en que corren.
