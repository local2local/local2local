#!/bin/bash
# --- L2LAAF Gemini Session Initializer ---
# Run from the repo root: ./scripts/gemini_session.sh

set -e

# ─── Guard: must run from repo root ───────────────────────────────────────────
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Run this script from the repo root (where pubspec.yaml lives)."
  exit 1
fi

# ─── Dynamic values from repo ─────────────────────────────────────────────────
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
RELAY_VERSION=$(grep -m1 'RELAY v' scripts/relay.sh | grep -oE 'v[0-9]+\.[0-9]+' || echo "unknown")
DEV_NODES=$(jq '[.nodes[].name] | length' n8n_workflows/l2laaf_autonomous_orchestrator.develop.json 2>/dev/null || echo "unknown")
PROD_NODES=$(jq '[.nodes[].name] | length' n8n_workflows/l2laaf_autonomous_orchestrator.main.json 2>/dev/null || echo "unknown")
ACTIVE_PHASE=$(grep -m1 'IN PROGRESS' documents/project_plan.md | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "45")
STAGING_DIR="$HOME/Downloads/gemini_session_documents"

# ─── Header ───────────────────────────────────────────────────────────────────
clear
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   🤖  L2LAAF  Gemini Session Setup       ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Version:       $VERSION"
echo "  relay.sh:      $RELAY_VERSION"
echo "  DEV nodes:     $DEV_NODES"
echo "  PROD nodes:    $PROD_NODES"
echo "  Active phase:  $ACTIVE_PHASE"
echo ""

# ─── Session type ─────────────────────────────────────────────────────────────
echo "  Select session type:"
echo "  ─────────────────────────────────────────"
echo "  1  General coding  (Cloud Functions / ASSISTED payload)"
echo "  2  n8n orchestrator work"
echo "  3  Flutter UI  (Dreamflow prep)"
echo "  4  Phase planning / architecture"
echo ""
read -p "  Enter choice [1-4]: " SESSION_TYPE
echo ""

# ─── Prepare staging folder ───────────────────────────────────────────────────
echo "  🗂   Preparing document staging folder..."

