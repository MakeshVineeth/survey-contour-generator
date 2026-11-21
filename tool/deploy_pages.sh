#!/usr/bin/env bash
# Builds the web app and publishes it to the `gh-pages` branch (GitHub Pages).
#
#   tool/deploy_pages.sh            # build + commit + push
#   tool/deploy_pages.sh --no-push  # build + commit only
#
# Requires: Flutter on PATH, a clean `git` remote named `origin`.
# Pages must be set to "Deploy from a branch: gh-pages / (root)" in repo settings.
set -euo pipefail
cd "$(dirname "$0")/.."

# Git Bash on Windows would otherwise rewrite the leading "/" of --base-href.
export MSYS_NO_PATHCONV=1

REPO_NAME="$(basename -s .git "$(git remote get-url origin)")"
BASE_HREF="/${REPO_NAME}/"
VERSION="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml | head -n1)"
PUSH=1
[ "${1:-}" = "--no-push" ] && PUSH=0

flutter build web --release --wasm --no-web-resources-cdn --web-content-hash \
  --base-href "$BASE_HREF"

# Work inside build/ (git-ignored): a plain relative path behaves the same for git
# and for the shell on every OS, unlike mktemp paths under Git Bash on Windows.
WORK="build/pages-deploy"
git worktree remove --force "$WORK/site" >/dev/null 2>&1 || true
rm -rf "$WORK"
mkdir -p "$WORK"
trap 'git worktree remove --force "$WORK/site" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

# Reuse the existing gh-pages history when there is one, else start an orphan branch.
git fetch origin gh-pages >/dev/null 2>&1 || true
if git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
  git worktree add -B gh-pages "$WORK/site" origin/gh-pages >/dev/null
else
  git worktree add --orphan -b gh-pages "$WORK/site" >/dev/null
fi

# Replace the site wholesale; never let git convert line endings in build output.
find "$WORK/site" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R build/web/. "$WORK/site"/
touch "$WORK/site/.nojekyll"

cd "$WORK/site"
git -c core.autocrlf=false add -A
if git diff --cached --quiet; then
  echo "No changes to deploy."
  exit 0
fi
git -c core.autocrlf=false commit -q -m "deploy: ${REPO_NAME} web ${VERSION}"
if [ "$PUSH" = 1 ]; then
  git push origin gh-pages
  echo "Deployed https://$(git remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#' | tr '[:upper:]' '[:lower:]').github.io/${REPO_NAME}/"
fi
