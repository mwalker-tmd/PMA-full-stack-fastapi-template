#! /usr/bin/env bash

# Reproduce the CI test workflows locally before pushing.
#
# Replays the steps of .github/workflows/test-docker-compose.yml and
# test-backend.yml (and, with --playwright, playwright.yml) against a clean
# temporary checkout of the current commit, so the results match what CI
# reports for that commit. Your working tree, .env files and running stack are
# never touched. Uncommitted changes are not tested: commit them first.
#
# Requirements: Docker, uv and, for --playwright, Bun.
# Stop your local stack first (docker compose down), since the test stack
# uses the same ports (8000, 5432, 1025, 8025).
#
# Usage: bash scripts/test-ci-docker.sh [--playwright]

set -euo pipefail

run_playwright=false
for arg in "$@"; do
    case "$arg" in
        --playwright) run_playwright=true ;;
        -h | --help) sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (use --help)" >&2; exit 2 ;;
    esac
done

for tool in docker uv; do
    command -v "$tool" >/dev/null || { echo "❌ $tool is required but not installed" >&2; exit 1; }
done
if $run_playwright; then
    command -v bun >/dev/null || { echo "❌ bun is required for --playwright" >&2; exit 1; }
fi
docker info >/dev/null 2>&1 || { echo "❌ Docker is not running" >&2; exit 1; }

# The backend tests connect to localhost:5432, so a native PostgreSQL (e.g.
# Postgres.app or Homebrew) or a running dev stack would silently take the
# place of the test containers
busy_ports=""
for port in 5432 8000 1025 8025; do
    if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
        busy_ports="$busy_ports $port"
    fi
done
if [ -n "$busy_ports" ]; then
    echo "❌ Port(s)$busy_ports already in use. Stop whatever is listening first:" >&2
    echo "   - your dev stack: docker compose down" >&2
    echo "   - a local PostgreSQL on 5432 (Postgres.app, Homebrew, etc.)" >&2
    echo "   Find it with: lsof -nP -iTCP:<port> -sTCP:LISTEN" >&2
    exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
commit="$(git -C "$repo_root" rev-parse --short HEAD)"
if [ -n "$(git -C "$repo_root" status --porcelain)" ]; then
    echo "⚠️  You have uncommitted changes. They are NOT tested, only commit $commit."
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/test-ci.XXXXXX")"
checkout="$workdir/repo"

cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    if [ -d "$checkout" ]; then
        (cd "$checkout" && docker compose down -v --remove-orphans >/dev/null 2>&1) || true
        git -C "$repo_root" worktree remove --force "$checkout" >/dev/null 2>&1 || true
    fi
    rm -rf "$workdir"
}
trap cleanup EXIT

section() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

section "Preparing a clean checkout of $commit"
git -C "$repo_root" worktree add --detach "$checkout" HEAD >/dev/null
cd "$checkout"
# Same as CI: a throwaway stack on the public local defaults
cp .env.example .env
echo "✅ Checkout ready at $checkout"

section "Test Docker Compose (test-docker-compose.yml)"
docker compose build
docker compose down -v --remove-orphans
docker compose run --rm backend bash scripts/prestart.sh
docker compose up -d --wait backend adminer
curl -fsS http://localhost:8000/api/v1/utils/health-check && echo ""
curl -fsS -o /dev/null http://localhost:8000
echo "✅ Backend and frontend are up"
docker compose down -v --remove-orphans

section "Test Backend (test-backend.yml)"
docker compose up -d --wait db mailpit
(cd backend && uv run bash scripts/prestart.sh)
(cd backend && uv run bash scripts/tests-start.sh "Coverage for $commit")
docker compose down -v --remove-orphans
(cd backend && uv run coverage report --fail-under=90)
echo "✅ Backend tests and coverage passed"

if $run_playwright; then
    section "Playwright Tests (playwright.yml)"
    (cd backend && uv sync)
    (cd frontend && bun ci)
    bash scripts/generate-client.sh
    docker compose build
    docker compose down -v --remove-orphans
    docker compose run --rm backend bash scripts/prestart.sh
    # CI splits the suite into 4 shards; locally it runs as one
    CI=true docker compose run --rm playwright bunx playwright test --fail-on-flaky-tests --reporter=list
    docker compose down -v --remove-orphans
    echo "✅ Playwright tests passed"
fi

section "✅ All CI checks passed for $commit"
if ! $run_playwright; then
    echo "Playwright was skipped. Run with --playwright to include it (slower)."
fi
echo "Lint and formatting run separately: uv run prek run --all-files"
