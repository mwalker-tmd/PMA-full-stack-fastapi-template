# Documentation

Everything you need to run, understand, change and deploy this application. If you're new, follow **[Start Here](#start-here)** in order. Otherwise, jump to the guide for what you're doing.

## Start Here

For a new bootcamp student or intern, this order takes you from a clean machine to a running app, and then to your first contribution:

1. **[Getting Started](./getting-started.md):** install Docker, uv and Bun, create your `.env`, start the stack, and log in at <http://localhost:8000>. When you're done, the application is running.
2. **[Architecture](../ARCHITECTURE.md):** what each service does, how a request flows through FastAPI, and where everything lives in the repository.
3. **[Contributing](./contributing.md):** the everyday workflow: branches, making changes, tests, commits and pull requests.
4. **[Troubleshooting](./troubleshooting.md):** bookmark it. Search it for the exact error message you see.

## All Guides

### Run and develop

| Guide | What's in it |
|---|---|
| [Getting Started](./getting-started.md) | The stack's services, prerequisites, a quick start, the step-by-step first run (env files, secrets, database, login), everyday Docker commands, development tool setup, and common first-run problems |
| [Development](../development.md) | Running the FastAPI and Vite dev servers on your machine, the full stack with `docker compose watch`, Mailpit, the Compose files, the `.env` files, and pre-commit hooks |
| [Contributing](./contributing.md) | Complete environment setup, then issues, `<type>/<short-name>` branches, what else to update when you change models, the API, email templates or settings, tests, commits, pull requests, review, code style and using AI tools |
| [Troubleshooting](./troubleshooting.md) | Problems with configuration, Docker, the database, the backend, login, email, the frontend and tooling, each listed under its exact error message with cause and fix, plus how to start over |
| [Backend README](../backend/README.md) | Backend workflow, tests, Alembic migrations and React Email templates |
| [Frontend README](../frontend/README.md) | Frontend dev server, regenerating the API client, using a remote API, code structure and Playwright tests |

### Understand the system

| Guide | What's in it |
|---|---|
| [Architecture](../ARCHITECTURE.md) | Service topology, how one FastAPI process serves the API, docs and frontend, backend and frontend structure, authentication (JWT, Argon2), the email pipeline, configuration, deployment options and the repository layout |
| [Diagrams](./diagrams.md) | Database schema, login and password-reset sequences, Compose service dependencies, CI/CD flows, both deployment setups and the development workflow (Mermaid) |

### Automate and deploy

| Guide | What's in it |
|---|---|
| [CI/CD](./ci-cd.md) | Every GitHub Actions workflow and when it runs, why CI needs no secrets, the generated API client, Dependabot, running CI locally, and what to do when a check fails |
| [GitHub Secrets and Variables](./github-secrets-setup.md) | The secrets and variables each deploy workflow needs (none for CI), Secrets vs Variables, generating and setting values, and optional Environment protection |
| [Deployment Checklist](./deployment-checklist.md) | Tick-box checklists for your computer, FastAPI Cloud and a self-hosted server with a GitHub Actions runner, including verification, security, backups, updates and rollback |
| [Deploy to FastAPI Cloud](../deployment.md) | Step-by-step FastAPI Cloud setup: the default deployment |
| [Deploy with Docker Compose](../deployment-docker-compose.md) | Step-by-step self-hosted setup: Traefik with HTTPS, and the self-hosted runner |

## Paths by Goal

**I want to deploy.** Read the [Deployment Checklist](./deployment-checklist.md) to choose between FastAPI Cloud and your own server. Then follow [deployment.md](../deployment.md) or [deployment-docker-compose.md](../deployment-docker-compose.md), with [GitHub Secrets and Variables](./github-secrets-setup.md) open alongside.

**A CI check failed on my pull request.** See [When CI Fails](./ci-cd.md#when-ci-fails), then [Troubleshooting](./troubleshooting.md).

**I'm changing the database models.** See [Database migrations](./contributing.md#database-migrations).

**I'm changing an email.** See [Email](../ARCHITECTURE.md#email), then [Email Templates](../backend/README.md#email-templates).

## Quick Reference

Run these from the project root.

| Task | Command |
|---|---|
| Prepare the database (first run, or after `down -v`) | `docker compose run --rm backend bash scripts/prestart.sh` |
| Start the app | `docker compose up -d --wait proxy db adminer backend mailpit` |
| Start with live reload | `docker compose watch` |
| Service status / logs | `docker compose ps` / `docker compose logs -f backend` |
| Stop (keep data) / reset (delete data) | `docker compose down` / `docker compose down -v` |
| Run the code checks | `uv run prek run --all-files` |
| Run CI's checks on your last commit | `bash scripts/test-ci-docker.sh` (add `--playwright` for end-to-end) |
| Regenerate the API client | `bash scripts/generate-client.sh` |
| Create a migration | `cd backend && uv run alembic revision --autogenerate -m "describe the change"` |
| Database shell | `docker compose exec db psql -U postgres -d app` |

| Service | URL |
|---|---|
| The app | <http://localhost:8000> |
| API docs | <http://localhost:8000/docs> |
| Adminer (database UI) | <http://localhost:8080> |
| Mailpit (caught emails) | <http://localhost:8025> |
| Traefik dashboard | <http://localhost:8090> |

## Improving the Docs

Found something wrong or unclear? Fix it in a pull request, following [Contributing](./contributing.md). If you add a guide to `docs/`, add it to this index too.
