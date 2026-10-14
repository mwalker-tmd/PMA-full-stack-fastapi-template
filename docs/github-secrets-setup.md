# GitHub Secrets and Variables

**You don't need any secrets or variables for CI.** The test workflows run on the public defaults in `.env.example`, so a new repository from this template has green CI with nothing configured. [ci-cd.md](./ci-cd.md#how-ci-is-configured) explains why.

Secrets and variables are only needed **to deploy**, and only for the deploy workflow you use:

* [FastAPI Cloud (`deploy.yml`)](#fastapi-cloud-deployyml), the default
* [Self-hosted (`deploy-docker-compose.yml`)](#self-hosted-deploy-docker-composeyml), your own server

If you haven't chosen a deployment yet, skip this page.

## Secrets vs Variables

GitHub Actions has two kinds of stored configuration, both under **Settings → Secrets and variables → Actions**:

| | Secrets | Variables |
|---|---|---|
| For | Passwords, keys, tokens, connection strings | Names, hostnames, email addresses, other non-sensitive settings |
| Can you read the value later? | No. Write-only once saved. | Yes, in the settings page |
| In workflow logs | Masked as `***` | Printed in plain text |
| In a workflow | `${{ secrets.NAME }}` | `${{ vars.NAME }}` |

The rule here: **if leaking it would let someone log in, decrypt something, or impersonate the app, it's a secret.** Everything else is a variable, which is easier to check and change.

`FIRST_SUPERUSER` (the admin's email address) and `PROJECT_NAME` are variables for that reason. The admin's *password* is a secret.

## FastAPI Cloud (`deploy.yml`)

Step-by-step setup: [deployment.md](../deployment.md).

| Name | Kind | Required | What it is |
|---|---|---|---|
| `FASTAPI_CLOUD_TOKEN` | Secret | Yes | Deploy token from FastAPI Cloud |
| `FASTAPI_CLOUD_APP_ID` | Secret | Yes | Your FastAPI Cloud application ID |
| `DATABASE_URL` | Secret | Yes | Connection URL from your database provider. Must be reachable from GitHub's runners. |
| `SECRET_KEY` | Secret | Yes | Signs login tokens. Same value as configured in FastAPI Cloud. |
| `FIRST_SUPERUSER_PASSWORD` | Secret | Yes | Password for the first admin account |
| `PROJECT_NAME` | Variable | Yes | App name, shown in the UI and emails |
| `FIRST_SUPERUSER` | Variable | Yes | Email address of the first admin account |

Until both `FASTAPI_CLOUD_TOKEN` and `FASTAPI_CLOUD_APP_ID` are set, the workflow **skips** deployment with a notice instead of failing. `uv run fastapi cloud setup-ci --secrets-only --app-id <your-app-id>` sets those two for you (see [deployment.md](../deployment.md#configure-continuous-deployment)).

## Self-Hosted (`deploy-docker-compose.yml`)

Step-by-step setup, including installing the self-hosted runner: [deployment-docker-compose.md](../deployment-docker-compose.md).

| Name | Kind | Required | What it is |
|---|---|---|---|
| `SECRET_KEY` | Secret | Yes | Signs login tokens |
| `FIRST_SUPERUSER_PASSWORD` | Secret | Yes | Password for the first admin account |
| `POSTGRES_PASSWORD` | Secret | Yes | Password for the PostgreSQL database that runs on your server |
| `DOMAIN` | Variable | Yes | Your domain, e.g. `example.com`. Traefik serves the app there and gets its HTTPS certificate. |
| `PROJECT_NAME` | Variable | Yes | App name |
| `FIRST_SUPERUSER` | Variable | Yes | Email address of the first admin account |
| `SMTP_HOST` | Variable | For email | Your email provider's SMTP server |
| `EMAILS_FROM_EMAIL` | Variable | For email | Sender address for emails |
| `SMTP_USER` | Variable | If your provider requires login | SMTP username |
| `SMTP_PASSWORD` | Secret | If your provider requires login | SMTP password |
| `SENTRY_DSN` | Variable | Optional | Enables error reporting to [Sentry](https://sentry.io) |

Emails are sent only when both `SMTP_HOST` and `EMAILS_FROM_EMAIL` are set. Set `SMTP_USER` and `SMTP_PASSWORD` only for a real email provider that requires login, never for Mailpit.

## Generating Secret Values

Use a random value for `SECRET_KEY` and each password:

```bash
openssl rand -hex 32
```

The output contains only letters and digits, so it's also safe in a database URL, where characters like `@`, `:` or `/` would break it. Use a different value for each secret, and don't reuse your local `.env` values in a deployment.

## Setting Them

### With the GitHub CLI (recommended)

```bash
gh secret set SECRET_KEY                          # prompts for the value
gh variable set PROJECT_NAME --body "My App"
```

`gh secret set` without `--body` **prompts** for the value. It doesn't end up in your shell history, and no stray newline gets added. Check what's set with:

```bash
gh secret list
gh variable list
```

### In the browser

**Settings → Secrets and variables → Actions**, then the **Secrets** or **Variables** tab, then **New repository secret** or **New repository variable**.

When pasting, make sure you don't copy a line break after the value. **A trailing newline becomes part of the secret**, and GitHub won't show it to you afterwards, because secrets can't be read back. A password with a hidden newline makes the database password, or the URL built from it, silently differ from what you meant.

## Optional: Keep Deploy Secrets in an Environment

Repository secrets are available to every workflow in the repository. For extra protection, store the deploy secrets in a GitHub **Environment** instead. A job then receives them only if it declares that environment, and you can limit the environment to the `main` branch or require an approval before each deployment.

1. **Settings → Environments → New environment**, named `production`. Optionally, under **Deployment branches**, allow only `main`, and add **Required reviewers**.
2. Add the deploy secrets and variables to the environment instead of the repository:

   ```bash
   gh secret set SECRET_KEY --env production
   gh variable set PROJECT_NAME --env production --body "My App"
   ```

3. Declare the environment in the deploy workflow, on **every job that reads the secrets**:
   * `deploy.yml`: both the `check-config` job and the `deploy` job. If only `deploy` declares it, `check-config` can't see the FastAPI Cloud secrets and always skips deployment.
   * `deploy-docker-compose.yml`: its `deploy` job.

   ```yaml
   jobs:
     deploy:
       environment: production
       runs-on: ubuntu-latest
   ```

Which protection rules you can use, such as required reviewers, depends on your GitHub plan and on whether the repository is public or private. See GitHub's [environments documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment).

## Cleaning Up After Upgrading From an Older Template

Earlier versions of this template needed many more repository secrets and variables, most of them for CI. If your repository predates this version, compare `gh secret list` and `gh variable list` with the tables above. **Anything not listed above isn't read by any workflow** and can be deleted:

```bash
gh variable delete NAME
gh secret delete NAME
```

## Troubleshooting

**The Deploy workflow is green but nothing was deployed.** Open the run: the `check-config` job reports that `FASTAPI_CLOUD_TOKEN` or `FASTAPI_CLOUD_APP_ID` is not set. Set both (see [above](#fastapi-cloud-deployyml)). If you use an Environment, also check that `check-config` declares it.

**A deployment can't connect to the database, or logins fail, although the values look right.** The secret may contain a trailing newline from pasting. Set it again with `gh secret set NAME` and type or paste the value at the prompt.

**Emails aren't sent from a deployment.** Check that `SMTP_HOST` and `EMAILS_FROM_EMAIL` are set, and that `SMTP_USER` and `SMTP_PASSWORD` match your email provider.

**I changed a secret, but the app still uses the old value.** Secrets are read when a workflow runs. Run the deploy workflow again.

For problems running the app itself, see [troubleshooting.md](./troubleshooting.md).
