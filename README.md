# Mission 05 — Mets le détecteur de fraude en boîte

**Compte une heure trente.** Prérequis : les missions 01 et 02.

Les quatre missions précédentes emballaient des programmes qu'on t'avait
donnés. Celle-ci emballe **le tien** : le détecteur de fraude, son modèle
entraîné et l'API qui le sert.

Le scénario est celui de lundi matin. Un collègue clone ce dossier. Il n'a pas
Python, pas de scikit-learn, pas ton environnement virtuel. Il ne lira aucune
documentation. **Le système doit être debout.**

Tu n'écris pas une ligne de Python aujourd'hui. Tu écris ce qui l'emballe.

## Le point de départ

Tout ce qui appartient au modèle est déjà là.

| Déjà là | Absent |
|---|---|
| `api.py` — l'API, trois guichets, sert le modèle | rien ne décrit une **image** |
| `model.pkl` — le modèle entraîné (1,1 Mo) | rien ne décrit le **système** |
| `train.py` — de quoi le réentraîner | rien ne dit ce qui **ne doit pas** entrer dans l'image |
| `fraud_example.json`, `normal_example.json` — deux vraies transactions | les dépendances n'ont **aucune version** |

Les quatre fichiers que tu dois écrire sont dans ce dossier, **troués de tout
ce qui t'appartient** : `requirements.txt`, `Dockerfile`, `.dockerignore`,
`docker-compose.yml`. Chaque trou est un `___` précédé d'un `TODO` qui dit ce
qu'on attend.

**Ce qui ne doit pas exister à la fin** : un script de lancement, une notice
d'installation. *Si tu as besoin d'expliquer comment démarrer, c'est raté.*

Le nom de l'image attendu, partout : **`fraud-api:1.0`**.

> **Cette mission emballe la version anglaise du projet.** Les guichets
> répondent `{"fraud": true, "fraud_probability": 0.55}`, et les exemples
> s'appellent `fraud_example.json`. Le dossier `bloc1_2/` du dépôt porte la même
> API en français (`fraude`, `probabilite_fraude`, `exemple_fraude.json`) : si tu
> pars de celui-là, le `check.sh` d'ici ne reconnaîtra pas ses réponses.

> **Le jeu de données n'est pas ici.** `data/creditcard.csv` pèse 151 Mo : il ne
> se versionne pas. Si tu as le dossier du cours sur ta machine, copie-le à côté
> de cette mission — l'étape 4 en devient nettement plus parlante. Sinon, tout
> le reste fonctionne sans lui : l'image sert un modèle **déjà entraîné**.

## Étape 1 — Lis ce que tu emballes

Rien à écrire. Cinq minutes, et elles t'évitent la panne la plus fréquente de
cette mission.

```bash
head -20 api.py
tail -5 api.py
```

Trois choses à relever, parce que chacune commande une décision plus loin :

- l'API charge `model.pkl` **au démarrage**, une seule fois — donc ce fichier
  doit être **dans l'image**, à côté de `api.py` ;
- elle n'écrit **rien** : pas de base, pas de fichier de sortie. Retiens-le,
  l'étape 7 s'en sert ;
- **sa dernière ligne** lance uvicorn sur `127.0.0.1`. Regarde-la bien. On y
  revient à l'étape 5, et c'est là que la moitié de la salle bloque.

## Étape 2 — Fige les versions

Ouvre `requirements.txt`. Il porte les cinq dépendances du projet, **sans
aucune version**, et te demande de les figer.

Ce n'est pas un rite. Un modèle enregistré par `joblib` porte la version de
scikit-learn qui l'a produit : rechargé par une autre, il avertit — et selon
l'écart, il refuse. Une image qui se reconstruit différemment dans six mois
n'est pas reproductible, et c'est tout ce qu'on lui demande.

```bash
pip freeze | grep -iE 'pandas|scikit-learn|joblib|fastapi|uvicorn'
# ou, avec uv :
uv pip freeze | grep -iE 'pandas|scikit-learn|joblib|fastapi|uvicorn'
```

