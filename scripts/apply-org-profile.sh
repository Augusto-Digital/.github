#!/usr/bin/env bash
# Apply the organization profile in org-profile.json to GitHub.
#
# GitHub stores an organization's description, website, location, and email
# in org settings, not in any repository, so a pull request cannot change them.
# This script pushes the values in org-profile.json to the org through the
# REST API (PATCH /orgs/{org}). Run it once from a machine where `gh` is
# authenticated as an organization owner:
#
#   ./scripts/apply-org-profile.sh            # apply
#   ./scripts/apply-org-profile.sh --dry-run  # print the request, change nothing
#
# Requires: gh (https://cli.github.com), jq.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="$here/org-profile.json"
dry_run=0
[[ "${1:-}" == "--dry-run" ]] && dry_run=1

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: $tool is required" >&2; exit 1; }
done
[[ -f "$profile" ]] || { echo "error: $profile not found" >&2; exit 1; }

org="$(jq -r '.login' "$profile")"
[[ -n "$org" && "$org" != "null" ]] || { echo "error: org-profile.json needs a .login" >&2; exit 1; }

# Only the fields GitHub accepts on PATCH /orgs/{org}; nulls are dropped.
payload="$(jq -c '{name, description, blog, location, email, twitter_username}
                  | with_entries(select(.value != null))' "$profile")"

echo "Organization: $org"
echo "Payload:      $payload"

if [[ $dry_run -eq 1 ]]; then
  echo "(dry run, nothing sent)"
  exit 0
fi

gh api --method PATCH "/orgs/$org" \
  -H "Accept: application/vnd.github+json" \
  --input <(printf '%s' "$payload") \
  --jq '{login, name, description, blog, location, email, twitter_username}'

echo "Applied. Verify at https://github.com/$org"