# Clear and recreate staging folder
if [ -d "$STAGING_DIR" ]; then
  rm -f "$STAGING_DIR"/*
else
  mkdir -p "$STAGING_DIR"
fi

# Copy core documents (every session)
cp documents/gemini_cicd_briefing.md     "$STAGING_DIR/"
cp documents/project_plan.md             "$STAGING_DIR/"
cp documents/ai_context_rules.md         "$STAGING_DIR/"
cp documents/cicd_pipeline_reference.md  "$STAGING_DIR/"
cp documents/judge_layer_architecture.md "$STAGING_DIR/"

# Copy session-type-specific documents
case $SESSION_TYPE in
  2)
    cp n8n_workflows/l2laaf_autonomous_orchestrator.develop.json "$STAGING_DIR/"
    cp n8n_workflows/l2laaf_autonomous_orchestrator.main.json    "$STAGING_DIR/"
    ;;
  3)
    cp documents/development_method_dreamflow.md         "$STAGING_DIR/"
    cp documents/L2LAAF_flutter-first_architecture.md    "$STAGING_DIR/"
    cp documents/firestore_schema.md                     "$STAGING_DIR/"
    ;;
  4)
    cp documents/l2laaf_full_specification.md "$STAGING_DIR/"
    ;;
esac

FILE_COUNT=$(ls "$STAGING_DIR" | wc -l | tr -d ' ')
echo "  ✅  $FILE_COUNT files ready in ~/Downloads/gemini_session_documents/"
echo ""

# ─── Open tools ───────────────────────────────────────────────────────────────
echo "  📂  Opening staging folder in Finder..."
open "$STAGING_DIR"

echo "  🌐  Opening Gemini 2.5 Pro..."
open "https://aistudio.google.com/prompts/new_chat"

sleep 1

# ─── Document checklist ───────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  STEP 1 — Drag all files into Gemini     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  All files are in the Finder window that just opened."
echo "  Select all (⌘A) and drag them into the Gemini chat."
echo ""
echo "  Files included:"
ls "$STAGING_DIR" | sed 's/^/  ✦  /'
echo ""

if [ "$SESSION_TYPE" = "2" ]; then
  echo "  ⚠️  For orchestrator files — tell Gemini:"
  echo "  'Add to this file — do not replace it.'"
  echo ""
fi

echo "  GitHub repo (paste as a link in the chat, do not attach):"
echo "  ➜  https://github.com/local2local/local2local"
echo ""
read -p "  ✋  Press Enter when all files are attached and repo link pasted..."

# ─── Standing instruction ─────────────────────────────────────────────────────
printf '%s' "You are working as a development assistant on the L2LAAF platform. Before we begin, there are two standing rules that apply to every payload, commit message, or n8n workflow change you generate in this session:

Rule 1 — Pre-flight audit. Every logic_payload.txt bundle you generate will be reviewed by Claude AI before I run relay.sh. Claude runs a structured audit against known failure modes for this codebase. Do not consider a payload complete or ready to deploy until I confirm Claude has cleared it. If Claude flags issues, I will paste them back to you for correction.

Rule 2 — Current file first. Before generating any change to an existing file — especially n8n orchestrator JSON, relay.sh, or any Cloud Function — ask me to provide the current file content. Never reconstruct a file from memory or generate it from scratch. Work only from what I give you.

These two rules are non-negotiable and apply for the entire session." | pbcopy

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  STEP 2 — Paste standing instruction     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Copied to clipboard ✓  →  Paste in Gemini (⌘V) and send."
echo ""
read -p "  ✋  Press Enter when Gemini has acknowledged..."

# ─── One-shot opener ──────────────────────────────────────────────────────────
printf '%s' "I am starting a new L2LAAF development session. Please read all attached documents before responding.

After reading, confirm you have understood the following by answering each question:

1. What is the single source of truth for the version number, and when does it increment?
2. What must you do before generating any change to an n8n orchestrator workflow?
3. When building a Gemini API call in n8n, what body type and node pattern must you use, and why?
4. What happens to main.json if a payload only lists develop.json in relay.sh v6.4?
5. What is the correct commit message format, and what are two things that are never allowed?

Do not begin any development work until you have answered all five questions." | pbcopy

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  STEP 3 — Paste session opener           ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Copied to clipboard ✓  →  Paste in Gemini (⌘V) and send."
echo ""
echo "  Verify Gemini's 5 answers against these correct responses:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  Q1  pubspec.yaml. Increments only on PROMOTE TO PROD.         │"
echo "  │  Q2  Ask for current file. Never generate from scratch.         │"
echo "  │  Q3  Raw body + Code node + JSON.stringify(). Inline =         │"
echo "  │      [object Object].                                           │"
echo "  │  Q4  main.json untouched. v6.4 only deletes listed files.      │"
echo "  │  Q5  [SOURCE] TYPE(scope): Description. No version prefix.     │"
echo "  │      No multi-line.                                             │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  ⚠️  If Q2 or Q3 are wrong — correct Gemini before continuing."
echo ""
read -p "  ✋  Press Enter when all 5 answers are verified..."

# ─── Plan context ─────────────────────────────────────────────────────────────
printf '%s' "Before we begin implementation, confirm you have read documents/project_plan.md. Tell me: what phase are we currently in, what is the next phase after the current one, and what is the single most important architectural decision we need to make today that will affect Phase 46 or later?" | pbcopy

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  STEP 4 — Paste plan context             ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Copied to clipboard ✓  →  Paste in Gemini (⌘V) and send."
echo ""
read -p "  ✋  Press Enter when Gemini has oriented itself to the plan..."

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅  GEMINI SESSION READY                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  When Gemini produces a payload:"
echo "  1. Copy logic_payload.txt content"
echo "  2. Run:  ./scripts/claude_session.sh"
echo "  3. Select option 1 (Pre-flight audit)"
echo "  4. If CLEARED → run ./scripts/relay.sh"
echo "  5. If BLOCKED → paste Claude's issues back to Gemini"
echo ""
echo "  Baseline for Claude audit template:"
echo "  ─────────────────────────────────────────"
echo "  Version:    $VERSION"
echo "  relay.sh:   $RELAY_VERSION"
echo "  DEV nodes:  $DEV_NODES"
echo "  PROD nodes: $PROD_NODES"
echo ""