Valide : `./check.sh 2`

## Étape 3 — Le Dockerfile, version simple

Ouvre le `Dockerfile`. Pour cette étape, **ignore le premier étage** (`AS
builder`) : écris une seule image, qui installe les dépendances puis copie ce
qu'il faut.

```bash
docker build -t fraud-api:1.0 .
```

Regarde la toute première ligne de la sortie :

```
=> transferring context: ...
```

Note le chiffre. Il va changer à l'étape 4.

<details>
<summary>« failed to solve: failed to read dockerfile »</summary>

Tu n'es pas dans le dossier de la mission, ou tu as laissé un `___` dans le
fichier. Docker lit la première ligne et s'arrête sur ce qu'il ne comprend pas.
</details>

Valide : `./check.sh 3`

## Étape 4 — Ce qui ne doit jamais entrer

Ouvre `.dockerignore` et complète-le. Puis reconstruis, et compare le contexte
avec celui de l'étape 3.

Si tu as copié le jeu de données à côté, l'écart est spectaculaire : **151 Mo**
partaient au démon à chaque construction, pour un fichier dont l'image n'a
aucun besoin. Le reste — l'environnement virtuel, l'historique Git, le cache de
Python — est moins gros, mais suit la même règle : ce qui n'est pas nécessaire
au service n'a rien à faire dans le contexte.

Puis mesure le cache, qui est la vraie raison d'ordonner un Dockerfile :

```bash
# change une ligne de api.py, puis :
docker build -t fraud-api:1.0 .     # regarde quelles couches sortent en CACHED

# change une ligne de requirements.txt, puis :
docker build -t fraud-api:1.0 .     # compare la durée
```

Le second est beaucoup plus long. C'est l'effet de l'ordre `COPY
requirements.txt` **avant** `COPY api.py` : le code change dix fois par jour,
les dépendances trois fois par an.

Valide : `./check.sh 4`

## Étape 5 — Fais-la répondre

```bash
docker run -d -p 8000:8000 --name fraud fraud-api:1.0
curl -s localhost:8000/
```

**Il y a de bonnes chances que rien ne réponde.** C'est prévu. Deux pannes
possibles, et savoir les distinguer est tout l'exercice :

**Le conteneur s'est arrêté** — `docker ps -a` le montre `Exited`. Lis la
raison, elle est écrite : `docker logs fraud`.

**Le conteneur tourne, et rien ne répond.** C'est la ligne que tu as lue à
l'étape 1. `127.0.0.1` veut dire « moi-même », et dans un conteneur,
« moi-même » n'est pas ta machine : c'est la boîte. Le service écoute une porte
qui ne donne sur rien.

<details>
<summary>Comment on le vérifie, plutôt que de le croire</summary>

Depuis l'intérieur du conteneur, l'API répond parfaitement :

```bash
docker exec fraud python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read())"
```

Ça marche. De l'extérieur, non. Ce n'est pas le port qui manque, c'est
l'adresse d'écoute : il faut `0.0.0.0`, qui veut dire « toutes les interfaces,
y compris celle par laquelle on entre ».
</details>

Une fois corrigé et reconstruit, la vraie preuve — une prédiction sur une
fraude réelle du jeu de données :

```bash
curl -s -X POST localhost:8000/predict \
  -H 'Content-Type: application/json' -d @fraud_example.json
# {"fraud":true,"fraud_probability":0.55}

curl -s -X POST localhost:8000/predict \
  -H 'Content-Type: application/json' -d @normal_example.json
