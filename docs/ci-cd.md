# CI/CD

This project uses GitHub Actions to check every pull request (continuous integration, CI) and to deploy the application (continuous deployment, CD). This page describes what each workflow does, when it runs, and how it's configured.

**The short version:**

* **CI works out of the box.** A brand-new repository created from this template runs green CI with no secrets or variables configured.
* **Only deployment needs configuration.** Secrets and variables are read by the two deploy workflows and nothing else. See [github-secrets-setup.md](./github-secrets-setup.md).

## Workflow Inventory

All workflows live in `.github/workflows/`.

| File | Name in the Actions tab | Runs on | What it does | Reads secrets or variables |
|---|---|---|---|---|
| `test-backend.yml` | Test Backend | PRs; pushes to `main` | Backend tests with coverage, minimum 90% | No |
| `test-docker-compose.yml` | Test Docker Compose | PRs; pushes to `main` | Builds the stack and checks that it starts | No |
| `playwright.yml` | Playwright Tests | PRs and pushes to `main` that touch app code; manual | End-to-end browser tests in 4 parallel shards | No |
| `pre-commit.yml` | pre-commit | PRs | Lint, format, type checks and API client freshness | No |
| `zizmor.yml` | Zizmor | PRs; pushes to `main`; manual | Security analysis of the workflow files themselves | No |
| `detect-conflicts.yml` | Conflict detector | Every push; PR updates | Labels open PRs that have merge conflicts | Only GitHub's built-in token |
| `deploy.yml` | Deploy | Pushes to `main`; manual | Deploys to [FastAPI Cloud](https://fastapicloud.com) (the default) | Yes |
| `deploy-docker-compose.yml` | Deploy with Docker Compose | Manual only | Deploys to your own server through a self-hosted runner | Yes |

[Dependabot](#dependabot) is configured separately, in `.github/dependabot.yml`.

## How CI Is Configured

The CI workflows (`test-backend`, `test-docker-compose`, `playwright` and `pre-commit`) start with the same step:

```yaml
- name: Create .env
  run: cp .env.example .env
```

Each run starts a throwaway stack with the public local-development defaults from `.env.example`, tests it, and deletes it. Nothing in it is worth protecting, so CI deliberately uses **no** repository secrets:

* **A fresh repository is green immediately.** Students don't have to configure anything before their first PR.
* **Pull requests from forks work.** GitHub never gives secrets to workflows triggered by a fork's PR, so CI that needed secrets would fail for every outside contributor.
* **Production secrets stay out of PR workflows.** Any code in a PR from a branch in the same repository can read the secrets its workflows receive. Because CI receives none, a PR can't expose the secrets your deploy workflows use.

If you add a setting that CI needs, add it to `.env.example` with a safe local default. See [Adding a Setting](#adding-a-setting).

Never set `SMTP_USER` or `SMTP_PASSWORD` for anything that sends email to Mailpit, which is what CI and local development use. Mailpit doesn't support SMTP login, so every email would fail silently.

## CI Workflows

### Test Backend (`test-backend.yml`)

1. Starts the `db` and `mailpit` services with Docker Compose.
2. Runs migrations and creates the first superuser (`backend/scripts/prestart.sh`).
3. Runs the backend tests with `pytest`, measuring coverage.
4. Uploads the HTML coverage report as the `coverage-html` artifact. Download it from the run's summary page.
5. **Fails if coverage is below 90%.**

The backend runs directly on the runner with uv, not in a container, which is why it reaches the database at `localhost:5432` like a local setup does.

### Test Docker Compose (`test-docker-compose.yml`)

Builds every image, prepares the database, starts `backend` and `adminer`, then checks that the API health endpoint and the frontend served by FastAPI both respond. This catches Dockerfile and Compose problems, including frontend build errors, since the frontend is built inside the backend image.

### Playwright Tests (`playwright.yml`)

1. A `changes` job checks whether the push or PR touched `backend/`, `frontend/`, `.env.example`, `compose*.yml` or the workflow itself. If not, the tests are skipped, which counts as passing.
2. Otherwise it regenerates the API client, builds the stack, and runs the Playwright suite in the `playwright` service, split into **4 shards** that run in parallel.
3. `--fail-on-flaky-tests` makes a test that passes only on retry count as a failure.
4. A final job merges the shards into one HTML report, uploaded as an artifact.

You can also start it manually from the Actions tab. The `debug_enabled` option opens a [tmate](https://github.com/mxschmitt/action-tmate) SSH session on the runner for debugging.

### pre-commit (`pre-commit.yml`)

Runs the same [prek](https://prek.j178.dev/) hooks as your local git hook (`.pre-commit-config.yaml`), on the files the PR changed:

| Hook | Checks |
|---|---|
| `check-added-large-files`, `check-toml`, `check-yaml`, `end-of-file-fixer`, `trailing-whitespace`, `typos` | General file hygiene and spelling |
| biome check | Frontend lint and format |
| ruff check, ruff format | Backend lint and format |
| mypy check, ty check | Backend type checking |
| Generate Frontend SDK | Regenerates the frontend API client when backend code changes, so a stale client shows up as a diff |
| add date to latest release header | Dates the newest section of `release-notes.md` |
| zizmor | Workflow security analysis |

**If a hook would change a file, the job fails and prints the diff.** It doesn't push fixes to your branch. Run the hooks locally and commit the result:

```bash
uv run prek run --all-files
```

Install the git hook once (`uv run prek install -f`) and this runs automatically on every commit. The hooks need both uv and Bun installed.

### Zizmor (`zizmor.yml`)

Runs [zizmor](https://docs.zizmor.sh/) over `.github/workflows/` to find insecure workflow patterns, such as untrusted input in shell commands or overly broad permissions. Findings appear as annotations on the PR. A finding that has been reviewed and accepted is marked in the workflow file with a `# zizmor: ignore[...]` comment.

### Conflict detector (`detect-conflicts.yml`)

After every push, it checks open PRs for merge conflicts. Conflicting PRs get a `conflicts` label and the comment "This pull request has a merge conflict that needs to be resolved."

## Deployment Workflows

Both deploy workflows skip GitHub's own copy of the template (`fastapi/full-stack-fastapi-template`) and run only in repositories created from it.

### Deploy (`deploy.yml`): FastAPI Cloud, the default

Runs on every push to `main`, and manually from the Actions tab.

1. A `check-config` job checks whether `FASTAPI_CLOUD_TOKEN` and `FASTAPI_CLOUD_APP_ID` are set. **If either is missing, deployment is skipped with a notice** ("FASTAPI_CLOUD_TOKEN or FASTAPI_CLOUD_APP_ID is not set, skipping FastAPI Cloud deployment"), not failed. So a repository that hasn't set up FastAPI Cloud, or deploys another way, stays green.
2. Otherwise it builds the frontend into `backend/app/frontend`, runs migrations and creates the first superuser against `DATABASE_URL`, then deploys with `uv run fastapi deploy`.

Setup: [deployment.md](../deployment.md). The secrets and variables it reads are listed in [github-secrets-setup.md](./github-secrets-setup.md#fastapi-cloud-deployyml).

### Deploy with Docker Compose (`deploy-docker-compose.yml`): your own server

Manual only: **Actions → Deploy with Docker Compose → Run workflow**. It runs on a [self-hosted runner](https://docs.github.com/en/actions/hosting-your-own-runners) installed on your server, and builds and starts the stack there with `compose.yml` and `compose.deploy.yml`.

It deliberately has no automatic trigger. A self-hosted runner executes workflow code directly on your server, so it must never run code from pull requests.

Setup: [deployment-docker-compose.md](../deployment-docker-compose.md). The secrets and variables it reads are listed in [github-secrets-setup.md](./github-secrets-setup.md#self-hosted-deploy-docker-composeyml).

## The Generated API Client

The frontend calls the backend through a TypeScript client generated from the backend's OpenAPI schema with [`@hey-api/openapi-ts`](https://heyapi.dev/) (version pinned in `frontend/package.json`; configuration in `frontend/openapi-ts.config.ts`). It's written to `frontend/src/client/` and committed to git:

| Path | Contents |
|---|---|
| `sdk.gen.ts` | One class per API tag (`ItemsService`, `LoginService`, `UsersService`, `UtilsService`, `PrivateService`), with a static method per operation |
| `types.gen.ts` | Request and response types for every model and operation |
| `client.gen.ts`, `client/`, `core/` | The Axios-based HTTP client and its helpers |
| `index.ts` | Re-exports everything. Import from `@/client` in app code. |

```ts
import { type UserPublic, UsersService } from "@/client"
```

Never edit these files by hand. Regenerate them after changing backend routes or models:

```bash
bash scripts/generate-client.sh
```

This exports the OpenAPI schema from the backend, runs `openapi-ts`, and formats the result. It runs automatically:

* in the **Generate Frontend SDK** pre-commit hook, whenever backend code, `uv.lock` or the generator config changes;
* at the start of the **Playwright** workflow, so the end-to-end tests always use a client that matches the backend.

If you forget to commit a regenerated client, the pre-commit check fails with the diff.

Dependabot doesn't update `@hey-api/openapi-ts`. Its output layout changes between versions, so upgrade it deliberately and regenerate the client in the same PR.

## Dependabot

`.github/dependabot.yml` opens **monthly** grouped update PRs for GitHub Actions, Python (uv), frontend (Bun), Dockerfiles and Compose images. A new release must be at least 7 days old before Dependabot proposes it (`cooldown`), which protects against compromised or broken releases that are quickly pulled. The PRs go through the same CI as any other PR.

## Running CI Locally

Run the same checks before you push:

```bash
uv run prek run --all-files                      # the pre-commit job
bash scripts/test-ci-docker.sh                   # Test Docker Compose + Test Backend
bash scripts/test-ci-docker.sh --playwright      # ...plus Playwright
```

`test-ci-docker.sh` replays the workflow steps on a clean temporary copy of your latest commit, so its results match CI for that commit. It needs Docker, uv and (for `--playwright`) Bun, and free ports. Stop your local stack first.

## When CI Fails

Open the failed run from the PR's **Checks** tab and expand the red step. The last lines usually name the problem.

| Failing check | Usual cause | Fix |
|---|---|---|
| pre-commit | A hook would change files, or the API client is stale | `uv run prek run --all-files`, then commit |
| Test Backend: coverage report | Coverage dropped below 90% | Add tests for the new code; the `coverage-html` artifact shows which lines aren't covered |
| Test Backend: Run tests | A failing test | Run the backend tests locally (`bash scripts/test-ci-docker.sh`) |
| Test Docker Compose | Image build failed, often a frontend TypeScript error | Run `cd frontend && bun run build` locally to see the error |
| Playwright | A failing or flaky test | Download the merged HTML report artifact; it includes traces of failed tests |
| Zizmor | An insecure workflow pattern | Follow the linked zizmor rule documentation |

Error messages and fixes for running the stack are in [troubleshooting.md](./troubleshooting.md).

## Changing the Workflows

### Adding a setting

* **Needed by the app in CI** (tests, the Compose stack): add it to `.env.example` with a safe local default. CI copies that file, so nothing else is needed. If the value must come from Compose, also add it to the service's `environment:` in `compose.yml`.
* **Needed only for deployment:** add it as a repository secret or variable, pass it in the deploy workflow's `env:`, and document it in [github-secrets-setup.md](./github-secrets-setup.md).

Don't add `secrets.*` to the CI workflows. See [How CI Is Configured](#how-ci-is-configured).

### Turning a workflow off

To pause a workflow without deleting it, use **Actions → (the workflow) → ⋯ → Disable workflow**. To remove it for good, delete its file in a PR.
