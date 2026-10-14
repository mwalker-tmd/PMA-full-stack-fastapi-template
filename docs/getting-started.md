# Getting Started

This guide takes you from a clean machine to the full application running locally, with a login that works. It assumes no prior experience with this stack.

You'll end up with:

* The web app at <http://localhost:8000>, served by FastAPI
* Interactive API docs at <http://localhost:8000/docs>
* A PostgreSQL database, a database admin UI, and a mail catcher for the emails the app sends

## What's in the Stack

Everything runs in Docker, so the only thing you need to *run* the app is Docker.

| Service | What it is | URL |
|---|---|---|
| `backend` | FastAPI on Python 3.14. Serves the API **and** the built React frontend. | <http://localhost:8000> |
| `db` | PostgreSQL | `localhost:5432` |
| `adminer` | Web UI for browsing the database | <http://localhost:8080> |
| `mailpit` | Catches emails, such as password resets, instead of sending them | <http://localhost:8025> |
| `proxy` | Traefik reverse proxy, the same routing used in deployments | <http://localhost> (dashboard: <http://localhost:8090>) |
| `playwright` | Helper for running the end-to-end tests. Not a long-running service. | |

The frontend is built with [Bun](https://bun.sh/) inside the `backend` image, so there is no separate frontend server to start. Passwords are hashed with Argon2 (via `pwdlib`).

## Prerequisites

### To run the app

* [Git](https://git-scm.com/downloads)
* [Docker Desktop](https://www.docker.com/products/docker-desktop/) (macOS, Windows), or Docker Engine with the Compose plugin (Linux)

On Windows, run the commands in this guide in [WSL](https://learn.microsoft.com/windows/wsl/install) or Git Bash.

### To develop: write code, commit, run tests

You also need these. Install them before your first commit, even if you only work on the backend:

* [uv](https://docs.astral.sh/uv/getting-started/installation/), which manages Python. It downloads Python 3.14 automatically; you don't need to install Python yourself.
* [Bun](https://bun.sh/docs/installation), which manages the frontend. The pre-commit hooks use it to lint the frontend and to regenerate the frontend API client whenever backend code changes, so **every** developer needs it.

Check what you have:

```bash
git --version
docker compose version
uv --version
bun --version
```

## Quick Start

If you've done this before, these are all the steps. Each is explained below.

```bash
git clone https://github.com/<your-account>/<your-repo>.git
cd <your-repo>
cp .env.example .env
cp frontend/.env.example frontend/.env
# Edit .env: set SECRET_KEY, FIRST_SUPERUSER_PASSWORD and POSTGRES_PASSWORD
# to values from: openssl rand -hex 32
docker compose run --rm backend bash scripts/prestart.sh
docker compose up -d --wait proxy db adminer backend mailpit
```

Then open <http://localhost:8000> and log in.

## Step by Step

### 1. Get the code

If you haven't yet, create your own repository from the template: click **Use this template** on the GitHub page. Then clone it:

```bash
git clone https://github.com/<your-account>/<your-repo>.git
cd <your-repo>
```

All the commands below run from this project root folder.

### 2. Create your environment files

Settings live in `.env` files, which are never committed because they hold passwords. The repository tracks templates for them, ending in `.example`. Copy them:

```bash
cp .env.example .env
cp frontend/.env.example frontend/.env
```

### 3. Set your secrets

`.env` ships with `changethis` placeholders. Replace three of them with random values. Run this once per value and copy each result:

```bash
openssl rand -hex 32
```

Open `.env` in your editor and set:

| Variable | What it's for |
|---|---|
| `SECRET_KEY` | Signs login tokens. Required, with no default. |
| `FIRST_SUPERUSER_PASSWORD` | Password of the admin account you'll log in with |
| `POSTGRES_PASSWORD` | Database password |

Optionally, also change `FIRST_SUPERUSER` (the admin's email, `admin@example.com` by default) and `PROJECT_NAME`.

Use `openssl rand -hex 32` rather than typing your own passwords. Its output contains only letters and digits, so it is safe inside the database connection URL. Characters such as `@`, `/` or `:` in `POSTGRES_PASSWORD` would break that URL.

Every other variable in `.env` is optional and already set for local development. Each one is explained by a comment in `.env.example`.

### 4. Prepare the database

```bash
docker compose run --rm backend bash scripts/prestart.sh
```

This builds the Docker images, starts PostgreSQL, applies the database migrations, and creates your admin account. The **first run takes several minutes** while Docker downloads and builds images. Later runs take seconds.

It's done when you see `Initial data created`.

### 5. Start the application

```bash
docker compose up -d --wait proxy db adminer backend mailpit
```

`-d` runs everything in the background. `--wait` returns once the services are healthy. Check them with:

```bash
docker compose ps
```

`backend`, `db` and `mailpit` should show `(healthy)`.

> **Why list the services?** A bare `docker compose up -d --wait` also starts the `playwright` test helper, which exits immediately. Compose then reports `container ... playwright-1 exited (0)` and returns an error, even though the app is running fine.

### 6. Open the app and log in

| What | URL |
|---|---|
| The app | <http://localhost:8000> |
| API docs (Swagger UI) | <http://localhost:8000/docs> |
| Database admin (Adminer) | <http://localhost:8080> |
| Emails sent by the app (Mailpit) | <http://localhost:8025> |
| Traefik dashboard | <http://localhost:8090> |

Log in to the app with the `FIRST_SUPERUSER` email and the `FIRST_SUPERUSER_PASSWORD` you set in step 3.

To see email working, log out, click **Forgot your password?**, and enter the admin email. The reset email shows up in Mailpit.

In Adminer, use **System** `PostgreSQL`, **Server** `db`, **Username** `postgres`, **Password** your `POSTGRES_PASSWORD`, and **Database** `app`.

## Everyday Commands

**Live reload while you code.** Watch mode syncs your changes into the running containers and restarts or rebuilds as needed. It runs in the foreground; stop it with `Ctrl+C`:

```bash
docker compose watch
```

**See logs:**

```bash
docker compose logs backend      # one service
docker compose logs -f backend   # follow live, Ctrl+C to stop
```

**Stop the app.** Your data is kept:

```bash
docker compose down
```

Start it again with step 5.

**Start over with an empty database.** This deletes all data:

```bash
docker compose down -v
```

Then repeat steps 4 and 5. Do this after changing `POSTGRES_PASSWORD`, because the existing database keeps the password it was created with.

## Set Up Your Development Tools

Do this once before you write code. It needs uv and Bun (see [Prerequisites](#prerequisites)).

```bash
uv sync                    # Python dependencies, installs Python 3.14 if needed
bun install                # frontend dependencies
uv run prek install -f     # run the code checks automatically on every commit
```

`uv sync` also activates the FastAPI and SQLModel guides for AI coding assistants, which are linked from `.claude/skills/` and `.agents/skills/`.

From here:

* **Run the backend and frontend dev servers on your machine**, for the fastest feedback: see [development.md](../development.md#local-development)
* **Run the same checks CI runs, before you push:** `bash scripts/test-ci-docker.sh` (add `--playwright` for the end-to-end tests)
* **Run the code checks on everything:** `uv run prek run --all-files`

## Common First-Run Problems

**`required variable SECRET_KEY is missing a value`** (or `POSTGRES_PASSWORD`, `PROJECT_NAME`...)
You skipped step 2, or ran the command outside the project root. `.env` must exist next to `compose.yml`.

**`port is already allocated`** or **`address already in use`**
Something else is using one of the ports (80, 5432, 8000, 8025, 8080, 8090). Find it with `lsof -nP -iTCP:8000 -sTCP:LISTEN` (swap in the port number). It's often another project's Docker containers, or this project's own stack started from a different folder.

**`FATAL: database "app" does not exist`** when running backend commands on your machine
A local PostgreSQL (Postgres.app, Homebrew `postgresql`) is answering on `localhost:5432` instead of the Docker database. Docker doesn't report a port conflict in this case; the local server silently wins. Check with `lsof -nP -iTCP:5432 -sTCP:LISTEN`, stop it (quit Postgres.app, or `brew services stop postgresql@<version>`), and try again.

**`The value of SECRET_KEY is "changethis"`**
A placeholder is still in `.env`. Locally that's only a warning, but deployments refuse to start. Go back to step 3.

**`Cannot connect to the Docker daemon`**
Docker isn't running. Start Docker Desktop and wait until it reports that it's running.

**Login fails with the right password after you changed `.env`**
The admin account is created only once, when the database is first prepared. To apply new `FIRST_SUPERUSER` or `FIRST_SUPERUSER_PASSWORD` values, start over with `docker compose down -v` and repeat steps 4 and 5.

## Where Next

* [development.md](../development.md): local dev servers, Docker Compose files, `.env` details, pre-commit hooks
* [backend/README.md](../backend/README.md) and [frontend/README.md](../frontend/README.md): working on each half of the app
* [deployment.md](../deployment.md): deploy to FastAPI Cloud, the default
* [deployment-docker-compose.md](../deployment-docker-compose.md): deploy to your own server
