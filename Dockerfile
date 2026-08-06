# La recette de l'image. Deuxième livrable de la mission.
#
# Écris-la en deux temps :
#   étape 3 — une version simple, qui construit et qui tourne ;
#   étape 6 — la même, en construction à deux étages, et tu compares les tailles.
#
# La forme ci-dessous est celle de l'étape 6. Pour l'étape 3, ignore le premier
# étage et installe les dépendances directement dans l'image finale.

# ─── étage atelier ────────────────────────────────────────────────────────────
# TODO : une base Python légère, version figée. L'API demande Python 3.10 ou
#        plus ; prends une version précise, en variante « slim ».
FROM python:3.10-slim AS builder

WORKDIR /app

# TODO : les dépendances AVANT le code. Cet ordre décide de ce que Docker garde
#        en cache — l'étape 4 te le fait mesurer.
COPY requirements.txt .

# --prefix installe tout dans un seul dossier, qu'on emportera tel quel.
# Install numpy first to pin the version before pandas pulls a newer one
# Model was pickled with numpy >=1.25 (has numpy._core), so use numpy 1.26.4 (last 1.x with numpy._core)
ENV PIP_PROGRESS_BAR=off
RUN pip install --no-cache-dir --prefix=/install numpy==1.26.4
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ─── image livrée ─────────────────────────────────────────────────────────────
# TODO : la même base que l'étage atelier, sans le « AS builder ».
FROM python:3.10-slim

WORKDIR /app

# TODO : récupère le résultat de l'atelier, et lui seul. Ni pip, ni compilateur,
#        ni cache ne doivent traverser. Destination : /usr/local
COPY --from=builder /install /usr/local

# TODO : ce dont le service a besoin pour répondre. Deux fichiers, pas un de
#        plus — le reste du dossier n'a rien à faire dans une image.
COPY api.py .
COPY model.pkl .

# TODO : le programme ne doit pas tourner en administrateur. Crée un
#        utilisateur, puis bascule dessus.
RUN adduser --disabled-password --gecos "" appuser
USER appuser

# EXPOSE ne publie rien : c'est une note pour qui lit l'image. Seul le -p d'un
# docker run, ou le ports: du compose, branche vraiment un port.
EXPOSE 8000

# TODO : la commande qui démarre le service. Forme JSON.
#
# ⚠ LIS api.py AVANT D'ÉCRIRE CETTE LIGNE. Sa dernière ligne lance uvicorn sur
#   127.0.0.1 — l'adresse qui veut dire « moi-même ». Dans un conteneur,
#   « moi-même » n'est pas ta machine : c'est la boîte, et personne d'autre
#   n'y a accès. Le conteneur tournera, l'API répondra, et ton navigateur
#   n'obtiendra rien.
#
#   Appelle uvicorn directement, et dis-lui d'écouter l'extérieur. La forme :
#       uvicorn <module>:<objet> --host <adresse> --port <port>
#   Le module, c'est le nom du fichier sans .py. L'objet, c'est la variable
#   FastAPI qu'il contient.
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
