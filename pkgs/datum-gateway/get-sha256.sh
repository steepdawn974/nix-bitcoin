#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git jq curl nix

set -euo pipefail

REPO_OWNER=OCEAN-xyz
REPO_NAME=datum_gateway
REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME.git"

# Get the latest tag from GitHub API
TAG=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/tags" | jq -r '.[0].name')

echo "Cloning $REPO_URL at tag $TAG..."
TMPDIR=$(mktemp -d)
git clone --depth 1 --branch "$TAG" "$REPO_URL" "$TMPDIR/$REPO_NAME"

# Remove .git directory to match what Nix does
rm -rf "$TMPDIR/$REPO_NAME/.git"

HASH=$(nix hash path "$TMPDIR/$REPO_NAME")

rm -rf "$TMPDIR"

echo
echo "tag: $TAG"
echo "sha256: $HASH"
