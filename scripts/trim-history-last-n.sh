#!/bin/bash
# Trim repo history to only the last N commits, then prune to reduce .git size.
# Use this to keep the repository under a manageable size when health-check
# commits run every 15 minutes (e.g. KEEP=500 ~= 5 days of history).
#
# Run from repo root. Ensure working tree is clean and you have a backup.
# After running, you must force-push: git push --force-with-lease
#
# Usage: ./scripts/trim-history-last-n.sh [N]
#   N = number of commits to keep (default: 500)

set -e
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

KEEP="${1:-500}"
if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [ "$KEEP" -lt 1 ]; then
  echo "Usage: $0 [N]" >&2
  echo "  N = number of commits to keep (default: 500)" >&2
  exit 1
fi

TOTAL=$(git rev-list --count HEAD 2>/dev/null || echo 0)
if [ "$TOTAL" -le "$KEEP" ]; then
  echo "Repository has $TOTAL commits (<= $KEEP). Nothing to trim."
  echo "Running gc only to reclaim space..."
  git reflog expire --expire=now --all
  git gc --prune=now --aggressive
  echo "Done. .git size: $(du -sh .git | cut -f1)"
  exit 0
fi

# Oldest commit we want to keep (will become the new root)
ROOT_COMMIT=$(git rev-list -n 1 HEAD~$((KEEP - 1)))
echo "=== Trimming to last $KEEP commits ($TOTAL -> $KEEP) ==="
echo "New root commit: $ROOT_COMMIT"
echo "This may take a long time for large repos..."
echo ""

FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --parent-filter '
  if [ "$GIT_COMMIT" = "'"$ROOT_COMMIT"'" ]; then
    true
  else
    cat
  fi
' --tag-name-filter cat -- --all

echo ""
echo "=== Removing backup refs from filter-branch ==="
git for-each-ref --format="%(refname)" refs/original/ 2>/dev/null | xargs -r -n1 git update-ref -d || true

echo "=== Expire reflog and prune ==="
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "=== Done. Commit count and .git size ==="
git rev-list --count HEAD
du -sh .git
echo "Push with: git push --force-with-lease"
