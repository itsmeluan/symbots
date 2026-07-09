#!/bin/bash
# Claude Code Stop hook: auto-commit uncommitted work (commit only — never push).
# User-authorized exception to "No commits without user instruction" in
# CLAUDE.md's Collaboration Protocol. Fires on every Stop event (closest
# available proxy for "a skill/command finished" — Claude Code has no
# skill-boundary hook). Push always stays a manual, deliberate action.
#
# Re-runs the same checks validate-commit.sh applies to manual commits, since
# a hook-internal `git commit` never triggers the PreToolUse(Bash) hook that
# validate-commit.sh is normally wired to.

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Don't interfere with an in-progress merge/rebase
if [ -f .git/MERGE_HEAD ] || [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
    exit 0
fi

[ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0

git add -A 2>/dev/null

# Reuse the manual-commit validation path (same script, synthetic payload) so
# auto-commits get the same checks as commits made via Claude's Bash tool.
VALIDATION_OUTPUT=""
VALIDATION_EXIT=0
if [ -f .claude/hooks/validate-commit.sh ]; then
    VALIDATION_OUTPUT=$(printf '{"tool_input": {"command": "git commit -m auto-commit"}}' | bash .claude/hooks/validate-commit.sh 2>&1)
    VALIDATION_EXIT=$?
fi

json_message() {
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg m "$1" '{systemMessage: $m}'
    else
        ESCAPED=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
        printf '{"systemMessage": "%s"}\n' "$ESCAPED"
    fi
}

if [ "$VALIDATION_EXIT" -ne 0 ]; then
    # Blocking issue (e.g. invalid JSON in assets/data/) — leave staged, don't commit
    json_message "Auto-commit skipped — validation blocked it: $VALIDATION_OUTPUT"
    exit 0
fi

FILES=$(git diff --cached --name-only 2>/dev/null)
COUNT=$(echo "$FILES" | grep -c .)
SAMPLE=$(echo "$FILES" | head -5 | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
if [ "$COUNT" -gt 5 ]; then
    SAMPLE="$SAMPLE, and $((COUNT - 5)) more"
fi

COMMIT_MSG="chore: auto-commit — $COUNT file(s) changed ($SAMPLE)

Automated via Stop hook (.claude/hooks/auto-commit.sh). Push is manual."

if [ -n "$VALIDATION_OUTPUT" ]; then
    COMMIT_MSG="$COMMIT_MSG

Validation-Warnings: $(printf '%s' "$VALIDATION_OUTPUT" | tr '\n' ' ')"
fi

if git commit -q -m "$COMMIT_MSG" >/dev/null 2>&1; then
    if [ -n "$VALIDATION_OUTPUT" ]; then
        json_message "Auto-committed $COUNT file(s) with warnings: $VALIDATION_OUTPUT"
    else
        json_message "Auto-committed $COUNT file(s): $SAMPLE"
    fi
fi

exit 0
