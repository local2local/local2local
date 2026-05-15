# L2LAAF AI Chat Checklist

**Last updated:** 2026-05-14
**Script:** `./scripts/ai_chat.sh` (run from repo root)
**Purpose:** Reference guide for all AI chat session start and end procedures.

---

## Quick Start

```zsh
./scripts/ai_chat.sh
```

Select from the main menu:

```
1  Gemini AI chat — Start
2  Gemini AI chat — End
3  Claude AI chat — Start
4  Claude AI chat — End
5  Cancel
```

### Gemini — Start

1. Select **option 1** in the menu
2. Select session type (1–4)
3. Script clears and populates `~/Downloads/gemini_session_documents/` with the correct files
4. Script opens Gemini (AI Studio) and the staging folder in Finder simultaneously
5. **Confirm model is Gemini 2.5 Pro** in AI Studio
6. Select all files in the Finder window (⌘A) and drag into the Gemini chat
7. Paste the GitHub repo link as text in the chat: `https://github.com/local2local/local2local`
8. Press Enter in the terminal — the script walks through Steps 2–4, copying each prompt to clipboard one at a time (⌘V to paste, send, then press Enter to continue)
9. **Verify Gemini's 5 quiz answers** before starting work — correct answers are shown in the terminal

> If Gemini answers Q2 or Q3 incorrectly, correct it before continuing. These are the two failure modes that caused the most regressions.

### Claude — Start

1. Select **option 3** in the menu
2. Select session type (1–5)
3. Script clears and populates `~/Downloads/claude_session_documents/` with the correct files
4. Script opens Claude (claude.ai/new) and the staging folder in Finder simultaneously
5. **Confirm model** — Sonnet 4.6 for audits and debugging, Opus 4.6 for architecture
6. Select all files in the Finder window (⌘A) and drag into the Claude chat
7. Press Enter in the terminal — the script copies the appropriate prompt template to clipboard
8. Paste into Claude (⌘V), fill in the placeholders, and send

> No quiz, no standing instruction, no GitHub link needed for Claude.

---

## Quick End

Always run an end session before closing the chat window. This commits updated documents to the repo and logs the session so the next AI session starts from current state.

### Gemini — End

1. Select **option 2** in the menu
2. Enter a one-line summary of what was accomplished
3. Script shows a numbered list of all files in `documents/` — type comma-separated numbers for every document that changed during the session (e.g. `1,3,5`)
4. For each selected document, the script automatically copies the updated version from `~/Downloads/gemini_session_documents/` into `documents/` if a newer version exists there; otherwise the repo version is left as-is
5. Script appends an entry to `documents/session_log.md` with date, phase, version, summary, and list of updated files
6. Script commits all changes as `[MANUAL] CHORE(docs): Gemini session end — [summary]` and pushes to `develop`
7. Script clears `~/Downloads/gemini_session_documents/`

### Claude — End

1. Select **option 4** in the menu
2. **Save any documents Claude produced or updated** to `~/Downloads/claude_session_documents/` before pressing Enter — the script looks there for updated versions to copy into the repo
3. Press Enter when updated files are in the staging folder
4. Enter a one-line summary of what was accomplished
5. Script shows a numbered list of all files in `documents/` — type comma-separated numbers for every document that changed
6. For each selected document, the script copies the updated version from `~/Downloads/claude_session_documents/` into `documents/` if present
7. Script appends an entry to `documents/session_log.md`
8. Script commits all changes as `[MANUAL] CHORE(docs): Claude session end — [summary]` and pushes to `develop`
9. Script clears `~/Downloads/claude_session_documents/`

> The session log (`documents/session_log.md`) is committed to the repo so both AIs can read recent session summaries as context at the start of future sessions.

---

## Quick Reference