# {"fraud":false,"fraud_probability":0.0}
```

Et la page qui rend tout ça lisible : **http://localhost:8000/docs**, où le
formulaire de `/predict` est déjà rempli avec cette fraude.

Nettoie derrière toi : `docker rm -f fraud`.

Valide : `./check.sh 5`

## Étape 6 — Deux étages

Reprends le `Dockerfile` et cette fois écris-le en entier, avec ses deux
étages. Reconstruis sous un autre tag, et compare :

```bash
docker build -t fraud-api:1.1 .
docker images fraud-api
```

L'écart entre les deux lignes, c'est ce que l'atelier de fabrication pesait :
pip, ses caches, ce qu'il a fallu pour installer et qui ne sert plus à rien une
fois installé.

<details>
<summary>Deux tailles pour la même image : laquelle compte ?</summary>

Depuis Docker 29, `docker images` affiche deux colonnes :

```
IMAGE           DISK USAGE   CONTENT SIZE
fraud-api:1.0        722MB          154MB
```

**DISK USAGE** est ce que l'image occupe chez toi, décompressée. **CONTENT
SIZE** est ce qui voyage sur le réseau, compressé — et c'est aussi ce que
renvoie `docker image inspect --format '{{.Size}}'`, ce qui surprend tout le
monde une fois.

Les deux sont vraies et ne répondent pas à la même question : la première dit
ce que coûte ton disque, la seconde ce que coûte un `docker pull`. Le critère
de cette mission porte sur la première.
</details>

Valide : `./check.sh 6`

## Étape 7 — Une seule commande

Ouvre `docker-compose.yml` et complète-le. Puis :

```bash
docker compose up -d
curl -s localhost:8000/
```

Tu viens de remplacer une ligne de commande à retenir par un fichier qui part
dans le dépôt avec le code. C'est le critère qui contient tous les autres :
**depuis un clone propre, une seule commande.**

Remarque ce que ce fichier **n'a pas** : aucun volume. Cette API ne conserve
rien — elle charge un modèle et répond. On la détruit, on la relance, elle est
identique. C'est ce qui la rend facile à déplacer et à dupliquer, et c'est une
propriété qu'on cherche, pas un manque.

```bash
docker compose down
docker compose up -d
curl -s localhost:8000/     # exactement le même service
```

Valide : `./check.sh 7`

## Terminer

Sept critères. Vrai ou faux, tu vérifies seul :

```bash
./check.sh
```

**Ça marche**

1. Depuis un clone propre, **une seule commande** met le système debout.
2. L'API répond **depuis l'extérieur**, et le modèle est chargé.
3. La **prédiction** distingue la fraude de la transaction normale.

**C'est propre**

4. Les dépendances sont **toutes figées**.
5. Le programme, dans le conteneur, **ne tourne pas en administrateur**.
6. Le jeu de données n'est **pas dans l'image**.
7. L'image pèse **moins de 900 Mo**.

> Le plafond est calé sur l'image de référence de cette mission :
> **722 Mo** mesurés le 5 août 2026, macOS arm64, Docker 29.6.1. Si
> tu es largement au-dessus, c'est l'étape 6 qu'il faut repasser — ou le
> `.dockerignore` de l'étape 4.

Puis nettoie derrière toi : `docker compose down`.

Le corrigé est dans [`../solutions/docker-05-fraud-api/`](../solutions/docker-05-fraud-api/) —
les quatre fichiers dans leur version finale, et l'explication de chaque choix.
À ouvrir **après** avoir cherché : une réponse lue avant ne laisse aucune trace.

Ce que tu viens de faire est exactement ce qu'on demande à une équipe qui met
un modèle en production : le code et le modèle voyagent ensemble, dans un objet
qu'on peut construire, peser, relire et relancer à l'identique. Tout ce que la
formation ajoute ensuite se pose **sur cette boîte**.

---

# Mission 05 — Box up the fraud detector

**Allow an hour and a half.** Requires missions 01 and 02.

The four previous missions boxed up programs that were handed to you. This one
boxes up **yours**: the fraud detector, its trained model and the API that
serves it.

The scenario is Monday morning. A colleague clones this folder. They have no
Python, no scikit-learn, none of your virtual environment. They will read no
documentation. **The system must be up.**

You are not writing a line of Python today. You are writing what wraps it.

## The starting point

Everything that belongs to the model is already here.

| Already there | Missing |
|---|---|
| `api.py` — the API, three endpoints, serves the model | nothing describes an **image** |
| `model.pkl` — the trained model (1.1 MB) | nothing describes the **system** |
| `train.py` — what it takes to retrain it | nothing says what must **never** enter the image |
| `fraud_example.json`, `normal_example.json` — two real transactions | the dependencies have **no versions** |

The four files you have to write are in this folder, **with holes where your
part belongs**: `requirements.txt`, `Dockerfile`, `.dockerignore`,
`docker-compose.yml`. Every hole is a `___` preceded by a `TODO` saying what is
expected.

**What must not exist at the end**: a launch script, an installation guide. *If
you need to explain how to start it, you have failed.*

The expected image name, everywhere: **`fraud-api:1.0`**.

> **This mission boxes up the English version of the project.** The endpoints
> answer `{"fraud": true, "fraud_probability": 0.55}`, and the examples are named
> `fraud_example.json`. The repository's `bloc1_2/` folder carries the same API in
> French (`fraude`, `probabilite_fraude`, `exemple_fraude.json`): if you start
> from that one, this folder's `check.sh` will not recognise its answers.

> **The dataset is not here.** `data/creditcard.csv` weighs 151 MB: it does not
> belong in version control. If you have the course folder on your machine, copy
> it next to this mission — it makes step 4 far more telling. Otherwise
> everything else works without it: the image serves an **already trained**
> model.

## Step 1 — Read what you are boxing up

Nothing to write. Five minutes, and they save you this mission's most common
failure.

```bash
head -20 api.py
tail -5 api.py
```

Three things to note, because each one drives a decision further down:

- the API loads `model.pkl` **at startup**, once — so that file must be
  **inside the image**, next to `api.py`;
- it writes **nothing**: no database, no output file. Remember it, step 7 uses
  that;
- **its last line** starts uvicorn on `127.0.0.1`. Look at it closely. We come
  back to it in step 5, and that is where half the room gets stuck.

## Step 2 — Pin the versions

Open `requirements.txt`. It carries the project's five dependencies, **with no
versions at all**, and asks you to pin them.

This is not a ritual. A model saved by `joblib` carries the scikit-learn
version that produced it: reloaded by another one, it warns — and depending on
the gap, it refuses. An image that rebuilds differently in six months is not
reproducible, and reproducibility is the whole point.

```bash
pip freeze | grep -iE 'pandas|scikit-learn|joblib|fastapi|uvicorn'
# or, with uv:
uv pip freeze | grep -iE 'pandas|scikit-learn|joblib|fastapi|uvicorn'
```

Check: `./check.sh 2`

## Step 3 — The Dockerfile, simple version

Open the `Dockerfile`. For this step, **ignore the first stage** (`AS
builder`): write a single image that installs the dependencies, then copies
what is needed.

```bash
docker build -t fraud-api:1.0 .
```

Look at the very first line of the output:

```
=> transferring context: ...
```

Note the number. It is about to change in step 4.

<details>
<summary>"failed to solve: failed to read dockerfile"</summary>

You are not in the mission's folder, or you left a `___` in the file. Docker
reads the first line and stops on what it cannot parse.
</details>

Check: `./check.sh 3`

## Step 4 — What must never get in

Open `.dockerignore` and fill it in. Then rebuild, and compare the context with
step 3's.

If you copied the dataset next door, the gap is spectacular: **151 MB** were
shipped to the daemon on every build, for a file the image has no use for. The
rest — the virtual environment, the Git history, Python's cache — is smaller,
but follows the same rule: whatever the service does not need has no business
in the context.

Then measure the cache, which is the real reason to order a Dockerfile:

```bash
# change a line in api.py, then:
docker build -t fraud-api:1.0 .     # watch which layers come out CACHED

