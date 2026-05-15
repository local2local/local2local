# L2LAAF AI Session Initiation Checklist

**Last updated:** 2026-05-14
**Purpose:** Step-by-step guide for starting Gemini and Claude sessions correctly every time.

---

## Quick Reference

| | Gemini | Claude |
|---|---|---|
| **Role** | Actor — generates code, payloads, n8n workflows | Judge / Architect — QA review, planning, debugging |
| **Preferred model** | Gemini 2.5 Pro | Claude Sonnet 4.6 (standard) / Claude Opus 4.6 (architecture) |
| **GitHub repo link** | ✅ Required | ❌ Not needed (paste content directly) |
| **Core docs always attached** | 5 documents | 3 documents |
| **Standing instruction** | Required — Part 1 of session setup | Not required — Claude holds context |
| **Confirmation quiz** | Required — 5 questions | Not required |
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

These five documents must be attached at the start of every Gemini session without exception:

- [ ] `documents/gemini_cicd_briefing.md` — pipeline overview, commit format, n8n orchestrator rules, body serialization rules, relay.sh v6.4 behaviour
- [ ] `documents/project_plan.md` — current roadmap, active phase, horizon 2 detail
- [ ] `documents/ai_context_rules.md` — all hard rules for code generation
- [ ] `documents/cicd_pipeline_reference.md` — pipeline steps, webhook IDs, key file locations
- [ ] `documents/judge_layer_architecture.md` — action classification, ActionProposal schema, four-outcome decision, memory provenance rules

### Step 3 — Attach session-type documents (conditional)

**If working on n8n orchestrator:**
- [ ] Current `n8n_workflows/l2laaf_autonomous_orchestrator.develop.json` (download from repo or copy from local)
- [ ] Current `n8n_workflows/l2laaf_autonomous_orchestrator.main.json` (same)

> Rule: Never let Gemini generate an orchestrator workflow without the current file as context. Attach it and say "Here is the current orchestrator. Add to this — do not replace it."

**If working on Cloud Functions:**
- [ ] `documents/firestore_schema.md`
- [ ] Current file content for every file being modified (copy-paste from Cursor)

**If working on Flutter UI:**
- [ ] `documents/development_method_dreamflow.md`
- [ ] `documents/L2LAAF_flutter-first_architecture.md`
- [ ] `documents/firestore_schema.md`
- [ ] Current file content for every file being modified

**If working on a new phase or planning:**
- [ ] `documents/l2laaf_full_specification.md`

### Step 4 — Provide GitHub repo link

- [ ] Paste: `https://github.com/local2local/local2local`

Gemini can read the repo structure and recent commits directly. This helps it understand the current state without requiring you to paste every file. Still attach the current version of any file it will modify — do not rely on Gemini reading it from GitHub for file content.

### Step 5 — Paste the standing instruction (Part 1 of `gemini_session_setup.md`)

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

### Step 6 — Paste the one-shot opener (Part 2 of `gemini_session_setup.md`)

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

Before proceeding, check Gemini's five answers against these correct responses:

| Question | Correct answer |
|---|---|
| 1 | `pubspec.yaml`. Version increments only on PROMOTE TO PROD — not on push to develop. |
| 2 | Ask the developer to provide the current orchestrator JSON. Never generate from scratch. |
| 3 | Raw body type + Code node using `JSON.stringify()`. Because inline `jsonBody` expressions serialise objects as `[object Object]`. |
| 4 | `main.json` is not touched. v6.4 only deletes files explicitly listed in the payload. |
| 5 | `[SOURCE] TYPE(scope): Description`. Never a version prefix. Never multi-line. |

If Gemini answers question 2 or 3 incorrectly, correct it before starting work. These are the two failure modes that caused the most regressions.

### Step 8 — Add plan context prompt (Part 4 of `gemini_session_setup.md`)

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
| Pre-flight payload audit (standard) | **Claude Sonnet 4.6** |
| Architecture decisions, phase planning, judge layer design | **Claude Opus 4.6** |
| Debugging a specific error, fixing a failing test | **Claude Sonnet 4.6** |
| Writing or reviewing documentation | **Claude Sonnet 4.6** |
| Designing a new system component from scratch | **Claude Opus 4.6** |

### Step 2 — Attach core documents (always)

- [ ] `documents/project_plan.md`
- [ ] `documents/ai_context_rules.md`
- [ ] `documents/judge_layer_architecture.md`

### Step 3 — Attach session-type documents (conditional)

**If doing a pre-flight payload audit:**
- [ ] The `logic_payload.txt` content (paste directly — no file needed)
- [ ] `documents/cicd_pipeline_reference.md`

**If debugging n8n orchestrator issues:**
- [ ] The relevant n8n execution JSON or screenshot description
- [ ] `documents/cicd_pipeline_reference.md`
- [ ] Current orchestrator JSON if available

**If doing architecture or planning work:**
- [ ] `documents/l2laaf_full_specification.md`
- [ ] `documents/cicd_pipeline_reference.md`
- [ ] `documents/gemini_cicd_briefing.md` (so Claude understands what Gemini has been told)

**If reviewing Flutter code:**
- [ ] `documents/development_method_dreamflow.md`
- [ ] The specific file content being reviewed

### Step 4 — GitHub repo link

- [ ] **Not required.** Claude works with content pasted directly into the conversation. The repo is private and Claude cannot authenticate to read it. Paste file content explicitly when needed.

### Step 5 — No standing instruction needed

Claude maintains context across the session and does not require a confirmation quiz. Start with the task directly.

**For a pre-flight audit, use this template:**

```
Audit this payload.

[paste logic_payload.txt content here]

Known baseline:
- DEV orchestrator node count: 51
- PROD orchestrator node count: 51
- relay.sh version: v6.4
- Current prod version: [current version]
- Active phase: [current phase]
```

**For architecture or planning:**

Start with the question. Claude has the project plan and will orient itself.

**For debugging:**

Paste the error output, the relevant file content, and describe what you expected vs what happened. Claude will diagnose and provide a fix.

---

## Session Workflow Summary

```
1. Open Gemini 2.5 Pro
   → Attach 5 core docs + session-type docs
   → Paste GitHub repo link
   → Paste standing instruction (Part 1)
   → Paste one-shot opener (Part 2)
   → Verify 5 answers
   → Paste plan context prompt (Part 4)
   → Do development work

2. Gemini produces logic_payload.txt
   → Copy payload content

3. Open Claude Sonnet 4.6
   → Attach 3 core docs
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

All documents live in `documents/` in the repo root. Current versions are always in `main` after promotion.

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

- relay.sh version changes (update baseline in audit template)
- Orchestrator node count changes (update baseline in audit template)
- Current prod version changes (update audit template before each session)
- A new document is added to `documents/` that both AIs need
- A new failure mode is discovered that should be added to the audit checklist