| | Gemini | Claude |
|---|---|---|
| **Role** | Actor — generates code, payloads, n8n workflows | Judge / Architect — QA review, planning, debugging |
| **Preferred model** | Gemini 2.5 Pro | Claude Sonnet 4.6 (standard) / Claude Opus 4.6 (architecture) |
| **Script** | `./scripts/ai_chat.sh` → option 1 or 2 | `./scripts/ai_chat.sh` → option 3 or 4 |
| **Staging folder** | `~/Downloads/gemini_session_documents/` | `~/Downloads/claude_session_documents/` |
| **GitHub repo link** | ✅ Required — paste as text | ❌ Not needed |
| **Standing instruction** | ✅ Required — script handles it | ❌ Not required |
| **Confirmation quiz** | ✅ Required — 5 questions | ❌ Not required |
| **Pre-flight audit role** | Receives audit results | Performs audit |
| **Session log** | Written on End | Written on End |

---

## Gemini Session Detail

### Session types

| Type | Use for |
|---|---|
| 1 — General coding | Cloud Functions, multi-file ASSISTED payloads |
| 2 — n8n orchestrator | Orchestrator node additions (attach current JSON) |
| 3 — Flutter UI | Dreamflow prep — attaches architecture and schema docs |
| 4 — Planning / architecture | Phase design, Horizon 2 planning |

### Model selection

| Task | Model |
|---|---|
| Cloud Functions, n8n workflows, multi-file ASSISTED payloads | **Gemini 2.5 Pro** |
| Simple single-file changes, commit message review, quick lookups | **Gemini 2.5 Flash** |
| Architecture planning, phase design | **Gemini 2.5 Pro** |

### Core documents (always attached — script handles this)

- `documents/gemini_cicd_briefing.md` — pipeline overview, commit format, n8n rules, relay.sh v6.4
- `documents/project_plan.md` — current roadmap and active phase
- `documents/ai_context_rules.md` — all hard rules for code generation
- `documents/cicd_pipeline_reference.md` — pipeline steps, webhook IDs, key files
- `documents/judge_layer_architecture.md` — action classification, ActionProposal schema, memory provenance

### Conditional documents (script adds based on session type)

| Session type | Additional documents |
|---|---|
| 2 — n8n orchestrator | Both orchestrator JSON files. Tell Gemini: "Add to this — do not replace it." |
| 3 — Flutter UI | `development_method_dreamflow.md`, `L2LAAF_flutter-first_architecture.md`, `firestore_schema.md` |
| 4 — Planning | `l2laaf_full_specification.md` |

### Quiz answer reference (Step 7)

| Q | Correct answer |
|---|---|
| 1 | `pubspec.yaml`. Version increments only on PROMOTE TO PROD. |
| 2 | Ask for the current file. Never generate from scratch. |
| 3 | Raw body + Code node + `JSON.stringify()`. Inline `jsonBody` serialises as `[object Object]`. |
| 4 | `main.json` untouched. v6.4 only deletes files explicitly listed in the payload. |
| 5 | `[SOURCE] TYPE(scope): Description`. No version prefix. No multi-line. |

---

## Claude Session Detail

### Session types

| Type | Use for |
|---|---|
| 1 — Pre-flight audit | Review a Gemini-generated payload before running relay.sh |
| 2 — Debugging | Diagnose errors, failed pipeline steps, n8n execution problems |
| 3 — Architecture | Phase planning, system design, judge layer decisions |
| 4 — Flutter review | Code review of Dreamflow-generated Dart files |
| 5 — Documentation | Update or write documents/ files |

### Model selection

| Task | Model |
|---|---|
| Pre-flight payload audit | **Claude Sonnet 4.6** |
| Architecture decisions, phase planning, judge layer design | **Claude Opus 4.6** |
| Debugging a specific error | **Claude Sonnet 4.6** |
| Writing or reviewing documentation | **Claude Sonnet 4.6** |
| Designing a new system component from scratch | **Claude Opus 4.6** |

### Core documents (always attached — script handles this)

- `documents/project_plan.md`
- `documents/ai_context_rules.md`
- `documents/judge_layer_architecture.md`

### Conditional documents (script adds based on session type)

