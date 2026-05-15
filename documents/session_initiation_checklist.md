# L2LAAF AI Session Initiation Checklist

**Last updated:** 2026-05-14
**Purpose:** Step-by-step guide for starting Gemini and Claude sessions correctly every time.

---

## Quick Start

Both session scripts live in `scripts/` and must be run from the repo root.

### Gemini session

```zsh
./scripts/gemini_session.sh
```

1. Select session type (1–4) in the terminal
2. Script clears and populates `~/Downloads/gemini_session_documents/` with the correct files
3. Script opens Gemini (AI Studio) and the staging folder in Finder simultaneously
4. **Confirm model is Gemini 2.5 Pro** in AI Studio
5. Select all files in the Finder window (⌘A) and drag into the Gemini chat
6. Paste the GitHub repo link as text in the chat: `https://github.com/local2local/local2local`
7. Press Enter in the terminal — the script walks you through Steps 2–4, copying each prompt to clipboard one at a time (⌘V to paste each one, send, then press Enter to continue)
8. **Verify Gemini's 5 quiz answers** before starting work — answers are shown in the terminal

> If Gemini answers Q2 or Q3 incorrectly, correct it before continuing. These are the two failure modes that caused the most regressions.

### Claude session

```zsh
./scripts/claude_session.sh
```

1. Select session type (1–5) in the terminal
2. Script clears and populates `~/Downloads/claude_session_documents/` with the correct files
3. Script opens Claude (claude.ai/new) and the staging folder in Finder simultaneously
4. **Confirm model** — Sonnet 4.6 for audits and debugging, Opus 4.6 for architecture
5. Select all files in the Finder window (⌘A) and drag into the Claude chat
6. Press Enter in the terminal — the script copies the appropriate prompt template to clipboard
7. Paste into Claude (⌘V), fill in the placeholders, and send

> No quiz, no standing instruction, no GitHub link needed for Claude.

---

## Quick Reference

| | Gemini | Claude |
|---|---|---|
| **Role** | Actor — generates code, payloads, n8n workflows | Judge / Architect — QA review, planning, debugging |
| **Preferred model** | Gemini 2.5 Pro | Claude Sonnet 4.6 (standard) / Claude Opus 4.6 (architecture) |
| **Script** | `./scripts/gemini_session.sh` | `./scripts/claude_session.sh` |
| **Staging folder** | `~/Downloads/gemini_session_documents/` | `~/Downloads/claude_session_documents/` |
| **GitHub repo link** | ✅ Required — paste as text | ❌ Not needed |
| **Standing instruction** | ✅ Required — script handles it | ❌ Not required |
| **Confirmation quiz** | ✅ Required — 5 questions | ❌ Not required |
| **Pre-flight audit role** | Receives audit results | Performs audit |

---

## Gemini Session Checklist

### Step 1 — Choose the right model

| Task | Model |
|---|---|
| Cloud Functions, n8n workflows, multi-file ASSISTED payloads | **Gemini 2.5 Pro** |
| Simple single-file changes, commit message review, quick lookups | **Gemini 2.5 Flash** |
| Architecture planning, phase design | **Gemini 2.5 Pro** |

### Step 2 — Attach core documents (always)

These five documents are copied automatically by the script into `~/Downloads/gemini_session_documents/`:

- [ ] `documents/gemini_cicd_briefing.md` — pipeline overview, commit format, n8n orchestrator rules, body serialization rules, relay.sh v6.4 behaviour
- [ ] `documents/project_plan.md` — current roadmap, active phase, horizon 2 detail
- [ ] `documents/ai_context_rules.md` — all hard rules for code generation
- [ ] `documents/cicd_pipeline_reference.md` — pipeline steps, webhook IDs, key file locations
- [ ] `documents/judge_layer_architecture.md` — action classification, ActionProposal schema, four-outcome decision, memory provenance rules

### Step 3 — Attach session-type documents (conditional)

The script adds these automatically based on session type selection:

**If working on n8n orchestrator (type 2):**
- [ ] `n8n_workflows/l2laaf_autonomous_orchestrator.develop.json`
- [ ] `n8n_workflows/l2laaf_autonomous_orchestrator.main.json`

> Rule: Never let Gemini generate an orchestrator workflow without the current file as context. Tell Gemini: "Add to this file — do not replace it."

**If working on Flutter UI (type 3):**
- [ ] `documents/development_method_dreamflow.md`
- [ ] `documents/L2LAAF_flutter-first_architecture.md`
- [ ] `documents/firestore_schema.md`

**If working on phase planning / architecture (type 4):**
- [ ] `documents/l2laaf_full_specification.md`

### Step 4 — Provide GitHub repo link

- [ ] Paste as text in the chat: `https://github.com/local2local/local2local`

Gemini uses this to orient itself on repo structure and recent commits. Still attach the current version of any file it will modify — do not rely on Gemini reading file content from GitHub.

### Step 5 — Standing instruction

The script copies this to clipboard automatically. Paste (⌘V) and send:

```
You are working as a development assistant on the L2LAAF platform. Before we begin,
there are two standing rules that apply to every payload, commit message, or n8n
workflow change you generate in this session:

Rule 1 — Pre-flight audit. Every logic_payload.txt bundle you generate will be
reviewed by Claude AI before I run relay.sh. Claude runs a structured audit against
known failure modes for this codebase. Do not consider a payload complete or ready
to deploy until I confirm Claude has cleared it. If Claude flags issues, I will paste
them back to you for correction.

Rule 2 — Current file first. Before generating any change to an existing file —
especially n8n orchestrator JSON, relay.sh, or any Cloud Function — ask me to provide
the current file content. Never reconstruct a file from memory or generate it from
scratch. Work only from what I give you.

These two rules are non-negotiable and apply for the entire session.
```

