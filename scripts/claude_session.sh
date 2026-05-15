#!/bin/bash
# --- L2LAAF Claude Session Initializer ---
# Run from the repo root: ./scripts/claude_session.sh

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
STAGING_DIR="$HOME/Downloads/claude_session_documents"

# ─── Header ───────────────────────────────────────────────────────────────────
clear
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ⚖️   L2LAAF  Claude Session Setup      ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Version:    $VERSION"
echo "  relay.sh:   $RELAY_VERSION"
echo "  DEV nodes:  $DEV_NODES"
echo "  PROD nodes: $PROD_NODES"
echo ""

# ─── Session type ─────────────────────────────────────────────────────────────
echo "  Select session type:"
echo "  ─────────────────────────────────────────"
echo "  1  Pre-flight payload audit"
echo "  2  Debugging / error diagnosis"
echo "  3  Architecture / planning"
echo "  4  Flutter code review"
echo "  5  Document writing / update"
echo ""
read -p "  Enter choice [1-5]: " SESSION_TYPE
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
cp documents/project_plan.md             "$STAGING_DIR/"
cp documents/ai_context_rules.md         "$STAGING_DIR/"
cp documents/judge_layer_architecture.md "$STAGING_DIR/"

# Copy session-type-specific documents
case $SESSION_TYPE in
  1|2)
    cp documents/cicd_pipeline_reference.md "$STAGING_DIR/"
    ;;
  3)
    cp documents/cicd_pipeline_reference.md  "$STAGING_DIR/"
    cp documents/l2laaf_full_specification.md "$STAGING_DIR/"
    cp documents/gemini_cicd_briefing.md     "$STAGING_DIR/"
    ;;
  4)
    cp documents/development_method_dreamflow.md "$STAGING_DIR/"
    ;;
  5)
    cp documents/cicd_pipeline_reference.md "$STAGING_DIR/"
    ;;
esac

FILE_COUNT=$(ls "$STAGING_DIR" | wc -l | tr -d ' ')
echo "  ✅  $FILE_COUNT files ready in ~/Downloads/claude_session_documents/"
echo ""

# ─── Open tools ───────────────────────────────────────────────────────────────
echo "  🌐  Opening Claude..."
open "https://claude.ai/new"

echo "  📂  Opening staging folder in Finder..."
open "$STAGING_DIR"

sleep 1

# ─── Document checklist ───────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  STEP 1 — Drag all files into Claude     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  All files are in the Finder window that just opened."
echo "  Select all (⌘A) and drag them into the Claude chat."
echo ""
echo "  Files included:"
ls "$STAGING_DIR" | sed 's/^/  ✦  /'
echo ""

if [ "$SESSION_TYPE" = "5" ]; then
  echo "  Also drag any additional document(s) you are updating."
  echo ""
fi

echo "  NOTE: No GitHub repo link needed — paste file content directly."
echo ""
read -p "  ✋  Press Enter when documents are attached..."

# ─── Session-specific prompt ──────────────────────────────────────────────────
echo ""

if [ "$SESSION_TYPE" = "1" ]; then

  echo "╔══════════════════════════════════════════╗"
  echo "║  STEP 2 — Payload audit                  ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Open your logic_payload.txt now."
  echo "  The audit template (with live baseline values) will be"
  echo "  copied to clipboard. Paste into Claude and replace the"
  echo "  placeholder with your full payload content."
  echo ""
  read -p "  ✋  Press Enter when logic_payload.txt is open..."

  AUDIT_TEMPLATE="Audit this payload.

[PASTE FULL logic_payload.txt CONTENT HERE — replace this line]

Known baseline:
- DEV orchestrator node count: $DEV_NODES
- PROD orchestrator node count: $PROD_NODES
- relay.sh version: $RELAY_VERSION
- Current prod version: $VERSION

Check against all rules in ai_context_rules.md and judge_layer_architecture.md.
Return CLEARED (with any minor notes) or BLOCKED (with specific line-level issues and fixes)."

  printf '%s' "$AUDIT_TEMPLATE" | pbcopy

  echo ""
  echo "  Audit template copied to clipboard ✓"
  echo "  → Paste in Claude (⌘V)"
  echo "  → Replace [PASTE FULL logic_payload.txt...] with your payload"
  echo "  → Send to Claude"
  echo ""
  echo "  Claude will return CLEARED or BLOCKED + specific issues."
  echo ""
  echo "  If CLEARED  →  run ./scripts/relay.sh"
  echo "  If BLOCKED  →  paste Claude's issues back to Gemini"
  echo "              →  re-run this script when corrected payload is ready"

elif [ "$SESSION_TYPE" = "2" ]; then

  printf '%s' "Diagnose this issue in the L2LAAF codebase.

Error output:
[PASTE ERROR OUTPUT HERE]

Relevant file content:
[PASTE FILE CONTENT HERE]

Expected behaviour:
[DESCRIBE WHAT YOU EXPECTED]

Actual behaviour:
[DESCRIBE WHAT HAPPENED]" | pbcopy

  echo "╔══════════════════════════════════════════╗"
  echo "║  STEP 2 — Debug template                 ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Copied to clipboard ✓"
  echo "  → Paste in Claude (⌘V)"
  echo "  → Fill in error output, file content, and behaviour"
  echo "  → Send to Claude"

elif [ "$SESSION_TYPE" = "3" ]; then

  echo "╔══════════════════════════════════════════╗"
  echo "║  STEP 2 — Architecture session           ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Start with your question directly — no template needed."
  echo "  Claude will orient itself from the attached documents."
  echo ""
  echo "  Recommended model for architecture work: Claude Opus 4.6"
  echo "  (Switch via the model selector in claude.ai)"

elif [ "$SESSION_TYPE" = "4" ]; then

  printf '%s' "Review this Flutter/Dart code for the L2LAAF codebase.

File: [FILE PATH]

[PASTE FILE CONTENT HERE]

Concern:
[DESCRIBE WHAT YOU WANT REVIEWED]" | pbcopy

  echo "╔══════════════════════════════════════════╗"
  echo "║  STEP 2 — Flutter review template        ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Copied to clipboard ✓"
  echo "  → Paste in Claude (⌘V)"
  echo "  → Fill in file path, content, and concern"
  echo "  → Send to Claude"

elif [ "$SESSION_TYPE" = "5" ]; then

  echo "╔══════════════════════════════════════════╗"
  echo "║  STEP 2 — Documentation session          ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Describe what needs to change in the document and why."
  echo "  Claude will produce updated content ready to commit."

fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅  CLAUDE SESSION READY                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
