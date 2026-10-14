# Contributing

Thanks for contributing!

The full guide is [docs/contributing.md](./docs/contributing.md): setting up your machine, branches, tests, commits, pull requests and review. New to the project? Start with [docs/getting-started.md](./docs/getting-started.md).

In short:

1. Start from an issue. For bigger changes, agree on the approach there first.
2. Branch from `main` as `<type>/<short-name>`, for example `chore/update-docs` or `fix/login-error`.
3. Install the commit checks once with `uv run prek install -f`, and keep them passing.
4. Add or update tests, and open a focused pull request into `main` that links the issue.
5. Wait for CI to pass and for a review, then merge.
