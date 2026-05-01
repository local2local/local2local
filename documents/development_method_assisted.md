# Development Method: Assisted

**Source tag:** `[ASSISTED]`  
**Tooling:** AI chat session (Claude or Gemini) + `scripts/relay.sh` + `scripts/patcher.js`  
**Use cases:** Feature development, complex refactors, multi-file changes where AI generation accelerates development

---

## Overview

The Assisted method uses an AI coding assistant to generate a structured payload bundle containing all file changes for a given task. The developer reviews the generated code in the chat session, then runs a single script (`relay.sh`) that extracts the files, validates the code, commits, and pushes to `develop`. The CI/CD pipeline takes over from there.

The developer remains in full control — the AI generates code, but the developer reviews it before it touches the repo.

---

## How it works

```
Developer describes task to AI
    → AI generates logic_payload.txt bundle
    → Developer copies bundle to scripts/logic_payload.txt
    → Developer runs ./scripts/relay.sh
        → patcher.js extracts files from bundle
        → TSC validation (Cloud Functions)
        → Flutter analyze
        → n8n workflow JSON validation
        → git commit (using COMMIT_MSG from bundle)
        → git push origin develop
    → CI/CD pipeline: Bump Version → Build → Deploy → HITL gate
```

---

## Prerequisites

- AI chat session open (Claude or Gemini) with the codebase context loaded
- Repo on `develop` branch with a clean working tree
- `node`, `flutter`, `firebase-tools` installed
- Scripts are executable: `chmod +x scripts/relay.sh`

```bash
git checkout develop
git pull --rebase origin develop
git status  # should show nothing to commit
```

---

## Step 1: Provide context to the AI

Start your AI session with the relevant context. At minimum, provide:

- The current `documents/cicd_pipeline_reference.md`
- The current `documents/ai_context_rules.md`
- Any files directly relevant to the change you're requesting

Use `scripts/audit.sh` to generate a bundle of recently changed files or the core logic structure:

```bash
./scripts/audit.sh
```

This creates `audit_bundle.txt` and copies it to your clipboard on Mac. Paste it into the AI chat.

---

## Step 2: Describe the task

Give the AI a clear, focused description of what you need. Be specific about:

- Which files need to change
- What the expected behaviour is
- Any constraints or rules from `ai_context_rules.md` that are relevant

The AI will generate a `logic_payload.txt` bundle structured as a series of `L2LAAF_BLOCK` sections.

---

## Step 3: Review the generated bundle

Before running anything, read through the AI's output in the chat window. Check that:

- The logic is correct and matches what you asked for
- No unintended files are being modified
- The `COMMIT_MSG` block uses the correct format: `[ASSISTED] TYPE(scope): Description`
- No version prefix is included in the commit message (the pipeline adds it)
- The `BUMP:` tag is included if this is a minor or major change

A valid bundle looks like this:

```
L2LAAF_BLOCK_START(code:index.ts:functions/src/index.ts)
// full file content here
L2LAAF_BLOCK_END

L2LAAF_BLOCK_START(commit:message:COMMIT_MSG)
[ASSISTED] FEAT(marketplace): Add seller onboarding flow BUMP: MINOR
L2LAAF_BLOCK_END
```

If the `COMMIT_MSG` block is missing or malformed, `relay.sh` will fail with a clear error before touching git.

---

## Step 4: Copy the bundle to scripts/logic_payload.txt

Copy the full content of the AI's output and paste it into `scripts/logic_payload.txt`:

```bash
# If the AI session is on your Mac and audit.sh copied to clipboard:
pbpaste > scripts/logic_payload.txt

# Or open the file and paste manually:
open scripts/logic_payload.txt
```

---

## Step 5: Run relay.sh

```bash
./scripts/relay.sh
```

The script runs these steps in order, stopping on any failure:

**① Patcher** — extracts all `L2LAAF_BLOCK` sections and writes files to their target paths. Handles directory creation automatically.