| Session type | Additional documents |
|---|---|
| 1 & 2 | `cicd_pipeline_reference.md` |
| 3 | `cicd_pipeline_reference.md`, `l2laaf_full_specification.md`, `gemini_cicd_briefing.md` |
| 4 | `development_method_dreamflow.md` |
| 5 | `cicd_pipeline_reference.md` + any document being updated (drag in manually) |

### Pre-flight audit template (copied to clipboard automatically)

```
Audit this payload.

[PASTE FULL logic_payload.txt CONTENT HERE]

Known baseline:
- DEV orchestrator node count: [auto-filled by script]
- PROD orchestrator node count: [auto-filled by script]
- relay.sh version: [auto-filled by script]
- Current prod version: [auto-filled by script]

Check against all rules in ai_context_rules.md and judge_layer_architecture.md.
Return CLEARED (with any minor notes) or BLOCKED (with specific line-level issues and fixes).
```

---

## Full Session Workflow

```
BEFORE STARTING
  git pull --rebase origin develop   ← always sync first

START GEMINI
  ./scripts/ai_chat.sh → option 1
  → Select session type
  → Drag staging folder files into Gemini
  → Paste GitHub repo link
  → Script walks through instruction + opener + plan context (4 clipboard steps)
  → Verify 5 quiz answers
  → Do development work

GEMINI PRODUCES PAYLOAD
  → Copy payload content to scripts/logic_payload.txt

START CLAUDE (pre-flight audit)
  ./scripts/ai_chat.sh → option 3
  → Select type 1
  → Drag staging folder files into Claude
  → Script copies audit template to clipboard
  → Paste, add payload content, send
  → Receive CLEARED or BLOCKED

IF BLOCKED
  → Paste Claude's issues back to Gemini
  → Gemini corrects payload
  → Re-run Claude Start (option 3) to audit again

IF CLEARED
  → Run ./scripts/relay.sh
  → Watch GitHub Actions pipeline
  → Respond to HITL card in Google Chat

END CLAUDE
  ./scripts/ai_chat.sh → option 4
  → Save any updated documents to ~/Downloads/claude_session_documents/ first
  → Enter session summary
  → Select updated document numbers
  → Script commits and pushes

CONTINUE IN GEMINI OR END GEMINI
  → If continuing: do next task
  → If done: ./scripts/ai_chat.sh → option 2
    → Enter session summary
    → Select updated document numbers
    → Script commits, pushes, clears staging
```

---

## Document Location Reference

All documents live in `documents/` in the repo root. The scripts always copy from the current working tree — run `git pull --rebase origin develop` before starting a session to ensure documents are current.

| Document | Purpose | Always attach to |
|---|---|---|
| `gemini_cicd_briefing.md` | Full CI/CD briefing for Gemini | Gemini |
| `project_plan.md` | Roadmap and active phase | Both |
| `ai_context_rules.md` | Hard rules for code generation | Both |
| `cicd_pipeline_reference.md` | Pipeline steps, IDs, key files | Both (Gemini always, Claude conditional) |
| `judge_layer_architecture.md` | Action classification, ActionProposal, memory provenance | Both |
| `session_log.md` | Running log of all AI sessions | Neither (read-only reference) |
| `l2laaf_full_specification.md` | Full system specification | Conditional |
| `development_method_dreamflow.md` | Flutter/Dreamflow rules | Conditional |
| `development_method_assisted.md` | relay.sh and payload format | Conditional |
| `firestore_schema.md` | Firestore collections and field names | Conditional |
| `L2LAAF_flutter-first_architecture.md` | Flutter file structure | Conditional |

---

## Update this checklist when

- A new document is added to `documents/` that both AIs need (update script copy lists in `ai_chat.sh`)
- A new failure mode is discovered that should be added to the Gemini quiz or Claude audit checklist
- Session type options change
- The script's commit format changes

Note: relay.sh version, orchestrator node counts, and current version are all read dynamically by the script — no manual updates needed when these change.