# change a line in requirements.txt, then:
docker build -t fraud-api:1.0 .     # compare how long it takes
```

The second is far slower. That is the effect of `COPY requirements.txt`
**before** `COPY api.py`: code changes ten times a day, dependencies three
times a year.

Check: `./check.sh 4`

## Step 5 — Make it answer

```bash
docker run -d -p 8000:8000 --name fraud fraud-api:1.0
curl -s localhost:8000/
```

**There is a good chance nothing answers.** That is planned. Two possible
failures, and telling them apart is the whole exercise:

**The container stopped** — `docker ps -a` shows it `Exited`. Read why, it is
written down: `docker logs fraud`.

**The container runs, and nothing answers.** That is the line you read in step
1. `127.0.0.1` means "myself", and inside a container "myself" is not your
machine: it is the box. The service is listening at a door that opens onto
nothing.

<details>
<summary>How to verify it, rather than believe it</summary>

From inside the container, the API answers perfectly well:

```bash
docker exec fraud python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read())"
```

That works. From outside, it does not. What is missing is not the port, it is
the listening address: you need `0.0.0.0`, which means "every interface,
including the one people come in through".
</details>

Once fixed and rebuilt, the real proof — a prediction on a real fraud from the
dataset:

```bash
curl -s -X POST localhost:8000/predict \
  -H 'Content-Type: application/json' -d @fraud_example.json
