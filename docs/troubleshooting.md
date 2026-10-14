# Troubleshooting

Find your error message or symptom below. Every entry was reproduced on this version of the template, and the error text is quoted as it actually appears, so searching this page for a fragment of your error (`Ctrl+F`/`Cmd+F`) is usually the fastest way in.

If you're setting up for the first time, follow [getting-started.md](./getting-started.md) first. Most first-run problems come from a skipped step there.

## Contents

* [First Steps for Any Problem](#first-steps-for-any-problem)
* [Configuration and `.env`](#configuration-and-env)
* [Docker and the Stack](#docker-and-the-stack)
* [Database](#database)
* [Backend](#backend)
* [Login and Authentication](#login-and-authentication)
* [Email and Mailpit](#email-and-mailpit)
* [Frontend](#frontend)
* [Tooling and CI](#tooling-and-ci)
* [Starting Over](#starting-over)

## First Steps for Any Problem

Run these from the project root. They answer "what is running, and what did it say?"

```bash
docker compose ps                     # which services are up, and are they healthy?
docker compose logs backend           # backend output, including Python tracebacks
docker compose logs --tail=50 db      # last 50 lines from one service
docker compose logs -f backend        # follow live; Ctrl+C to stop
```

The last few lines of a Python traceback name the actual error, for example `pwdlib.exceptions.UnknownHashError: ...`. Search this page for that name.

---

## Configuration and `.env`

### `required variable SECRET_KEY is missing a value: Variable not set`

Also seen with `POSTGRES_PASSWORD`, `PROJECT_NAME`, `FIRST_SUPERUSER` or `FIRST_SUPERUSER_PASSWORD`, from any `docker compose` command.

**Cause:** Docker Compose reads these from `.env`, and it can't find them. Either `.env` doesn't exist, you're running the command outside the project root, or the line is missing or commented out.

**Fix:** From the project root:

```bash
ls .env || cp .env.example .env
```

Then make sure every variable in the **Required** section of `.env` has a value (see [getting-started.md](./getting-started.md#3-set-your-secrets)).

### `SECRET_KEY` / `Field required [type=missing, ...]`

When you run backend commands on your machine (`uv run ...`), with any required variable name in place of `SECRET_KEY`:

```
pydantic_core._pydantic_core.ValidationError: 1 validation error for Settings
SECRET_KEY
  Field required [type=missing, ...]
```

**Cause:** The backend settings are loaded from the `.env` file in the project root, one level above `backend/`, and that variable isn't set there.

**Fix:** Same as above: create `.env` from `.env.example` and fill in the required values. The line before `Field required` names the missing variable.

### `The value of SECRET_KEY is "changethis", for security, please change it, at least for deployments.`

Also seen for `FIRST_SUPERUSER_PASSWORD` and `DATABASE_URL password`.

**Cause:** A placeholder from `.env.example` is still in use. How bad that is depends on `FASTAPI_ENV`:

* **`FASTAPI_ENV=development`** (the default in `.env.example`, and always set for the Docker Compose backend): it's only a `UserWarning` in the logs, and the app runs.
* **Anywhere else**, including deployments: it's an error, and the backend refuses to start:

  ```
  ValidationError: 1 validation error for Settings
    Value error, The value of SECRET_KEY is "changethis", ...
  ```

**Fix:** Replace the placeholder with a generated value:

```bash
openssl rand -hex 32
```

For deployments, set real values in your deployment secrets, not in `.env`. See [deployment.md](../deployment.md).

### `URL scheme should be 'postgres', 'postgresql', ...`

**Cause:** `DATABASE_URL` isn't a PostgreSQL URL. Typical mistakes are a different scheme (`mysql://...`), or no scheme at all (`localhost:5432/app`).

**Fix:** Use the format from `.env.example`:

```
DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@localhost:5432/app
```

`postgres://` and `postgresql://` both work; the backend switches them to its database driver automatically. `DATABASE_URL` only matters when running the backend on your machine. Docker Compose builds its own URL pointing at the `db` service.

### `Input should be a valid URL, invalid port number`

Also seen as other `url_parsing` errors for `DATABASE_URL`.

**Cause:** `POSTGRES_PASSWORD` contains characters that have a meaning inside a URL, such as `@`, `:` or `/`. The password is inserted into `DATABASE_URL`, and those characters break it.

**Fix:** Use a password made only of letters and digits:

```bash
openssl rand -hex 32
```

If the database already exists with the old password, see [`password authentication failed`](#password-authentication-failed-for-user-postgres).

### My `.env` disappeared after `git pull`, or `git pull` refuses because of `.env`

```
error: Your local changes to the following files would be overwritten by checkout:
	.env
```

**Cause:** Older copies of this template tracked `.env` in git. The current version doesn't: `.env` is ignored, and `.env.example` is tracked instead. When a clone that still tracks `.env` updates:

* if you never edited `.env`, git deletes it;
* if you did edit it, git refuses to update.

**Fix:** Save your values first, then update, then put them back:

```bash
cp .env ~/env-backup              # keep your values
git checkout -- .env              # only if git refused: drop the local edits
git pull
cp ~/env-backup .env              # or start from: cp .env.example .env
cp frontend/.env.example frontend/.env
```

Afterwards, `.env` is ignored by git, so this can't happen again.

---

## Docker and the Stack

### `Cannot connect to the Docker daemon at unix:///.../docker.sock. Is the docker daemon running?`

**Cause:** Docker isn't running.

**Fix:** Start Docker Desktop (on Linux, `sudo systemctl start docker`). Wait until it says it's running, then confirm:

```bash
docker info
```

### `ports are not available: ... bind: address already in use`

Also seen as `port is already allocated`.

**Cause:** Another program, or another Docker project, is using a port this stack needs: 80, 5432, 8000, 8025, 8080, 8090 or 1025.

**Fix:** The error names the port. Find what's using it:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

Stop that program, or stop the other project with `docker compose down` in its folder. A stack from this same project started in a different folder counts as "another project".

A local PostgreSQL on port 5432 usually does **not** cause this error. It causes a quieter problem instead; see [`database "app" does not exist`](#fatal-database-app-does-not-exist).

### `docker compose up -d --wait` fails with `container ... playwright-1 exited (0)`

**Cause:** A bare `up` also starts `playwright`, a helper that only exists to run the end-to-end tests. It exits immediately, and `--wait` treats that as a failure, even though the app is running fine.

**Fix:** Start the app's services by name:

```bash
docker compose up -d --wait proxy db adminer backend mailpit
```

### My code changes don't show up

**Cause:** `docker compose up` runs the code that was copied into the images when they were built. Editing files afterwards doesn't change the running containers.

**Fix:** For live updates while you code, use watch mode instead of `up`:

```bash
docker compose watch
```

Or rebuild and restart a service after a change:

```bash
docker compose up -d --build --wait backend
```

### Docker is using a lot of disk space, or builds fail with "no space left on device"

**Cause:** Old images and build cache pile up quickly. The images for this stack alone are several GB.

**Fix:** See what's using the space:

```bash
docker system df
```

Then free it. This removes stopped containers, unused images and build cache for **every project on this machine**, not just this one. Images are downloaded or rebuilt again when needed. It doesn't remove volumes, so your database is kept:

```bash
docker system prune -a
```

To clear only the build cache, which is often the largest item, use `docker builder prune`.

On Docker Desktop, you can also raise the disk limit in **Settings → Resources**.

---

## Database

### `password authentication failed for user "postgres"`

Shown by `scripts/prestart.sh`, or in the backend logs when a page loads data.

**Cause:** You changed `POSTGRES_PASSWORD` after the database was created. PostgreSQL sets its password only once, when the database volume is first created, and keeps it. `.env` and the database now disagree.

This is easy to miss: `docker compose ps` still shows the backend as `(healthy)`, because its health check doesn't touch the database.

**Fix:** Either put the old password back in `.env`, or recreate the database. Recreating **deletes all data**:

```bash
docker compose down -v
docker compose run --rm backend bash scripts/prestart.sh
docker compose up -d --wait proxy db adminer backend mailpit
```

### `FATAL: database "app" does not exist`

Seen when running backend commands on your machine, such as `uv run fastapi dev`, `uv run bash scripts/prestart.sh` or the backend tests, even though the Docker stack is up.

**Cause:** A PostgreSQL installed directly on your computer (Postgres.app, Homebrew `postgresql`, the EDB installer) is listening on `localhost:5432`. It answers instead of the Docker database, and it has no `app` database. Docker doesn't report a port conflict in this case.

**Fix:** Check what's listening:

```bash
lsof -nP -iTCP:5432 -sTCP:LISTEN
```

If it's not Docker, stop the local server: quit Postgres.app from its menu bar icon, or run `brew services stop postgresql@<version>`. `scripts/test-ci-docker.sh` checks for this before it starts.

### `Can't locate revision identified by '...'`

From `scripts/prestart.sh`:

```
ERROR [alembic.util.messaging] Can't locate revision identified by 'fe56fa70289e'
FAILED: Can't locate revision identified by 'fe56fa70289e'
```

**Cause:** The database was migrated by a different version of the code than the one you're running. That usually means you switched to an older branch while keeping the same database volume. The database is "ahead" of the code, and the code doesn't know the newer migration.

Going forward is fine: a database from an older version of this template is upgraded automatically by `prestart.sh`.

**Fix:** Switch back to the branch that matches the database, or start the older branch with a fresh database (`docker compose down -v`, then prepare and start it as usual).

### Looking inside the database

* **Adminer:** <http://localhost:8080>. Log in with **System** `PostgreSQL`, **Server** `db`, **Username** `postgres`, **Password** your `POSTGRES_PASSWORD`, and **Database** `app`.
* **Command line:**

  ```bash
  docker compose exec db psql -U postgres -d app
  ```

---

## Backend

### `ModuleNotFoundError: No module named 'fastapi'`

Or any other dependency.

**Cause:** The command ran with your system Python instead of the project's environment.

**Fix:** Run Python commands through uv, which uses the project environment and installs anything missing:

```bash
uv sync                                    # once, or after dependencies change
cd backend && uv run python -c "import fastapi"
```

### `RuntimeError: Frontend directory '.../backend/app/frontend' does not exist`

You may also see `GET / HTTP/1.1" 500` with `RuntimeError: StaticFiles directory ... does not exist`.

**Cause:** The backend serves the built frontend from `backend/app/frontend`. That folder is created by building the frontend, and it isn't in git, so a fresh clone doesn't have it. Inside Docker the build happens automatically. When you run the backend on your machine:

* `uv run fastapi dev`: the API works, but <http://localhost:8000/> returns a 500. For the UI, use the Vite dev server at <http://localhost:5173> instead.
* `uv run fastapi run`: the backend refuses to start.

**Fix:** Build the frontend once, and rebuild it after frontend changes when you want FastAPI to serve them:

```bash
cd frontend && bun run build
```

---

## Login and Authentication

### Login fails with the right password after I changed `.env`

**Cause:** The admin account (`FIRST_SUPERUSER`, `FIRST_SUPERUSER_PASSWORD`) is created only once, the first time `scripts/prestart.sh` runs against an empty database. Later edits to `.env` don't change the existing account.

**Fix:** Log in with the password the account was created with and change it in the app's settings. Or recreate the database, which **deletes all data**:

```bash
docker compose down -v
docker compose run --rm backend bash scripts/prestart.sh
docker compose up -d --wait proxy db adminer backend mailpit
```

### `{"detail":"Could not validate credentials"}` (403)

**Cause:** Your login token isn't valid anymore. Either `SECRET_KEY` changed since you logged in (tokens are signed with it), or the token expired. Tokens last 8 days by default (`ACCESS_TOKEN_EXPIRE_MINUTES`).

**Fix:** Log out and log in again. In the API docs (`/docs`), click **Authorize** again.

### Login returns 500, and the logs show `pwdlib.exceptions.UnknownHashError`

```
pwdlib.exceptions.UnknownHashError: This hash can't be identified. Make sure it's valid and that its corresponding hasher is enabled.
```

**Cause:** The user's `hashed_password` in the database isn't a password hash. This typically happens when someone edits it directly, for example typing a plain password into Adminer. Passwords are hashed with Argon2, and existing bcrypt hashes from older versions are still accepted (and upgraded to Argon2 on the next login). Anything else can't be checked.

**Fix:** Generate a proper hash:

```bash
cd backend && uv run python -c "from app.core.security import get_password_hash; print(get_password_hash('your-new-password'))"
```

Then paste the output, starting with `$argon2id$`, into that user's `hashed_password` in Adminer. Or set the password through the app instead: an admin can edit the user, or the user can use **Forgot your password?**.

---

## Email and Mailpit

Locally, emails are not delivered. [Mailpit](https://mailpit.axllent.org) catches them so you can read them:

* **Web UI:** <http://localhost:8025>
* **From the command line:**

  ```bash
  curl -s http://localhost:8025/api/v1/messages
  ```

### No email arrives in Mailpit, but the app says it was sent

For example, **Forgot your password?** reports success. The password recovery page always responds the same way, so it never shows an error.

Check the backend logs for the result of the send:

```bash
docker compose logs backend | grep "send email result"
```

A failed send looks like this. `status_code=None` means it didn't go through:

```
send email result: <emails.backend.SMTPResponse status_code=None status_text=None>
```

**Causes and fixes:**

* **`SMTP_USER` (or `SMTP_PASSWORD`) is set.** Mailpit doesn't support SMTP login, so any username makes every send fail. Remove or comment out `SMTP_USER` and `SMTP_PASSWORD` in `.env`, then restart the backend (`docker compose up -d --wait backend`).
* **Mailpit isn't running.** When you run the backend on your machine, start it first: `docker compose up -d mailpit`. `docker compose ps` should list `mailpit` as `(healthy)`.
* **Wrong host or port.** On your machine, `.env` should have `SMTP_HOST=localhost` and `SMTP_PORT=1025`. In Docker Compose, these are set to the `mailpit` service automatically.

---

## Frontend

### Build fails: `error TS...` and `"bun run build" did not complete successfully: exit code: 2`

Seen from `docker compose build`, `docker compose up --build` or `bun run build`:

```
src/main.tsx(57,7): error TS2322: Type 'string' is not assignable to type 'number'.
ERROR: process "/bin/sh -c bun run build" did not complete successfully: exit code: 2
```

**Cause:** The frontend is type-checked and built during the backend image build, so a TypeScript error in `frontend/src` stops the Docker build too. The line before `ERROR` names the file, line and problem.

**Fix:** Fix the reported error. Checking on your machine is faster than rebuilding the image:

```bash
cd frontend && bun run build
```

### Vite dev server: every API call fails with 404

**Cause:** `VITE_API_URL` isn't set, so the frontend sends API requests to the Vite dev server itself (<http://localhost:5173>), which has no API.

**Fix:** Make sure `frontend/.env` exists and sets the backend URL, then restart `bun run dev`:

```bash
cp frontend/.env.example frontend/.env    # contains VITE_API_URL=http://localhost:8000
```

### Browser console: `blocked by CORS policy`

**Cause:** The backend only accepts browser requests from `FRONTEND_HOST`, which defaults to `http://localhost:5173`. If the Vite dev server runs on another address, for example `http://localhost:5174` because 5173 was busy, the browser blocks the requests.

**Fix:** The simplest fix is to free port 5173 and restart `bun run dev`, so the dev server gets its usual address.

To allow a different address instead, it depends on where the backend runs:

* **Backend on your machine** (`uv run fastapi dev`): set `FRONTEND_HOST` in `.env` to the address the dev server shows, then restart the backend.
* **Backend in Docker Compose:** setting `FRONTEND_HOST` in `.env` has no effect, because Compose doesn't pass it to the container. Free port 5173 instead.

`FRONTEND_HOST` is also used for links in emails.

### Type errors after changing the backend API

**Cause:** The frontend's API client in `frontend/src/client` is generated from the backend's API. After changing backend routes or models, it's out of date.

**Fix:** Regenerate it. This needs uv and Bun:

```bash
bash scripts/generate-client.sh
```

If you've installed the git hooks (`uv run prek install -f`), this runs automatically when you commit backend changes.

---

## Tooling and CI

### `bun: command not found` (exit code 127) when committing

**Cause:** The pre-commit hooks use Bun: one lints the frontend, and another regenerates the API client when backend code changes. So everyone needs Bun, even if you only work on the backend.

**Fix:** [Install Bun](https://bun.sh/docs/installation), open a new terminal, and confirm with `bun --version`.

### CI's `pre-commit` check fails and shows a diff

**Cause:** A formatting or lint hook would change files. CI doesn't fix them for you; it shows the diff and fails.

**Fix:** Run the hooks on your machine, then commit and push the changes they make:

```bash
uv run prek run --all-files
```

To catch this before pushing, install the git hooks once with `uv run prek install -f`.

### Checking a change before you push

`scripts/test-ci-docker.sh` runs the same Docker Compose, backend and (with `--playwright`) end-to-end checks as CI, on a clean copy of your latest commit:

```bash
bash scripts/test-ci-docker.sh
```

If it stops with `Port(s) ... already in use`, stop your local stack (`docker compose down`) or the local PostgreSQL it names, and run it again.

---

## Starting Over

When nothing else helps, this resets the local stack completely. It **deletes your local database**:

```bash
docker compose down -v --remove-orphans
docker compose build --pull
docker compose run --rm backend bash scripts/prestart.sh
docker compose up -d --wait proxy db adminer backend mailpit
```

Your `.env` files and code are not touched.

For problems with deployments, see [deployment.md](../deployment.md) (FastAPI Cloud) or [deployment-docker-compose.md](../deployment-docker-compose.md) (your own server).
