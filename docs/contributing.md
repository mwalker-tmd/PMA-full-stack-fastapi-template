# Contributing

How to make a change to this project, from setting up your machine to getting a pull request merged. It's written for bootcamp students and interns working in their own repository created from this template, and for anyone contributing back to the template itself.

## 1. Set Up Your Development Environment

### Install the tools

| Tool | Why | Install |
|---|---|---|
| Git | Version control | <https://git-scm.com/downloads> |
| Docker | Runs the database and the full stack | [Docker Desktop](https://www.docker.com/products/docker-desktop/) on macOS and Windows; Docker Engine + Compose plugin on Linux |
| uv | Python and backend dependencies. Installs Python 3.14 for you. | <https://docs.astral.sh/uv/getting-started/installation/> |
| Bun | Frontend dependencies and builds. **Required for everyone**, because the commit checks use it. | <https://bun.sh/docs/installation> |

On Windows, use [WSL](https://learn.microsoft.com/windows/wsl/install). Check the installs with:

```bash
git --version && docker compose version && uv --version && bun --version
```

### Get the code and start the app

```bash
git clone https://github.com/<owner>/<repo>.git
cd <repo>

cp .env.example .env
cp frontend/.env.example frontend/.env
```

Open `.env` and replace the three `changethis` values (`SECRET_KEY`, `FIRST_SUPERUSER_PASSWORD`, `POSTGRES_PASSWORD`) with output from:

```bash
openssl rand -hex 32
```

Then start the stack:

```bash
docker compose run --rm backend bash scripts/prestart.sh     # first run takes a few minutes
docker compose up -d --wait proxy db adminer backend mailpit
```

Open <http://localhost:8000> and log in as `admin@example.com` (or your `FIRST_SUPERUSER`) with your `FIRST_SUPERUSER_PASSWORD`.

### Install the development tools

```bash
uv sync                    # Python dependencies (one virtual environment, .venv/, at the root)
bun install                # frontend and email-template dependencies
uv run prek install -f     # run the code checks automatically before every commit
```

Point your editor's Python interpreter at `.venv/bin/python`. VS Code suggests the recommended extensions when you open the folder.

You now have everything needed to change, test and commit code. For explanations of each step, see [getting-started.md](./getting-started.md); if something fails, see [troubleshooting.md](./troubleshooting.md).

## 2. Pick Up Work

* **Work from an issue.** Every change starts from a GitHub issue that says what and why. If there isn't one, open it first. For anything bigger than a small fix, agree on the approach in the issue before writing code.
* **Keep changes small.** One issue, one focused pull request. Large work is easier to review, and to undo, as a series of small PRs.
* **New dependencies** (`uv add`, `bun add`) need a reason in the issue. Every dependency is code you're trusting, and Dependabot will keep proposing updates for it.

## 3. Create a Branch

Branch from an up-to-date `main`:

```bash
git switch main
git pull
git switch -c chore/<short-name>
```

Name branches `<type>/<short-name>`, with a type matching the issue:

| Prefix | For |
|---|---|
| `chore/` | Maintenance: dependencies, tooling, docs, cleanup. This repository's tickets use it most. |
| `feat/` | New functionality |
| `fix/` | Bug fixes |

Use lowercase words joined by hyphens, for example `chore/env-example-0.12` or `fix/reset-link-host`.

## 4. Make Your Change

Run the stack in watch mode so your changes reach the running app:

```bash
docker compose watch
```

For the fastest feedback, you can instead run the backend and frontend dev servers directly on your machine. See [development.md](../development.md#local-development).

Depending on what you change, there may be a follow-up step:

| If you change... | Also do this |
|---|---|
| Database models (`backend/app/models.py`) | Create a migration and commit it (see [Database migrations](#database-migrations)) |
| API routes or their models | Regenerate the frontend client. The commit hook does it for you, or run `bash scripts/generate-client.sh`. |
| Email templates (`packages/react-email/`) | Run `bun run email:export` and commit the regenerated `backend/app/email-templates/*.html` |
| A setting in `backend/app/core/config.py` | Add it to `.env.example` with a safe default and a comment |
| Something a student or user would notice | Update the docs in the same PR |

### Database migrations

The schema is changed only through [Alembic](https://alembic.sqlalchemy.org) migrations. After editing the models, with the stack running:

```bash
cd backend
uv run alembic revision --autogenerate -m "Add last_name to User"
```

Review the generated file in `backend/app/alembic/versions/`, since autogenerate can miss or misread changes, then apply it:

```bash
uv run alembic upgrade head
```

Commit the migration file together with the model change.

## 5. Test Your Change

| What | Command | Notes |
|---|---|---|
| Code checks | `uv run prek run --all-files` | Lint, format and type checks for backend and frontend. Fix what it reports, then commit any files it reformatted. |
| Backend tests | `cd backend && uv run bash scripts/test.sh` | Needs `db` and `mailpit` running. CI requires at least **90% coverage**. **Deletes all users and items** in your local database (see below). |
| End-to-end tests | `docker compose run --rm playwright bunx playwright test` | Needs the stack running. Add tests in `frontend/tests/` for new UI behavior. |
| Everything CI runs | `bash scripts/test-ci-docker.sh --playwright` | Runs CI's checks on a clean copy of your last commit. Stop your local stack first. |

Add or update tests with every behavior change. Backend tests live in `backend/tests/` and run against a real database.

> **The backend tests wipe your local data.** They use the same `app` database as your running stack, and when they finish, they delete **every user and item**, including the admin account. Afterwards, recreate the admin before using the app or running the end-to-end tests:
>
> ```bash
> docker compose run --rm backend bash scripts/prestart.sh
> ```
>
> To test without touching your local data, use `bash scripts/test-ci-docker.sh`, which runs everything on a separate, temporary copy.

## 6. Commit

Write commit messages as `<type>: <what changed, in the imperative>`, using the same types as branches plus `docs`:

```text
fix: send the password-reset link to the frontend host
docs: add the self-hosted deployment checklist
```

Add a body when the *why* isn't obvious from the change.

The commit hook runs the checks on the files you changed. **If a check modifies files, the commit stops.** Review the changes, `git add` them, and commit again. Don't bypass the hook with `--no-verify`: CI runs the same checks and will fail.

## 7. Open a Pull Request

```bash
git push -u origin <branch>
```

Then open a pull request into `main`. Its description should say:

* **what** changed and **why**, linking the issue (`Closes #123` closes it automatically when the PR is merged into `main`);
* **how you tested** it;
* anything the reviewer should look at closely, or decisions you made along the way.

CI runs automatically on every PR (see [ci-cd.md](./ci-cd.md)). It needs no setup or secrets. A PR is ready for review when CI is green.

## 8. Review and Merge

* **Reviewers look for:** a change that does what the issue asked and nothing else, tests that cover it, readable code that matches the surrounding style, updated docs, and no secrets or credentials in the diff.
* **Responding to feedback:** push follow-up commits to the same branch. Reply to each comment, or resolve it, so the reviewer can see what changed.
* **Merging:** once approved and green, merge with a merge commit. Then delete the branch and update your local `main`.

## Code Style

Formatting and most style rules are enforced automatically, so there's little to memorize:

* **Backend:** [Ruff](https://docs.astral.sh/ruff/) for lint and format; [mypy](https://mypy-lang.org) and [ty](https://docs.astral.sh/ty/) for types. Use type hints everywhere, and SQLModel models for database tables and API schemas.
* **Frontend:** [Biome](https://biomejs.dev) for lint and format; TypeScript in strict mode. Use the generated client (`@/client`) for API calls, never hand-written `fetch` calls, and the shadcn/ui components in `frontend/src/components/ui/`.
* **Everywhere:** match the surrounding code. Don't commit commented-out code or stray debug output.

## Using AI Tools

AI coding assistants are welcome, and this repository helps them: `uv sync` links up-to-date FastAPI and SQLModel guidance for assistants into `.claude/skills/` and `.agents/skills/`. You're still the author of what you submit:

* **Read and understand every line** before you commit it. You need to be able to explain it in review.
* **Run it and test it.** Generated code that looks right is often subtly wrong.
* **Keep the PR yours:** the description, review replies and decisions should reflect your own judgment.

## Where Things Are

[ARCHITECTURE.md](../ARCHITECTURE.md) explains how the parts fit together and where they live. For the backend and frontend specifics, see [backend/README.md](../backend/README.md) and [frontend/README.md](../frontend/README.md).
