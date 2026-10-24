# Fuentes

Maestro de fuentes del proyecto: de dónde salen los datos y en qué se basan los análisis.
Se actualiza cada vez que se agrega una fuente nueva.

## Datos

| Fuente | Qué se obtiene | Dónde se usa |
|---|---|---|
| [API de Last.fm](https://www.last.fm/api) — `user.getRecentTracks` | Historial completo de escuchas (fecha, artista, canción, álbum) | `descargar_escuchas.R` → `data/escuchas.parquet` |
| [API de Last.fm](https://www.last.fm/api) — `artist.getTopTags` | Hasta 30 etiquetas por artista, con su peso (géneros, países, ánimo) | `descargar_tags.R` → `data/tags_artistas.parquet` |
| [API de Last.fm](https://www.last.fm/api) — `artist.getInfo` | Oyentes y reproducciones globales de cada artista | `descargar_tags.R` → `data/info_artistas.parquet` |
| [API pública de Deezer](https://developers.deezer.com/api) — `search/artist`, `search/album` | Fotos de artistas y portadas de discos (solo coincidencias exactas de nombre) | `R/imagenes.R` → `data/imagenes/` |
| Historial ampliado de Spotify (*pendiente*) | Cada reproducción con milisegundos escuchados y saltos | Base consolidada con Last.fm (por hacer) |

## Marcos de análisis

| Fuente | Qué se toma | Dónde se usa |
|---|---|---|
| [Personalidades de oyente de Spotify Wrapped 2022](https://www.aol.com/16-personality-types-spotify-wrapped-195652285.html) ([otra reseña](https://says.com/my/entertainment/spotify-wrapped-2022-16-personalities)) | Idea de describir al oyente con pares de rasgos (familiaridad/exploración, lealtad/variedad, común/único) | Sección "Mi personalidad de oyente" |
| [Tourmaline](https://next.tangled.org/ewancroft.uk/tourmaline) | Idea de un índice de nicho según la popularidad del artista | Sección "¿Qué tan de nicho es lo que escucho?" |
| [Puntaje de eclecticismo en Last.fm](https://www.spudart.org/blog/what-is-your-eclectic-score/amp/) | Idea de medir diversidad del gusto | Tabla "Diversidad por año" |
| Rentfrow, Goldberg y Levitin (2011); [Kosinski y otros (2012), replicación del modelo MUSIC](https://www.gsb.stanford.edu/index%2Ephp/node/428616) | Cinco dimensiones de preferencia musical: Mellow, Unpretentious, Sophisticated, Intense, Contemporary | Sección "Mis gustos según el modelo MUSIC" |
| [Russell (1980), modelo circunflejo del afecto](https://doi.org/10.1037/h0077714) | Ubicar emociones en dos ejes: valencia y activación (energía) | Sección "Mi ánimo musical" |
| Rentfrow y Gosling (2003), *The do re mi's of everyday life*, Journal of Personality and Social Psychology | Relación entre dimensiones de preferencia musical y rasgos de personalidad | Sección "Lectura psicológica" |
| North (2008), estudio de Heriot-Watt University sobre gusto musical y personalidad | Rasgos asociados a fans de metal y de música clásica | Sección "Lectura psicológica" |
| Vuoskoski, Thompson, McIlwain y Eerola (2012), *Who enjoys listening to sad music and why?*, Music Perception | Quienes disfrutan la música triste puntúan más alto en empatía y apertura | Sección "Lectura psicológica" |
| Sharman y Dingle (2015), *Extreme metal music and anger processing*, Frontiers in Human Neuroscience | Escuchar música extrema tras enojarse ayuda a regular la rabia | Sección "Lectura psicológica" |
| Encuesta de Deezer (2018) sobre la edad en que se deja de descubrir música | En promedio, alrededor de los 30 años | Sección "Lectura psicológica" |

| Bourdieu (1979), *La distinción* | El gusto como marca social y el análisis de correspondencias como "espacio de los gustos" | Laboratorio: "El espacio de mis gustos" |
| Peterson (1992); Peterson y Kern (1996), *Changing highbrow taste: from snob to omnivore*, American Sociological Review | El omnívoro cultural como nuevo signo de distinción | Pestaña "¿Soy omnívoro?" |
| DeNora (2000), *Music in Everyday Life* | La música como "tecnología del yo" para regular el ánimo en la vida cotidiana | Sección "Mi ritmo" |
| Zajonc (1968), efecto de mera exposición; Berlyne (1971), *Aesthetics and Psychobiology* | Repetición y gusto, curva en U invertida | Pestaña "En loop" |
| Krumhansl y Zupnick (2013), *Cascading reminiscence bumps in popular music*, Psychological Science | Pico de reminiscencia musical | Pestaña "Ranking año a año" |
| Grimm (1987), *CONISS: a FORTRAN 77 program for stratigraphically constrained cluster analysis*, Computers & Geosciences | Clustering jerárquico con restricción de contigüidad (Ward) | Sección "Mis eras musicales" |
| Blei, Ng y Jordan (2003), *Latent Dirichlet Allocation*, Journal of Machine Learning Research | Modelo de tópicos | Laboratorio: "Playlists ocultas" y tópicos de las letras |
| Shannon (1948); número efectivo de categorías (exponencial de la entropía) | Medida de diversidad de géneros | Pestaña "¿Soy omnívoro?" |
| Hothorn, Hornik y Zeileis (2006), *Unbiased Recursive Partitioning: A Conditional Inference Framework*, Journal of Computational and Graphical Statistics (`partykit`) | Árbol de inferencia condicional | Laboratorio: "¿Puede una máquina adivinar cuándo escucho?" |
| Venables y Ripley (2002), *Modern Applied Statistics with S* (`nnet`) | Regresión logística multinomial | Laboratorio: "¿Puede una máquina adivinar cuándo escucho?" |
| Breiman (2001), *Random Forests*, Machine Learning; Wright y Ziegler (2017), *ranger*, Journal of Statistical Software | Random forest | Laboratorio: "¿Puede una máquina adivinar cuándo escucho?" |
| Friedman (2001), *Greedy Function Approximation: A Gradient Boosting Machine*, Annals of Statistics; Chen y Guestrin (2016), *XGBoost* | Gradient boosting | Laboratorio: "¿Puede una máquina adivinar cuándo escucho?" |
| [LRCLIB](https://lrclib.net) | Letras de las canciones más escuchadas (solo análisis local; el reporte muestra palabras y tópicos agregados) | `descargar_letras.R` → `data/letras.parquet` |

## Contexto

| Fuente | Qué se toma | Dónde se usa |
|---|---|---|
| Estado de excepción constitucional de catástrofe en Chile (18-03-2020 al 30-09-2021) | Fechas del período "pandemia" | Sección "Antes, durante y después de la pandemia" |

## Decisiones propias (no vienen de una fuente)

- Umbrales de la personalidad de oyente (15% artistas nuevos, 30% top 10, 3 escuchas por canción, 1 millón de oyentes).
- Diccionarios que asignan etiquetas a países, a dimensiones MUSIC y a valencia/energía.
- Duración promedio de 3,5 minutos por canción para estimar horas.
- Número de eras (k = 5) en el análisis de clusters.
- Cobertura: etiquetas y oyentes de todos los artistas (tope de 5.000; 3.271 al 24-10-2026) y letras de las 8.000 canciones más escuchadas.
- Tope de 30 s por consulta a LRCLIB, con reintento: sin él, una conexión que el servidor dejó abierta congeló la descarga (24-10-2026).

## Portada (`docs/index.html`)

| Fuente | Qué se toma | Dónde se usa |
|---|---|---|
| `proyecto_cv/datos/cv.yml` (mi CV) | Perfil breve y enlace a LinkedIn (sin teléfono ni correo, porque la página es pública) | Sección «Sobre mí» |
| Foto propia de Ciro (`ciro_tatu1.jpg`) | Imagen de la portada | `docs/img/ciro.jpg` |
| Ilustraciones de Ciro (stickers generados con IA a partir de fotos propias; originales en `input/ciro_ilustraciones/`, prompt en `input/prompt_ciro.md`) | Mascota: natural, metalero, post-punk, rapero, encuestador y con café y camisa hawaiana. Fondo quitado y azules pasados a verde con `scripts/ciro_sin_fondo.py` | `assets/ciro/` (saludos y secciones de los reportes) y `docs/img/` (portada) |
| Skill de visualización de datos (dataviz) de Claude Code | Validación de la paleta para daltonismo y contraste; separación blanca de 1,5 px entre barras | `R/visual.R` (`interactivo()`) |

## Diseño y accesibilidad

| Fuente | Qué se toma | Dónde se usa |
|---|---|---|
| W3C, [WCAG 2.2](https://www.w3.org/TR/WCAG22/), aprobada como norma [ISO/IEC 40500:2025](https://www.w3.org/WAI/news/2025-10-21/wcag22-iso) | Nivel AA: contraste de texto 4,5:1 y de controles 3:1 (1.4.3, 1.4.11), texto alternativo en imágenes (1.1.1), reflujo sin deslizar de lado a 320 px (1.4.10), saltar al contenido (2.4.1), foco no tapado (2.4.11), controles de al menos 24×24 px (2.5.8), idioma de la página (3.1.1) | `assets/estilo.css`, `assets/saltar.html`, `R/visual.R`, portada y los tres reportes |
| Guía de herramientas (`GUIA_HERRAMIENTAS.html`, local) | Herramientas y criterios del flujo de render: /dataviz, verificación de cifras antes de publicar, revisión de código, revisar en el navegador | Todo el flujo (ver `FLUJO_DE_TRABAJO.txt`) |
