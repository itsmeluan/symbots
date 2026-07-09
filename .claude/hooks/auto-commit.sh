#!/bin/bash
# Claude Code Stop hook: auto-commit uncommitted work (commit only — never push).
# User-authorized exception to "No commits without user instruction" in
# CLAUDE.md's Collaboration Protocol. Fires on every Stop event (closest
# available proxy for "a skill/command finished" — Claude Code has no
# skill-boundary hook). Push always stays a manual, deliberate action.

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Don't interfere with an in-progress merge/rebase
if [ -f .git/MERGE_HEAD ] || [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
    exit 0
fi

[ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0

git add -A 2>/dev/null

FILES=$(git diff --cached --name-only 2>/dev/null)
COUNT=$(echo "$FILES" | grep -c .)
SAMPLE=$(echo "$FILES" | head -5 | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
if [ "$COUNT" -gt 5 ]; then
    SAMPLE="$SAMPLE, and $((COUNT - 5)) more"
fi

if git commit -q -m "chore: auto-commit — $COUNT file(s) changed ($SAMPLE)

Automated via Stop hook (.claude/hooks/auto-commit.sh). Push is manual." >/dev/null 2>&1; then
    printf '{"systemMessage": "Auto-committed %s file(s): %s"}\n' "$COUNT" "$SAMPLE"
fi

exit 0