### Step 6 — One-shot opener

The script copies this to clipboard automatically. Paste (⌘V) and send:

```
I am starting a new L2LAAF development session. Please read all attached documents
before responding.

After reading, confirm you have understood the following by answering each question:

1. What is the single source of truth for the version number, and when does it increment?
2. What must you do before generating any change to an n8n orchestrator workflow?
3. When building a Gemini API call in n8n, what body type and node pattern must you use, and why?
4. What happens to main.json if a payload only lists develop.json in relay.sh v6.4?
5. What is the correct commit message format, and what are two things that are never allowed?

Do not begin any development work until you have answered all five questions.
```

### Step 7 — Verify Gemini's answers

The correct responses are shown in the terminal. Reference:

| Question | Correct answer |
|---|---|
| 1 | `pubspec.yaml`. Version increments only on PROMOTE TO PROD — not on push to develop. |
| 2 | Ask the developer to provide the current orchestrator JSON. Never generate from scratch. |
| 3 | Raw body type + Code node using `JSON.stringify()`. Because inline `jsonBody` expressions serialise objects as `[object Object]`. |
| 4 | `main.json` is not touched. v6.4 only deletes files explicitly listed in the payload. |
| 5 | `[SOURCE] TYPE(scope): Description`. Never a version prefix. Never multi-line. |

If Gemini answers question 2 or 3 incorrectly, correct it before starting work.

### Step 8 — Plan context prompt

The script copies this to clipboard automatically. Paste (⌘V) and send:

```
Before we begin implementation, confirm you have read documents/project_plan.md.
Tell me: what phase are we currently in, what is the next phase after the current
one, and what is the single most important architectural decision we need to make
today that will affect Phase 46 or later?
```

---

## Claude Session Checklist

### Step 1 — Choose the right model

| Task | Model |
|---|---|
| Pre-flight payload audit | **Claude Sonnet 4.6** |
| Architecture decisions, phase planning, judge layer design | **Claude Opus 4.6** |
| Debugging a specific error | **Claude Sonnet 4.6** |
| Writing or reviewing documentation | **Claude Sonnet 4.6** |
| Designing a new system component from scratch | **Claude Opus 4.6** |

### Step 2 — Attach core documents (always)

These three documents are copied automatically by the script into `~/Downloads/claude_session_documents/`:

- [ ] `documents/project_plan.md`
- [ ] `documents/ai_context_rules.md`
- [ ] `documents/judge_layer_architecture.md`

### Step 3 — Attach session-type documents (conditional)

The script adds these automatically based on session type selection:

**Pre-flight audit or debugging (types 1 & 2):**
- [ ] `documents/cicd_pipeline_reference.md`

**Architecture / planning (type 3):**
- [ ] `documents/cicd_pipeline_reference.md`
- [ ] `documents/l2laaf_full_specification.md`
- [ ] `documents/gemini_cicd_briefing.md`

**Flutter code review (type 4):**
- [ ] `documents/development_method_dreamflow.md`

**Documentation update (type 5):**
- [ ] `documents/cicd_pipeline_reference.md`
- [ ] Any additional document being updated (drag in manually)

### Step 4 — GitHub repo link

**Not required.** Claude works with content pasted directly into the conversation. Paste file content explicitly when needed.

### Step 5 — No standing instruction needed

Claude maintains context across the session and does not require a confirmation quiz. Start with the task directly after attaching documents.

**For a pre-flight audit** — the script copies the audit template to clipboard with live baseline values (version, relay version, node counts). Paste into Claude, replace the placeholder with the full payload content, and send.

**For architecture or planning** — start with the question. Claude will orient itself from the attached documents.

**For debugging** — paste the error output, the relevant file content, and describe what you expected vs what happened.

---

## Session Workflow Summary

```
1. Run ./scripts/gemini_session.sh
   → Select session type
   → Drag ~/Downloads/gemini_session_documents/ files into Gemini
   → Paste GitHub repo link
   → Script walks through standing instruction + opener + plan context
   → Verify 5 quiz answers
   → Do development work

2. Gemini produces logic_payload.txt

3. Run ./scripts/claude_session.sh
   → Select type 1 (Pre-flight audit)
   → Drag ~/Downloads/claude_session_documents/ files into Claude
   → Paste audit template with payload content
   → Receive CLEARED or BLOCKED + issues

4. If BLOCKED:
   → Paste Claude's issues back to Gemini
   → Gemini corrects and produces new payload
   → Return to step 3

5. If CLEARED:
   → Copy payload to scripts/logic_payload.txt
   → Run ./scripts/relay.sh
   → Watch pipeline
   → Respond to HITL card

6. After HITL decision:
   → Return to Gemini with next task
   → Or select next design intent from SuperAdmin dashboard
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
| `l2laaf_full_specification.md` | Full system specification | Conditional |
| `development_method_dreamflow.md` | Flutter/Dreamflow rules | Conditional (Flutter sessions) |
| `development_method_assisted.md` | relay.sh and payload format | Conditional |
| `firestore_schema.md` | Firestore collections and field names | Conditional (backend sessions) |
| `L2LAAF_flutter-first_architecture.md` | Flutter file structure | Conditional (Flutter sessions) |

---

## Update this checklist when

- relay.sh version changes (script reads it dynamically — no manual update needed)
- Orchestrator node count changes (script reads it dynamically — no manual update needed)
- A new document is added to `documents/` that both AIs need (update script copy lists)
- A new failure mode is discovered that should be added to the Gemini quiz or Claude audit checklist
- Session type options change
