#! /usr/bin/env bash

# Create .env for CI from .env.example, replacing the local development
# defaults with repository secrets and variables when they are configured.
#
# Values that are unset or empty keep their .env.example defaults, so CI also
# works in a fresh repository without secrets and on pull requests from forks,
# which GitHub runs without access to secrets.

set -euo pipefail

OVERRIDABLE="PROJECT_NAME FIRST_SUPERUSER SECRET_KEY FIRST_SUPERUSER_PASSWORD POSTGRES_PASSWORD"

cp .env.example .env

for name in $OVERRIDABLE; do
    value="${!name:-}"
    if [ -z "$value" ]; then
        echo "$name: using the .env.example default"
        continue
    fi
    # Secrets pasted into the GitHub UI or piped through echo often end in a
    # line break, which is never part of the intended value
    trimmed="${value%"${value##*[!$'\r\n']}"}"
    if [ "$trimmed" != "$value" ]; then
        echo "$name: removed trailing line break(s) from the repository value"
        value="$trimmed"
    fi
    if [[ "$value" == *"'"* ]]; then
        echo "::error::$name contains a single quote, which .env quoting cannot hold. Update the secret or variable."
        exit 1
    fi
    if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
        echo "::error::$name contains a line break in the middle of the value. Update the secret or variable."
        exit 1
    fi
    # Replace the line in place, so variables that reference it, such as
    # DATABASE_URL, still see the new value. ENVIRON avoids escaping issues.
    NAME="$name" VALUE="$value" awk '
        index($0, ENVIRON["NAME"] "=") == 1 { print ENVIRON["NAME"] "='\''" ENVIRON["VALUE"] "'\''"; next }
        { print }
    ' .env > .env.tmp
    mv .env.tmp .env
    echo "$name: using the repository value"
done
