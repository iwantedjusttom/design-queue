#!/usr/bin/env bash
# Project board helper — set a repo issue/PR's Status on Tom's unified board.
#
# Usage:  board-status.sh <repo-name> <issue-or-pr-number> ["<Status name>"]
#   e.g.  board-status.sh samcamp 98 Ready      # add to table + set column
#         board-status.sh samcamp 98            # ADD-ONLY: on the table, NO column
#
# Omit the Status name for ADD-ONLY mode: the item is put on the board with no
# column set, so Tom decides where it sits. design-queue / build-loop use this to
# guarantee every issue/PR/migration lands on the table without ever moving it.
#
# - Tom's unified board is account-level Project #1 ("Tom's feature list"),
#   shared across ALL his repos. owner + project number below are stable.
# - Idempotently adds the item to the board if it isn't there yet, then sets Status.
# - Resolves the project/field/option IDs BY NAME every run, so renaming a
#   column (e.g. Future -> Idea) never breaks callers. Status name is matched
#   case-sensitively to a column: Idea | backlog | Ready | Building | In Review | Migrations | Closed
#   (Migrations = side-lane for needs-migration deploy issues; closed -> Closed via the built-in workflow)
set -euo pipefail

OWNER="iwantedjusttom"
PROJ_NUM=1
REPO="${1:?repo name}"; NUM="${2:?issue/PR number}"; export STATUS="${3:-}"

# Project id + Status field id + the requested option id (all resolved by name)
eval "$(gh api graphql -f query="
query {
  user(login: \"$OWNER\") {
    projectV2(number: $PROJ_NUM) {
      id
      field(name: \"Status\") { ... on ProjectV2SingleSelectField { id options { id name } } }
    }
  }
}" --jq '
  "PID=\(.data.user.projectV2.id); FID=\(.data.user.projectV2.field.id); " +
  ((.data.user.projectV2.field.options[] | select(.name==env.STATUS) | "OID=\(.id)") // "OID=")
')"

# Content node id + state (works for both issues and PRs)
eval "$(gh api graphql -f query="query { repository(owner:\"$OWNER\", name:\"$REPO\") { issueOrPullRequest(number:$NUM) { ... on Issue { id state } ... on PullRequest { id state } } } }" \
  --jq '"CID=\(.data.repository.issueOrPullRequest.id); CSTATE=\(.data.repository.issueOrPullRequest.state)"')"

# ── ADD-ONLY MODE ────────────────────────────────────────────────────────────
# No status name given → just make sure the item is ON the table; never set a
# column (Tom owns where it sits). This is how design-queue / build-loop put
# every issue, PR, and migration on the board without changing its location.
if [ -z "$STATUS" ]; then
  gh api graphql -f query="mutation { addProjectV2ItemById(input:{projectId:\"$PID\", contentId:\"$CID\"}) { item { id } } }" \
    --jq '.data.addProjectV2ItemById.item.id' >/dev/null
  echo "board: $REPO#$NUM -> added to table (no column)"
  exit 0
fi

# A status WAS requested but matches no column → a real error.
if [ -z "${OID:-}" ]; then
  echo "board-status: no column named \"$STATUS\" on Project #$PROJ_NUM" >&2; exit 1
fi

# Race guard: a closed/merged item must never be dragged back to a pre-close
# column. GitHub's built-in "Item closed -> Closed" workflow owns the Closed
# move the instant a PR merges; if a late Building/In Review write (e.g.
# build-loop's final step landing just after Tom merges) overwrote it, the card
# would wrongly resurrect. So once the item is closed, only an explicit "Closed"
# request is honored — everything else is a no-op.
if [ "$STATUS" != "Closed" ] && { [ "$CSTATE" = "CLOSED" ] || [ "$CSTATE" = "MERGED" ]; }; then
  echo "board: $REPO#$NUM is $CSTATE — skipping \"$STATUS\" (won't resurrect a finished card)"
  exit 0
fi

# Add to board (idempotent: returns the existing item id if already present)
ITEM=$(gh api graphql -f query="mutation { addProjectV2ItemById(input:{projectId:\"$PID\", contentId:\"$CID\"}) { item { id } } }" \
  --jq '.data.addProjectV2ItemById.item.id')

# Set the Status field
gh api graphql -f query="mutation { updateProjectV2ItemFieldValue(input:{projectId:\"$PID\", itemId:\"$ITEM\", fieldId:\"$FID\", value:{singleSelectOptionId:\"$OID\"}}) { projectV2Item { id } } }" \
  --jq '.data.updateProjectV2ItemFieldValue.projectV2Item.id' >/dev/null

echo "board: $REPO#$NUM -> $STATUS"
