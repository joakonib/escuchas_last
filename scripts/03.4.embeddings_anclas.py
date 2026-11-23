# Vectores de las "ideas ancla" para los temas guiados del reporte de letras.
# Cada idea (protesta, desamor, muerte...) se describe con varias frases en español
# e inglés; su vector es el promedio de las frases. Se usa el mismo modelo que las
# letras (03.2), así que una letra y una idea se pueden comparar por similitud.
#
# Entrada:  scripts/anclas_letras.csv (idea, frase)
# Salida:   data/embeddings_anclas.parquet (idea, e1..e384)
# Se recalcula entero en cada corrida: son pocas frases y así refleja cualquier cambio del CSV.
# Uso: .venv/Scripts/python.exe scripts/03.4.embeddings_anclas.py

import os
import numpy as np
import pandas as pd
from sentence_transformers import SentenceTransformer

MODELO = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
ENTRADA = "scripts/anclas_letras.csv"
SALIDA = "data/embeddings_anclas.parquet"


# 1. Frases ------
anclas = pd.read_csv(ENTRADA)
print(f"Ideas: {anclas['idea'].nunique()}, frases: {len(anclas)}", flush=True)


# 2. Vectores (promedio normalizado de las frases de cada idea) ------
modelo = SentenceTransformer(MODELO, device="cpu")
vectores = modelo.encode(anclas["frase"].tolist(), normalize_embeddings=True, convert_to_numpy=True)
ideas = list(dict.fromkeys(anclas["idea"]))
por_idea = np.vstack([vectores[(anclas["idea"] == i).to_numpy()].mean(axis=0) for i in ideas])
por_idea /= np.linalg.norm(por_idea, axis=1, keepdims=True)


# 3. Guardado ------
salida = pd.concat([
    pd.DataFrame({"idea": ideas}),
    pd.DataFrame(por_idea.astype("float32"), columns=[f"e{i + 1}" for i in range(por_idea.shape[1])]),
], axis=1)
salida.to_parquet(SALIDA + ".tmp", index=False)
os.replace(SALIDA + ".tmp", SALIDA)
print(f"Listo: {len(salida)} ideas con vector", flush=True)