**② TypeScript validation** — runs `npm run build` in `functions/`. If Cloud Functions TypeScript fails, the script exits with a clear error before touching git.

**③ Flutter analysis** — runs `flutter analyze`. Any analysis errors stop the script.

**④ n8n workflow validation** — if `n8n_workflows/` exists, validates JSON syntax and checks that all webhook nodes have `webhookId` fields.

**⑤ Git commit and push** — reads `COMMIT_MSG`, stages all changes including n8n workflows, commits, and pushes to `develop`. If the remote is ahead (e.g. due to an auto-version commit that landed while relay was running), it automatically rebases and retries the push.

On success you will see:

```
🟢 DEPLOYMENT COMPLETE: Stack stabilized and pushed.
```

---

## Step 6: Watch the pipeline and respond to the HITL card

Same as the Manual method — see `development_method_manual.md` Steps 5–7.

The HITL card will show `Originator: ASSISTED`.

---

## Commit message rules for the AI

When prompting the AI, instruct it to format the `COMMIT_MSG` block as follows:

```
[ASSISTED] TYPE(scope): Description
```

Rules to communicate to the AI:
- `[ASSISTED]` source tag is always used for this method
- `TYPE` must be uppercase: `FIX`, `FEAT`, `CHORE`, `REFACTOR`, etc.
- `scope` is a single lowercase word describing what changed
- `Description` is in title case
- No version number prefix — the pipeline adds it
- Append `BUMP: MINOR` or `BUMP: MAJOR` only when the change warrants it
- Default (no tag) is a PATCH bump

**Wrong:**
```
43.1.55 - fix(marketplace): add seller onboarding
```

**Right:**
```
[ASSISTED] FEAT(marketplace): Add Seller Onboarding Flow BUMP: MINOR
```

---

## What relay.sh will NOT do

- It will not push if TypeScript validation fails
- It will not push if Flutter analysis fails
- It will not push if n8n JSON is invalid
- It will not push if `COMMIT_MSG` is missing
- It will not create a merge commit — it uses `--rebase` automatically

---

## Handling relay.sh failures

**Patcher failed — no valid L2LAAF_BLOCK sections found**  
The bundle is empty or malformed. Ask the AI to regenerate the full payload.

**TypeScript validation failed**  
The Cloud Functions code has type errors. Share the error output with the AI and ask for a fix. The AI will generate a corrected payload — paste it into `logic_payload.txt` and run `relay.sh` again.

**Flutter validation failed**  
Same approach — share the `flutter analyze` output with the AI.

**Push failed after rebase — merge conflict**  
The AI modified the same lines as a recent autonomous commit. Resolve the conflict manually:
```bash
git status           # see conflicted files
# edit files to resolve conflicts
git add <file>
git rebase --continue
git push origin develop
```

---

## The audit.sh script

`scripts/audit.sh` generates a context bundle of recently changed files to paste into an AI chat session. It:

1. Finds files changed in the last commit (`git diff HEAD~1 HEAD`)
2. If nothing changed recently, falls back to the core logic structure (`functions/src/logic/`, `lib/`)
3. Outputs `audit_bundle.txt` and copies it to clipboard on Mac

Run it at the start of a new AI session to give the AI the most relevant context:

```bash
./scripts/audit.sh
# Paste clipboard content into AI chat
```

---

## Tips for effective AI collaboration

**Give the AI focused tasks.** One concern per payload. Multi-concern payloads are harder to review and harder to approve at the HITL gate.

**Always provide `ai_context_rules.md`.** This document contains hard-won rules about n8n, TypeScript, and commit formatting that the AI needs to follow. Paste it at the start of every session.

**Ask the AI to explain its changes.** Before copying the bundle, ask "Walk me through what you changed and why." This catches misunderstandings before code reaches the repo.

**If relay.sh fails, stay in the same AI session.** Paste the error output directly back to the AI. It has the context of what it just generated and can fix it efficiently.

**Use `audit.sh` between iterating.** After a successful push and before starting the next task in the same session, run `audit.sh` again to give the AI the updated file state.