# {"fraud":true,"fraud_probability":0.55}

curl -s -X POST localhost:8000/predict \
  -H 'Content-Type: application/json' -d @normal_example.json
# {"fraud":false,"fraud_probability":0.0}
```

And the page that makes all this readable: **http://localhost:8000/docs**,
where `/predict`'s form is already filled in with that fraud.

Clean up after yourself: `docker rm -f fraud`.

Check: `./check.sh 5`

## Step 6 — Two stages

Take the `Dockerfile` again and this time write it in full, both stages.
Rebuild under a different tag, and compare:

```bash
docker build -t fraud-api:1.1 .
docker images fraud-api
```

The gap between the two lines is what the workshop weighed: pip, its caches,
whatever was needed to install and is of no use once installed.

<details>
<summary>Two sizes for the same image: which one counts?</summary>

Since Docker 29, `docker images` shows two columns:

```
IMAGE           DISK USAGE   CONTENT SIZE
fraud-api:1.0        722MB          154MB
```

**DISK USAGE** is what the image takes up on your machine, uncompressed.
**CONTENT SIZE** is what travels over the network, compressed — and it is also
what `docker image inspect --format '{{.Size}}'` returns, which catches
everyone out once.

Both are true and they answer different questions: the first says what your
disk pays, the second what a `docker pull` pays. This mission's criterion is
about the first.
</details>

Check: `./check.sh 6`

## Step 7 — One single command

Open `docker-compose.yml` and fill it in. Then:

```bash
docker compose up -d
curl -s localhost:8000/
```

You have just replaced a command line to remember with a file that travels into
the repository alongside the code. This is the criterion that contains all the
others: **from a clean clone, one single command.**

Notice what this file does **not** have: any volume. This API keeps nothing —
it loads a model and answers. Destroy it, restart it, it is identical. That is
what makes it easy to move and to duplicate, and it is a property we look for,
not something missing.

```bash
docker compose down
docker compose up -d
curl -s localhost:8000/     # the very same service
```

Check: `./check.sh 7`

## Finishing

Seven criteria. True or false, you check them yourself:

```bash
./check.sh
```

**It works**

1. From a clean clone, **one single command** brings the system up.
2. The API answers **from the outside**, and the model is loaded.
3. The **prediction** tells the fraud from the normal transaction.

**It is clean**

4. Every dependency is **pinned**.
5. The program, inside the container, **does not run as administrator**.
6. The dataset is **not in the image**.
7. The image weighs **under 900 MB**.

> The ceiling is calibrated on this mission's reference image:
> **722 MB** measured on 5 August 2026, macOS arm64, Docker 29.6.1.
> If you are well above it, step 6 is the one to redo — or step 4's
> `.dockerignore`.

Then clean up after yourself: `docker compose down`.

The solution is in [`../solutions/docker-05-fraud-api/`](../solutions/docker-05-fraud-api/) —
the four files in their final form, and the reasoning behind every choice. Open
it **after** searching: an answer read beforehand leaves nothing behind.

What you have just done is exactly what a team shipping a model to production is
asked for: the code and the model travel together, inside an object you can
build, weigh, review and restart identically. Everything the course adds later
sits **on top of that box**.
