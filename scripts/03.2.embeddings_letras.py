# Embeddings multilingües de las letras (único paso en Python del proyecto).
# Convierte cada letra en un vector de significado con un modelo que entiende
# más de 50 idiomas, para que "amor" y "love" queden cerca. El resto del
# modelo de temas (UMAP, HDBSCAN y palabras de cada tema) se hace en R.
#
# Entrada:  data/letras.parquet
# Salida:   data/embeddings_letras.parquet (artista, cancion, e1..e384)
# Incremental: solo procesa las letras que aún no tienen vector.
# Uso: .venv/Scripts/python.exe scripts/03.2.embeddings_letras.py

import os
import numpy as np
import pandas as pd
from sentence_transformers import SentenceTransformer

MODELO = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
ENTRADA = "data/letras.parquet"
SALIDA = "data/embeddings_letras.parquet"
PALABRAS_POR_TROZO = 120   # el modelo lee hasta ~128 piezas; se trocea la letra
MAX_TROZOS = 6


# 1. Letras pendientes ------
letras = pd.read_parquet(ENTRADA)
letras = letras[letras["letra"].notna()][["artista", "cancion", "letra"]]
previas = pd.read_parquet(SALIDA) if os.path.exists(SALIDA) else None
if previas is not None:
    hechas = set(zip(previas["artista"], previas["cancion"]))
    letras = letras[[(a, c) not in hechas for a, c in zip(letras["artista"], letras["cancion"])]]
print(f"Letras por procesar: {len(letras)}", flush=True)
if len(letras) == 0:
    raise SystemExit(0)


# 2. Trozos de cada letra ------
# el vector de la canción es el promedio de sus trozos
def trozos(texto):
    palabras = texto.split()
    partes = [" ".join(palabras[i:i + PALABRAS_POR_TROZO])
              for i in range(0, len(palabras), PALABRAS_POR_TROZO)]
    return partes[:MAX_TROZOS] or [texto]


partes = [trozos(t) for t in letras["letra"]]
planos = [p for ps in partes for p in ps]
cuantos = [len(ps) for ps in partes]


# 3. Embeddings ------
modelo = SentenceTransformer(MODELO, device="cpu")
vectores = modelo.encode(planos, batch_size=64, show_progress_bar=True,
                         normalize_embeddings=True, convert_to_numpy=True)
cortes = np.cumsum([0] + cuantos)
por_cancion = np.vstack([vectores[cortes[i]:cortes[i + 1]].mean(axis=0)
                         for i in range(len(cuantos))])
por_cancion /= np.linalg.norm(por_cancion, axis=1, keepdims=True)


# 4. Guardado (temporal y luego reemplazo, como en R/datos.R) ------
nuevas = pd.concat([
    letras[["artista", "cancion"]].reset_index(drop=True),
    pd.DataFrame(por_cancion.astype("float32"),
                 columns=[f"e{i + 1}" for i in range(por_cancion.shape[1])]),
], axis=1)
total = pd.concat([previas, nuevas], ignore_index=True) if previas is not None else nuevas
total.to_parquet(SALIDA + ".tmp", index=False)
os.replace(SALIDA + ".tmp", SALIDA)
print(f"Listo: {len(total)} letras con embedding", flush=True)
