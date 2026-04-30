# Code Resurrection Mechanics

## Overview

When a change is marked **KEEP IN DEV** at the HITL gate, it is recorded as an abandoned phase in Firestore at:

```
Project:    local2local-dev
Collection: artifacts/system_status/public/data/abandoned_phases
```

The change is never deleted from git — it remains permanently in the `develop` branch history and can be resurrected at any time by cherry-picking it into a new version.

---

## Abandoned Phase Firestore Document

Each abandoned phase is recorded with the following structure:

```json
{
  "phase": "43.1.38",
  "commit_sha": "83a524a",
  "summary": "43.1.38 - [MANUAL] FEAT(pipeline): Split n8n workflow into dev/prod",
  "originator": "MANUAL",
  "abandoned_at": "2026-04-29T15:01:08Z",
  "abandoned_by": "todd.herron@local2local.ca",
  "reason": "KEEP_IN_DEV",
  "status": "ABANDONED"
}
```

| Field | Description |
|---|---|
| `phase` | The version number of the abandoned change |
| `commit_sha` | The exact git commit SHA — used to cherry-pick the change |
| `summary` | The full commit message for context |
| `originator` | Which development method created it: MANUAL, ASSISTED, AUTO, or DREAM |
| `abandoned_at` | ISO 8601 timestamp of when KEEP IN DEV was pressed |
| `abandoned_by` | The Google account that pressed KEEP IN DEV |
| `reason` | Always `KEEP_IN_DEV` for abandoned phases |
| `status` | `ABANDONED` initially, updated to `RESURRECTED` when cherry-picked |

Abandoned phases are viewable in the **SuperAdmin dashboard** in the dev environment.

---

## Step-by-Step Resurrection Instructions

### Step 1: Find the abandoned phase

Open the SuperAdmin dashboard in the dev environment and navigate to the abandoned phases list. Note the `commit_sha` of the phase you want to resurrect — e.g. `83a524a`.

Alternatively, query Firestore directly:
```
Project:    local2local-dev
Collection: artifacts/system_status/public/data/abandoned_phases
Filter:     status == "ABANDONED"
```

---

### Step 2: Determine the next available version number

Check the current phase on `develop`:

```bash
git checkout develop
git pull origin develop
cat .l2laaf/state.json | grep current_phase
```

If the current phase is `43.2.1`, your resurrected change will become `43.2.2`.

---

### Step 3: Cherry-pick the abandoned commit

```bash
git checkout develop
git pull origin develop
git cherry-pick 83a524a
```

If there are conflicts (because the codebase has moved on since the change was abandoned), resolve them manually:

```bash
# For each conflicted file:
# 1. Open the file and resolve the conflict markers
# 2. Stage the resolved file
git add <conflicted-file>

# Once all conflicts are resolved:
git cherry-pick --continue
```

---

### Step 4: Update the version number

Open `pubspec.yaml` and update the version:

```yaml
# Before
version: 43.1.38+530

# After (using next available version)
version: 43.2.2+531
```

Open `.l2laaf/state.json` and update the current phase:

```json
{
  "current_phase": "43.2.2",
  ...
}
```

---

### Step 5: Commit with a resurrection message

```bash
git add pubspec.yaml .l2laaf/state.json
git commit --amend -m "43.2.2 - [MANUAL] FEAT(x): Resurrect abandoned phase 43.1.38 — original: Split n8n workflow into dev/prod"
git push origin develop
```

The `--amend` updates the cherry-picked commit message to include the new version number.

---

### Step 6: Update the Firestore record

After pushing, update the abandoned phase document in Firestore:

```json
{
  "status": "RESURRECTED",
  "resurrected_as": "43.2.2",
  "resurrected_at": "2026-05-15T10:30:00Z"
}
```

This can be done via the SuperAdmin dashboard or directly in the Firestore console.

---

### Step 7: Respond to the HITL gate

The push to `develop` triggers the normal deployment pipeline. A `PROMOTE TO PROD` / `KEEP IN DEV` card will appear in the L2LAAF-Orchestrator Google Chat space. Review and respond as normal.

---

## Important Notes

- **A resurrected phase always gets a new version number.** Never reuse the original phase number.
- **Cherry-picks are safe.** Git cherry-pick copies the diff, not the commit history, so the original abandoned commit remains untouched in history.
- **Multiple phases can be resurrected independently.** Each gets its own new version number and goes through its own HITL gate.
- **The serial pipeline is preserved.** Resurrected changes enter the pipeline at the current tip of `develop`, not at their original position.
