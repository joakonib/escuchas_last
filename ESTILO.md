# Guía de estilo de los textos

Los textos interpretativos de los reportes deben sonar como escribe Joaquín. Esta guía sale de comparar sus trabajos anteriores a 2025 (unas 25 mil palabras de tesis, tareas e informes) con los textos del reporte. `scripts/06.chequear_estilo.R` la revisa en cada corrida completa.

## Cómo escribe

- **Oraciones encadenadas**, de unas 26 palabras en la mediana, unidas con conectores en vez de frases cortas con golpe de efecto.
- **Primero la cifra y después qué significa.** "Con un 14% de mis escuchas, el post-punk...".
- **Conectores propios:** respecto a, en cuanto a, asimismo, en este sentido, por otro lado, ya que, dado que, por lo tanto, por lo cual, lo cual, cabe señalar que, cabe tener en consideración, actualmente, finalmente, a partir de, mientras que.
- **Remates con "Lo cual..." o "Por lo cual..."** como cierre de una idea.
- **Prudencia al concluir:** "indica", "da cuenta de", "se asocia a", "podría". Se señalan los límites de los datos.
- **Primera persona** en este reporte, porque es personal, sin perder ese tono.

## Referencia directa: tesis de magíster (2025)

*Aprovechamiento de paradatos en estadísticas oficiales* (UDP, 2025), en
`OneDrive - Instituto Nacional de Estadisticas\Tesis Seminario de Grado\Entrega Final UDP`.
De ahí se toman estos rasgos, que conviene imitar:

- **Describe lo hecho con "se"**: "se presentan", "se realizó", "se aprecia", "se analiza", "se calcularon".
- **Interpreta con fórmulas propias**: "es posible dar cuenta que", "esto indica que", "esto permite concluir que", "resulta importante destacar", "esto hace sentido ya que", "lo cual, en otras palabras, señala que", "lo cual se ve afectado por".
- **Encadena con**: "dicho lo anterior", "teniendo en consideración", "en primera instancia", "bajo este eje", "a continuación", "en este contexto", "por ejemplo", "es decir".
- **Cifras entre paréntesis dentro de la oración** y luego qué significan: "en al menos un 30% de las encuestas (40,5% para el CH y 32,6% en el CUT), evidenciando...".
- **Explica antes de mostrar**: abre cada sección diciendo qué se presenta y en qué orden.
- **Cierra con una reflexión prudente**, a veces con una pregunta retórica ("¿qué nos quiere decir esto?") y con lo que queda para después ("podría considerarse").

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
