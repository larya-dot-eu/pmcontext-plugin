#!/usr/bin/env bash
# Release check — asserts that what ships matches what's documented.
#
# `claude plugin validate` checks the manifest's shape. It does not check the
# plugin's promise, which is how three drifts shipped in one month:
#   - commands resolved as /pmcontext:pmcontext:plan while every doc said /pmcontext:plan
#   - marketplace.json's sha sat 3 commits stale, so the README described features
#     nobody could install
#   - the workflow block froze at install while the commands moved on
#
# Each check below is one of those bugs, encoded. Run before a release:
#     ./check-release.sh
#
# Exit 0 = safe to release. Exit 1 = something ships that the docs contradict.

set -uo pipefail
cd "$(dirname "$0")"

FAIL=0
note() { printf '  %s\n' "$1"; }
pass() { printf '\033[32m  PASS\033[0m  %s\n' "$1"; }
fail() { printf '\033[31m  FAIL\033[0m  %s\n' "$1"; FAIL=1; }

json() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))$2)" "$1"; }

PLUGIN_JSON=.claude-plugin/plugin.json
MARKET_JSON=.claude-plugin/marketplace.json
DOCS=(README.md skills/pmcontext/SKILL.md templates/CLAUDE.md.example)

# Everything a user receives from a marketplace install and could act on. The
# docs belong here: a pin that lags README.md installs stale instructions, which
# is the same drift as a pin that lags a command file.
SHIPPED_PATHS=(commands templates skills .claude-plugin/plugin.json README.md CHANGELOG.md)

PLUGIN=$(json "$PLUGIN_JSON" '["name"]')
VERSION=$(json "$PLUGIN_JSON" '["version"]')

printf '\n=== Release check: %s %s ===\n\n' "$PLUGIN" "$VERSION"

# ---------------------------------------------------------------------------
# 1. Command names — do the documented commands actually exist?
#
# Commands resolve as <plugin>:<subdir>:<command>, so a file at
# commands/foo/bar.md is /<plugin>:foo:bar, not /<plugin>:bar. Derive the real
# names from the filesystem and compare against every name the docs promise.
# ---------------------------------------------------------------------------
printf 'Commands\n'

REAL=$(find commands -name '*.md' 2>/dev/null | sed -e 's|^commands/||' -e 's|\.md$||' -e 's|/|:|g' \
        | while read -r c; do echo "/${PLUGIN}:${c}"; done | sort)

if [ -z "$REAL" ]; then
  fail "no command files found under commands/"
else
  note "$(echo "$REAL" | wc -l) commands on disk"
fi

# Every /<plugin>:x mentioned in the docs must resolve to a real command.
# This is the direction that catches a namespace change: the docs said
# /pmcontext:plan while the only real command was /pmcontext:pmcontext:plan.
CLAIMED=$(grep -rhoE "/${PLUGIN}:[a-z][a-z0-9:_-]*" "${DOCS[@]}" 2>/dev/null | sort -u)

GHOSTS=$(comm -23 <(echo "$CLAIMED") <(echo "$REAL"))
if [ -n "$GHOSTS" ]; then
  fail "documented commands that do not exist:"
  echo "$GHOSTS" | sed 's/^/          /'
else
  pass "every documented command resolves to a real file"
fi

# Every real command must be documented in the README — a command users cannot
# discover may as well not ship.
README_CLAIMS=$(grep -ohE "/${PLUGIN}:[a-z][a-z0-9:_-]*" README.md 2>/dev/null | sort -u)
UNDOC=$(comm -23 <(echo "$REAL") <(echo "$README_CLAIMS"))
if [ -n "$UNDOC" ]; then
  fail "commands missing from README.md:"
  echo "$UNDOC" | sed 's/^/          /'
else
  pass "every command is documented in README.md"
fi

# ---------------------------------------------------------------------------
# 2. Pin freshness — can users actually get what's committed?
#
# marketplace.json pins installs to a sha. If shipped files changed since that
# sha, the docs describe a version nobody can install.
# ---------------------------------------------------------------------------
printf '\nPin\n'

SHA=$(json "$MARKET_JSON" '["plugins"][0]["source"]["sha"]')
note "pinned at ${SHA:0:7}"

# A pin can only ever point at a commit, so uncommitted work on a shipped file
# is unreachable by definition — and the sha comparison below reads commits, not
# the working tree, so it would not notice.
DIRTY=$(git status --porcelain -- "${SHIPPED_PATHS[@]}" 2>/dev/null)
if [ -n "$DIRTY" ]; then
  fail "uncommitted changes to shipped files — nothing can pin these:"
  echo "$DIRTY" | sed 's/^/          /'
fi

if ! git cat-file -e "$SHA^{commit}" 2>/dev/null; then
  fail "pinned sha is not a commit in this repo"
elif ! git merge-base --is-ancestor "$SHA" HEAD 2>/dev/null; then
  fail "pinned sha is not an ancestor of HEAD — it points off this branch"
else
  DRIFT=$(git diff --name-only "$SHA" HEAD -- "${SHIPPED_PATHS[@]}" 2>/dev/null)
  if [ -n "$DRIFT" ]; then
    fail "shipped files changed since the pin — users cannot install this:"
    echo "$DRIFT" | sed 's/^/          /'
    note "fix: push the code, then pin marketplace.json to that commit and push again"
  else
    pass "pin covers all shipped files"
  fi

  # The pin must exist on the remote, or `claude plugin install` resolves nothing.
  if git branch -r --contains "$SHA" 2>/dev/null | grep -q .; then
    pass "pinned sha is on the remote"
  else
    fail "pinned sha is not pushed — installs will fail to resolve it"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Version — is this release written down?
# ---------------------------------------------------------------------------
printf '\nVersion\n'

if grep -qE "^## \[${VERSION}\]" CHANGELOG.md 2>/dev/null; then
  pass "CHANGELOG.md has an entry for $VERSION"
else
  fail "CHANGELOG.md has no '## [$VERSION]' heading"
fi

# Tags are how a human finds a release on GitHub — the pin is machine-facing and
# invisible there. Tagging silently lapsed after 1.0.4 and went unnoticed for nine
# versions, because nothing looked.
TAG="pmcontext--v${VERSION}"
if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  fail "no tag $TAG — run: git tag -a $TAG <code-commit> -m \"pmcontext $VERSION\""
elif ! git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  fail "tag $TAG exists locally but is not pushed — run: git push origin --tags"
else
  TAGGED_VERSION=$(git show "$TAG:.claude-plugin/plugin.json" 2>/dev/null \
                   | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])' 2>/dev/null)
  if [ "$TAGGED_VERSION" != "$VERSION" ]; then
    fail "$TAG points at a tree whose plugin.json says $TAGGED_VERSION — mislabeled tag"
  else
    pass "$TAG exists, is pushed, and matches plugin.json"
  fi
fi

MARKET_DESC=$(json "$MARKET_JSON" '["plugins"][0]["description"]')
PLUGIN_DESC=$(json "$PLUGIN_JSON" '["description"]')
if [ "$MARKET_DESC" = "$PLUGIN_DESC" ]; then
  pass "plugin.json and marketplace.json descriptions agree"
else
  fail "plugin.json and marketplace.json descriptions have drifted apart"
fi

printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mOK — safe to release\033[0m\n\n'
else
  printf '\033[31mBLOCKED — what ships does not match what is documented\033[0m\n\n'
fi
exit "$FAIL"
