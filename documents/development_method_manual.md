# Development Method: Manual

**Source tag:** `[MANUAL]`  
**Tooling:** Cursor IDE on MacBook  
**Use cases:** Bug fixes, pipeline changes, infrastructure work, anything requiring direct code control

---

## Overview

The Manual method is the most direct path from idea to production. The developer writes code in Cursor IDE, commits to `develop`, and the CI/CD pipeline handles the rest — versioning, building, deploying to dev, and presenting a HITL card for promotion approval.

This method is the foundation that all other methods depend on. When something breaks in an Assisted, Autonomous, or Dreamflow change, the Manual method is how you fix it.

---

## Prerequisites

Ensure the following are in place before starting:

- Cursor IDE installed and the `local2local` repo open
- Flutter 3.38.5 installed and `flutter doctor` passing
- Firebase CLI installed (`npm install -g firebase-tools`)
- Authenticated to the correct GCP project (`gcloud auth login`)
- On the `develop` branch with a clean working tree

```bash
git checkout develop
git pull --rebase origin develop
git status  # should show nothing to commit
```

---

## Step 1: Make your changes

Write your code in Cursor. There are no restrictions on which files you edit.

**Keep changes focused.** Each commit goes through its own HITL gate. A focused change is easier to approve or reject cleanly, and easier to cherry-pick if it gets abandoned.

---

## Step 2: Verify locally

Run Flutter analysis before committing:

```bash
flutter analyze
```

If you have Cloud Functions changes, validate TypeScript:

```bash
cd functions
npm run build
cd ..
```

Fix any errors before proceeding. The pipeline will catch them anyway, but catching them locally saves a 4-minute build cycle.

---

## Step 3: Commit

Use the standard commit format:

```
[MANUAL] TYPE(scope): Description
```

Do not prefix the version number — the pipeline adds it automatically.

**Examples:**
```bash
git add .
git commit -m "[MANUAL] FIX(pipeline): Skip deployments triggered by merge commits"
git commit -m "[MANUAL] FEAT(orchestrator): Add decision card to HITL gate"
git commit -m "[MANUAL] CHORE(docs): Add CI/CD pipeline reference document"
```

### Optional: Controlling the version bump

By default, the pipeline increments the PATCH number. To increment MINOR or MAJOR, append a `BUMP:` tag (case insensitive):

```bash
git commit -m "[MANUAL] FEAT(marketplace): Add seller onboarding flow BUMP: MINOR"
git commit -m "[MANUAL] FEAT(platform): Launch phase 44 BUMP: MAJOR"
```

The `BUMP:` tag is stripped from the commit message before the final versioned message is built. So `[MANUAL] FEAT(marketplace): Add seller onboarding flow BUMP: MINOR` becomes `43.2.0 - [MANUAL] FEAT(marketplace): Add seller onboarding flow` in the git log.

### If the remote is ahead

If another commit landed on `develop` while you were working (e.g. an `[AUTO] CHORE(version)` bump), use rebase — never merge:

```bash
git pull --rebase origin develop
git push origin develop
```

Never use `git pull` without `--rebase`. A merge commit will trigger the pipeline unnecessarily and produce an `UNKNOWN` originator in the HITL card.

---

## Step 4: Push

```bash
git push origin develop
```

---

## Step 5: Watch the pipeline

Go to [github.com/local2local/local2local/actions](https://github.com/local2local/local2local/actions) and watch the run. You will see two commits appear in quick succession:

1. Your commit — e.g. `[MANUAL] FIX(pipeline): Description`
2. The auto-version bump — e.g. `43.1.55 - [AUTO] CHORE(version): Bump 43.1.54 to 43.1.55 (PATCH) [skip ci]`

Only your commit triggers the full pipeline. The version bump commit has `[skip ci]` and is skipped automatically.

The pipeline takes approximately 4 minutes end-to-end.

---

## Step 6: Respond to the HITL card

When the pipeline completes successfully, a deployment card appears in the `L2LAAF-Orchestrator` Google Chat space:

```
🚀 L2LAAF Deployment: Phase 43.1.55

Originator:     MANUAL
Status:         🟢 GREEN
Intent:         BUG_FIX
Build Details:  43.1.55 - [MANUAL] FIX(pipeline): Description
Throttle:       Proceeding with deployment.

[ PROMOTE TO PROD ]   [ KEEP IN DEV ]
```

**Press `PROMOTE TO PROD`** if the change is ready for production.

**Press `KEEP IN DEV`** if you want to continue iterating before promoting. The change is recorded as an abandoned phase in Firestore and can be resurrected later — see `code_resurrection_mechanics.md`.

---

## Step 7: Confirm promotion (if promoted)

After pressing `PROMOTE TO PROD`, a decision card appears immediately:

```
🚀 L2LAAF Deployment: Phase 43.1.55
Promotion to PROD in progress.
```

Within a few seconds, a second GitHub Actions run will appear on the `main` branch. This run deploys to `local2local-prod`. It takes approximately 4 minutes.

When the production deployment completes, a final card appears:

```
🚀 L2LAAF Deployment: Phase 43.1.55

Promoted to PROD.
Phase 43.1.55 promoted to prod. This merged the tested 'develop'
branch to the 'main' branch and deployed to local2local-prod.

Phase:       43.1.55
Originator:  MANUAL
Commit SHA:  d235957...
Summary:     43.1.55 - [MANUAL] FIX(pipeline): Description
Promoted by: todd.herron@local2local.ca
Status:      ACTIVE
```

---

## Using the deploy.sh script (optional)

The `scripts/deploy.sh` script is a convenience wrapper for the commit step that runs Flutter analysis automatically:

```bash
./scripts/deploy.sh
```

It will:
1. Run `flutter analyze`
2. Prompt you for a commit message (use the standard format)
3. Run `git add .`, `git commit`, `git push origin develop`

This is equivalent to Steps 2–4 above but in one command.

---

## Common mistakes

**Prefixing the version number manually.**  
Wrong: `git commit -m "43.1.55 - [MANUAL] FIX(pipeline): Description"`  
Right: `git commit -m "[MANUAL] FIX(pipeline): Description"`  
The pipeline prefixes the version. Doing it manually creates a double-version in the commit message.

**Using `git pull` without `--rebase`.**  
Wrong: `git pull origin develop`  
Right: `git pull --rebase origin develop`  
A plain `git pull` creates a merge commit that triggers a spurious pipeline run with `UNKNOWN` as the originator.

**Committing directly to `main`.**  
Never commit directly to `main`. All changes must go through `develop` and the HITL gate. Committing to `main` directly bypasses the approval gate and may cause conflicts with the promotion flow.

**Making large unfocused changes.**  
If a change is too large or unfocused, it is harder to approve at the HITL gate. Prefer small, well-scoped commits — one concern per commit, one HITL decision per concern.
