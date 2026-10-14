# Deployment Checklist

Step-by-step checklists for the three ways to run this application, from "nothing set up" to "verified working". Work through the one you need, top to bottom, and tick each item.

| Where | Use it for | Needs | Guide |
|---|---|---|---|
| **[A. Your computer](#a-local-docker-desktop)** | Development, demos, trying things out | Docker Desktop | [getting-started.md](./getting-started.md) |
| **[B. FastAPI Cloud](#b-fastapi-cloud)** (the default) | A public deployment without running a server | A FastAPI Cloud account and an external PostgreSQL | [deployment.md](../deployment.md) |
| **[C. Your own server](#c-self-hosted-server-with-a-github-actions-runner)** | Full control, everything on one machine | A Linux server, a domain, and a self-hosted GitHub Actions runner | [deployment-docker-compose.md](../deployment-docker-compose.md) |

**Choosing between B and C.** FastAPI Cloud is the template's default because there's no server to maintain: HTTPS, restarts and scaling are handled for you, and it deploys automatically on every push to `main`. You do need a PostgreSQL database from a provider, and should check FastAPI Cloud's current pricing for your situation. A self-hosted server costs a small monthly fee for a cloud VM, needs no other services, and teaches you more about how deployment works. But keeping it updated, backed up and secure is up to you. Both deploy workflows are included, and the FastAPI Cloud one skips itself until it's configured, so you can use either without removing the other.

---

## A. Local (Docker Desktop)

Full explanations are in [getting-started.md](./getting-started.md).

- [ ] Docker Desktop is installed and running (`docker info` succeeds)
- [ ] Repository cloned, and the commands below run from its root folder
- [ ] Environment files created:
  ```bash
  cp .env.example .env
  cp frontend/.env.example frontend/.env
  ```
- [ ] `SECRET_KEY`, `FIRST_SUPERUSER_PASSWORD` and `POSTGRES_PASSWORD` in `.env` replaced with values from `openssl rand -hex 32`
- [ ] Ports 80, 5432, 8000, 8025, 8080 and 8090 are free, and no local PostgreSQL is running (`lsof -nP -iTCP:5432 -sTCP:LISTEN` shows nothing)
- [ ] Database prepared:
  ```bash
  docker compose run --rm backend bash scripts/prestart.sh
  ```
- [ ] Stack started, with every service healthy:
  ```bash
  docker compose up -d --wait proxy db adminer backend mailpit
  docker compose ps
  ```

**Verify:**

- [ ] <http://localhost:8000> shows the login page, and you can log in as `FIRST_SUPERUSER`
- [ ] <http://localhost:8000/docs> shows the API docs
- [ ] <http://localhost:8080> (Adminer) logs in to server `db`, user `postgres`, database `app`
- [ ] **Forgot your password?** sends an email that appears in <http://localhost:8025>

---

## B. FastAPI Cloud

Follow [deployment.md](../deployment.md) for each step. The secrets and variables are described in [github-secrets-setup.md](./github-secrets-setup.md#fastapi-cloud-deployyml).

**Before you start:**

- [ ] A FastAPI Cloud account, and an application created with **Application Directory** `backend`
- [ ] A PostgreSQL database from a provider, reachable from the internet. GitHub's runners connect to it to run the migrations.
- [ ] Values generated for `SECRET_KEY` and `FIRST_SUPERUSER_PASSWORD` (`openssl rand -hex 32`, a different one each)

**Configure:**

- [ ] Environment variables set in the FastAPI Cloud application, as listed in [deployment.md](../deployment.md)
- [ ] GitHub secrets `FASTAPI_CLOUD_TOKEN` and `FASTAPI_CLOUD_APP_ID` set (`uv run fastapi cloud setup-ci --secrets-only --app-id <id>`)
- [ ] GitHub secrets `DATABASE_URL`, `SECRET_KEY` and `FIRST_SUPERUSER_PASSWORD` set, with the same values as in FastAPI Cloud
- [ ] GitHub variables `PROJECT_NAME` and `FIRST_SUPERUSER` set
- [ ] `gh secret list` and `gh variable list` show all of the above

**Deploy:**

- [ ] Push to `main`, or run **Actions → Deploy → Run workflow**
- [ ] The run's `check-config` job did **not** report "skipping FastAPI Cloud deployment", and the `deploy` job succeeded

**Verify:**

- [ ] `https://<your-app>.fastapicloud.dev` shows the login page, and you can log in as `FIRST_SUPERUSER`
- [ ] `https://<your-app>.fastapicloud.dev/docs` shows the API docs
- [ ] If email is configured: **Forgot your password?** delivers an email to a real inbox

---

## C. Self-Hosted Server with a GitHub Actions Runner

This deploys the full Docker Compose stack, including Traefik with automatic HTTPS, to your own Linux server. A [self-hosted GitHub Actions runner](https://docs.github.com/en/actions/hosting-your-own-runners) on that server runs the deployment when you trigger it. The commands for each step are in [deployment-docker-compose.md](../deployment-docker-compose.md).

### 1. Before you start

- [ ] **A Linux server** (a cloud VM is fine) with a public IP address and SSH access. The images are built on the server, so give it room: as a starting point, 2 GB of RAM and 20 GB of disk.
- [ ] **A domain**, e.g. `app.example.com`, with DNS **A records** pointing at the server's IP for both:
  - [ ] `app.example.com`
  - [ ] `adminer.app.example.com`

  Check them with `dig +short app.example.com`. Wait for DNS to answer correctly before the first deploy, because Let's Encrypt can only issue certificates for names that already point at the server.
- [ ] **Firewall** allows inbound TCP **80** and **443** (and SSH). Port 80 must stay open: Let's Encrypt uses it, and it redirects visitors to HTTPS.
- [ ] **Docker Engine** with the Compose plugin installed on the server ([install guide](https://docs.docker.com/engine/install/)), and `docker compose version` works
- [ ] **The repository is private,** or you fully trust everyone who can push to it. A self-hosted runner executes workflow code directly on your server.

### 2. Install the runner

Following [deployment-docker-compose.md](../deployment-docker-compose.md#install-a-self-hosted-runner):

- [ ] A dedicated `github` user exists and is in the `docker` group
- [ ] The runner is registered in **Settings → Actions → Runners → New self-hosted runner** (Linux), installed in `/home/github/actions-runner`
- [ ] The runner is installed and started as a service (`sudo ./svc.sh install github`, `sudo ./svc.sh start`), so it survives reboots
- [ ] **Settings → Actions → Runners** shows the runner as **Idle**

### 3. Configure the repository

All names and their meanings: [github-secrets-setup.md](./github-secrets-setup.md#self-hosted-deploy-docker-composeyml). Use `gh secret set NAME`, which prompts for the value, so no stray newline ends up in a secret.

- [ ] Variables: `DOMAIN` (e.g. `app.example.com`, without `https://`), `PROJECT_NAME`, `FIRST_SUPERUSER`
- [ ] Secrets: `SECRET_KEY`, `FIRST_SUPERUSER_PASSWORD`, `POSTGRES_PASSWORD`, each from `openssl rand -hex 32`
- [ ] For email: variables `SMTP_HOST` and `EMAILS_FROM_EMAIL`, plus `SMTP_USER` and the `SMTP_PASSWORD` secret if your provider requires login
- [ ] Optional: variable `SENTRY_DSN`
- [ ] Store `POSTGRES_PASSWORD` somewhere safe outside GitHub as well. GitHub can't show it back to you, and **changing it after the first deploy breaks the database connection** (see [Changing secrets later](#changing-secrets-later)).

### 4. Deploy

- [ ] **Actions → Deploy with Docker Compose → Run workflow**, with branch `main`
- [ ] The run finished green. It builds the images, runs `prestart.sh` (migrations and first superuser), and starts the stack with `compose.yml` + `compose.deploy.yml`.

The first run takes several minutes, because the images are built on the server.

### 5. Verify

From your own computer:

- [ ] `https://app.example.com` shows the login page **with a valid certificate**. The certificate is requested on the first visit and can take up to a minute.
- [ ] `curl -I http://app.example.com` answers with a redirect (`301`, `302` or `308`) to `https://`
- [ ] You can log in as `FIRST_SUPERUSER` with `FIRST_SUPERUSER_PASSWORD`
- [ ] `https://app.example.com/docs` shows the API docs
- [ ] `https://adminer.app.example.com` shows Adminer
- [ ] If email is configured: **Forgot your password?** delivers an email to a real inbox

On the server:

- [ ] `docker ps` lists the `proxy`, `db`, `adminer` and `backend` containers as running, and `backend` as `healthy`

### 6. Secure it

- [ ] **Adminer is public** at `adminer.<DOMAIN>`, protected only by the database password. Unless you need it, don't create its DNS record, or remove its Traefik labels in your copy of `compose.deploy.yml`. You can still reach it through an SSH tunnel.
- [ ] Only people you trust can push to the repository, and no workflow that runs on the self-hosted runner is triggered by pull requests
- [ ] The server's firewall allows only 22, 80 and 443 inbound. PostgreSQL isn't published by `compose.deploy.yml`; keep it that way.
- [ ] Automatic OS security updates are enabled (on Ubuntu, `unattended-upgrades`)
- [ ] You've logged in once and confirmed `FIRST_SUPERUSER_PASSWORD` is a generated value, not anything reused

### 7. Operate it

**Container names** are `<project>-<service>-1`. `<project>` is the folder the runner checks the code out into: your repository's name in lowercase. On the server, you can use plain `docker` commands, which don't need the deployment's environment variables:

```bash
docker ps                                   # what's running
docker logs --tail=100 <project>-backend-1  # backend logs
docker logs <project>-proxy-1               # Traefik: routing and certificate errors
```

**Back up the database** regularly, and before every deployment that includes migrations. Keep copies off the server.

```bash
docker exec <project>-db-1 pg_dump -U postgres -d app --clean --if-exists > backup-$(date +%F).sql
```

`--clean --if-exists` makes the backup replace existing tables when it's restored, so it can be restored over the live database.

**Restore** a backup. This **replaces all current data** with the backup's contents, and stops at the first error:

```bash
docker exec -i <project>-db-1 psql -U postgres -d app -v ON_ERROR_STOP=1 < backup-2026-01-31.sql
```

**Deploy an update:** merge to `main`, then run the workflow again. Migrations run automatically.

**Roll back:** revert the change on `main` (`git revert <commit>`, via a pull request) and run the workflow again. Alembic doesn't undo migrations automatically. If the change included a migration, restore the backup you took before deploying it.

### Changing secrets later

- `SECRET_KEY`: safe to change. Everyone is logged out.
- `FIRST_SUPERUSER_PASSWORD`: has no effect after the first deploy. The admin account already exists, so change the password in the app instead.
- `POSTGRES_PASSWORD`: **don't** change it, unless you also change it inside PostgreSQL. The database keeps the password it was created with, so the backend can't connect after a mismatch.

### If something goes wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| The run waits forever at "Waiting for a runner" | The runner is offline | On the server, `sudo ./svc.sh status` in `/home/github/actions-runner`, then `sudo ./svc.sh start` |
| The run fails with `required variable ... is missing a value` | That variable or secret isn't set | Set it (step 3) and run the workflow again |
| The browser warns about the certificate | DNS doesn't point at the server yet, or port 80/443 is blocked | Fix DNS or the firewall. `docker logs <project>-proxy-1` shows `Unable to obtain ACME certificate for domains` with the reason; Traefik serves its self-signed `TRAEFIK DEFAULT CERT` until it succeeds |
| `404 page not found` (plain text) at your domain | Traefik has no route for that host name | Check that `DOMAIN` exactly matches the name you're visiting |
| Login fails or pages error after you changed `POSTGRES_PASSWORD` | Password mismatch with the existing database | Restore the old value (see above) |
| The run fails building the image | Out of memory or disk on the server | `docker system df`, free space with `docker builder prune`, or use a larger server |

More errors and fixes: [troubleshooting.md](./troubleshooting.md).
