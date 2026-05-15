#!/bin/bash
# --- L2LAAF AI Chat Manager ---
# Run from the repo root: ./scripts/ai_chat.sh

# ─── Guard: must run from repo root ───────────────────────────────────────────
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Run this script from the repo root (where pubspec.yaml lives)."
  exit 1
fi

# ─── Dynamic values from repo ─────────────────────────────────────────────────
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
RELAY_VERSION=$(grep -m1 'RELAY v' scripts/relay.sh | grep -oE 'v[0-9]+\.[0-9]+' 2>/dev/null || echo "unknown")
DEV_NODES=$(jq '[.nodes[].name] | length' n8n_workflows/l2laaf_autonomous_orchestrator.develop.json 2>/dev/null || echo "unknown")
PROD_NODES=$(jq '[.nodes[].name] | length' n8n_workflows/l2laaf_autonomous_orchestrator.main.json 2>/dev/null || echo "unknown")
ACTIVE_PHASE=$(grep -m1 'IN PROGRESS' documents/project_plan.md | grep -oE '[0-9]+\.[0-9]+' | head -1 2>/dev/null || echo "45")
SESSION_LOG="documents/session_log.md"
GEMINI_STAGING="$HOME/Downloads/gemini_session_documents"
CLAUDE_STAGING="$HOME/Downloads/claude_session_documents"

# ─── Shared: commit documents ──────────────────────────────────────────────────
commit_documents() {
  local AI_NAME="$1"
  local SUMMARY="$2"

  # List all documents/ files for selection
  echo ""
  echo "  Which documents were updated during this session?"
  echo "  (Enter comma-separated numbers, or press Enter to skip)"
  echo ""
  local i=1
  local doc_list=()
  while IFS= read -r f; do
    printf "  %2d  %s\n" "$i" "$(basename "$f")"
    doc_list+=("$f")
    ((i++))
  done < <(find documents -maxdepth 1 -name "*.md" | sort)
  echo ""
  read -p "  Numbers: " DOC_SELECTION
  echo ""

  local UPDATED_DOCS=""
  local DOCS_COMMITTED=false

  if [ -n "$DOC_SELECTION" ]; then
    # Pull updated files from staging folder if present, otherwise leave as-is
    IFS=',' read -ra SELECTIONS <<< "$DOC_SELECTION"
    for sel in "${SELECTIONS[@]}"; do
      sel=$(echo "$sel" | tr -d ' ')
      if [[ "$sel" =~ ^[0-9]+$ ]]; then
        local idx=$((sel - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#doc_list[@]}" ]; then
          local doc_path="${doc_list[$idx]}"
          local doc_name=$(basename "$doc_path")
          local staging_file=""

          # Check staging folders for a newer version
          if [ "$AI_NAME" = "Claude" ] && [ -f "$CLAUDE_STAGING/$doc_name" ]; then
            staging_file="$CLAUDE_STAGING/$doc_name"
          elif [ "$AI_NAME" = "Gemini" ] && [ -f "$GEMINI_STAGING/$doc_name" ]; then
            staging_file="$GEMINI_STAGING/$doc_name"
          fi

          if [ -n "$staging_file" ]; then
            cp "$staging_file" "$doc_path"
            echo "  ✅  Copied updated $doc_name from staging folder"
          else
            echo "  ℹ️   $doc_name — marked as updated (no staging copy found, using repo version)"
          fi

          UPDATED_DOCS="${UPDATED_DOCS}${doc_name}, "
          DOCS_COMMITTED=true
        fi
      fi
    done
    UPDATED_DOCS="${UPDATED_DOCS%, }"
  fi

  # Write session log entry
  if [ ! -f "$SESSION_LOG" ]; then
    echo "# L2LAAF Session Log" > "$SESSION_LOG"
    echo "" >> "$SESSION_LOG"
    echo "Running record of AI chat sessions. Most recent at top." >> "$SESSION_LOG"
    echo "" >> "$SESSION_LOG"
    echo "---" >> "$SESSION_LOG"
    echo "" >> "$SESSION_LOG"
  fi

  local DATE_STR=$(date '+%Y-%m-%d %H:%M MT')
  local LOG_ENTRY="## $DATE_STR — $AI_NAME Session

**Phase:** $ACTIVE_PHASE
**Version:** $VERSION
**Summary:** $SUMMARY
**Documents updated:** ${UPDATED_DOCS:-none}

---

"
  # Prepend new entry after header (after line 5)
  local TMP=$(mktemp)
  head -6 "$SESSION_LOG" > "$TMP"
  printf '%s' "$LOG_ENTRY" >> "$TMP"
  tail -n +7 "$SESSION_LOG" >> "$TMP"
  mv "$TMP" "$SESSION_LOG"

  echo "  📝  Session logged to documents/session_log.md"
  echo ""

  # Stash dart_tool changes so they don't block the commit
  git stash --quiet 2>/dev/null || true

  # Stage and commit
  git add documents/
  if git diff --cached --quiet; then
    echo "  ℹ️   No document changes to commit."
  else
    local COMMIT_MSG="[MANUAL] CHORE(docs): $AI_NAME session end — $SUMMARY"
    git commit -m "$COMMIT_MSG"
    echo "  ✅  Committed: $COMMIT_MSG"

    echo ""
    echo "  📡  Pushing to origin/develop..."
    if git push origin develop; then
      echo "  ✅  Pushed successfully."
    else
      echo "  ⚠️  Remote is ahead — rebasing..."
      git pull --rebase origin develop && git push origin develop || \
        echo "  ❌  Push failed. Run 'git pull --rebase origin develop && git push origin develop' manually."
    fi
  fi

  # Restore stash if any
  git stash pop --quiet 2>/dev/null || true
}

# ─── Shared: clear staging folder ─────────────────────────────────────────────
clear_staging() {
  local DIR="$1"
  if [ -d "$DIR" ]; then
    rm -f "$DIR"/*
    echo "  🗑   Cleared $(basename "$DIR")"
  fi
}

# ─── Shared: prepare staging folder ───────────────────────────────────────────
prepare_staging() {
  local DIR="$1"
  shift
  if [ -d "$DIR" ]; then
    rm -f "$DIR"/*
  else
    mkdir -p "$DIR"
  fi
  for src in "$@"; do
    if [ -f "$src" ]; then
      cp "$src" "$DIR/"
    else
      echo "  ⚠️  Not found: $src"
    fi
  done
  local COUNT=$(ls "$DIR" | wc -l | tr -d ' ')
  echo "  ✅  $COUNT files ready in $(basename "$DIR")/"
}

# ═══════════════════════════════════════════════════════════════════════════════
# GEMINI START
# ═══════════════════════════════════════════════════════════════════════════════
gemini_start() {
  clear
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║   🤖  Gemini Session — Start             ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Version:       $VERSION"
  echo "  relay.sh:      $RELAY_VERSION"
  echo "  DEV nodes:     $DEV_NODES"
  echo "  PROD nodes:    $PROD_NODES"
  echo "  Active phase:  $ACTIVE_PHASE"
  echo ""

  echo "  Select session type:"
  echo "  ─────────────────────────────────────────"
  echo "  1  General coding  (Cloud Functions / ASSISTED payload)"
  echo "  2  n8n orchestrator work"
  echo "  3  Flutter UI  (Dreamflow prep)"
  echo "  4  Phase planning / architecture"
  echo ""
  read -p "  Enter choice [1-4]: " SESSION_TYPE
  echo ""

  echo "  🗂   Preparing staging folder..."
  local DOCS=(
    "documents/gemini_cicd_briefing.md"
    "documents/project_plan.md"
    "documents/ai_context_rules.md"
    "documents/cicd_pipeline_reference.md"
    "documents/judge_layer_architecture.md"
  )
  case $SESSION_TYPE in
    2) DOCS+=("n8n_workflows/l2laaf_autonomous_orchestrator.develop.json"
              "n8n_workflows/l2laaf_autonomous_orchestrator.main.json") ;;
    3) DOCS+=("documents/development_method_dreamflow.md"
              "documents/L2LAAF_flutter-first_architecture.md"
              "documents/firestore_schema.md") ;;
    4) DOCS+=("documents/l2laaf_full_specification.md") ;;
  esac
  prepare_staging "$GEMINI_STAGING" "${DOCS[@]}"
  echo ""
  echo "  Files included:"
  ls "$GEMINI_STAGING" | sed 's/^/  ✦  /'
  echo ""

  echo "  📂  Opening staging folder in Finder..."
  open "$GEMINI_STAGING"
  echo "  🌐  Opening Gemini 2.5 Pro in AI Studio..."
  open "https://aistudio.google.com/prompts/new_chat"
  sleep 1

  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║  STEP 1 — Drag all files into Gemini     ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Select all (⌘A) in the Finder window and drag into Gemini."
  echo ""
  [ "$SESSION_TYPE" = "2" ] && echo "  ⚠️  Tell Gemini: 'Add to this file — do not replace it.'" && echo ""
  echo "  Then paste this repo link as text in the chat:"
  echo "  ➜  https://github.com/local2local/local2local"
  echo ""
  read -p "  ✋  Press Enter when files are attached and repo link is pasted..."

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
  echo "  Verify Gemini's 5 answers:"
  echo "  ┌──────────────────────────────────────────────────────────────────┐"
  echo "  │  Q1  pubspec.yaml. Increments only on PROMOTE TO PROD.          │"
  echo "  │  Q2  Ask for current file. Never generate from scratch.          │"
  echo "  │  Q3  Raw body + Code node + JSON.stringify(). Inline =          │"
  echo "  │      [object Object].                                            │"
  echo "  │  Q4  main.json untouched. v6.4 only deletes listed files.       │"
  echo "  │  Q5  [SOURCE] TYPE(scope): Description. No version prefix.      │"
  echo "  │      No multi-line.                                              │"
  echo "  └──────────────────────────────────────────────────────────────────┘"
  echo ""
  echo "  ⚠️  If Q2 or Q3 are wrong — correct Gemini before continuing."
  echo ""
  read -p "  ✋  Press Enter when all 5 answers are verified..."

  printf '%s' "Before we begin implementation, confirm you have read documents/project_plan.md. Tell me: what phase are we currently in, what is the next phase after the current one, and what is the single most important architectural decision we need to make today that will affect Phase 46 or later?" | pbcopy

  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║  STEP 4 — Paste plan context             ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Copied to clipboard ✓  →  Paste in Gemini (⌘V) and send."
  echo ""
  read -p "  ✋  Press Enter when Gemini has oriented itself to the plan..."

  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║  ✅  GEMINI SESSION READY                ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  When Gemini produces a payload:"
  echo "  1. Copy logic_payload.txt content"
  echo "  2. Run ./scripts/ai_chat.sh → option 4 (Claude Start)"
  echo "  3. Select type 1 (Pre-flight audit)"
  echo "  4. If CLEARED → run ./scripts/relay.sh"
  echo "  5. If BLOCKED → paste Claude's issues back to Gemini"
  echo ""
  echo "  Audit baseline:  Version $VERSION  |  relay $RELAY_VERSION  |  DEV $DEV_NODES nodes  |  PROD $PROD_NODES nodes"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# GEMINI END
# ═══════════════════════════════════════════════════════════════════════════════
gemini_end() {
  clear
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║   🤖  Gemini Session — End               ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Version: $VERSION  |  Phase: $ACTIVE_PHASE"
  echo ""

  read -p "  One-line summary of what was accomplished: " SESSION_SUMMARY
  echo ""

  commit_documents "Gemini" "$SESSION_SUMMARY"

  echo ""
  echo "  🗑   Clearing staging folder..."
  clear_staging "$GEMINI_STAGING"

  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║  ✅  GEMINI SESSION CLOSED               ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Session logged. Documents committed. Staging folder cleared."
  echo "  Run ./scripts/ai_chat.sh to start the next session."
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLAUDE START
# ═══════════════════════════════════════════════════════════════════════════════
claude_start() {
  clear
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║   ⚖️   Claude Session — Start            ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Version:    $VERSION"
  echo "  relay.sh:   $RELAY_VERSION"
  echo "  DEV nodes:  $DEV_NODES"
  echo "  PROD nodes: $PROD_NODES"
  echo ""

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

  echo "  🗂   Preparing staging folder..."
  local DOCS=(
    "documents/project_plan.md"
    "documents/ai_context_rules.md"
    "documents/judge_layer_architecture.md"
  )
  case $SESSION_TYPE in
    1|2) DOCS+=("documents/cicd_pipeline_reference.md") ;;
    3)   DOCS+=("documents/cicd_pipeline_reference.md"
                "documents/l2laaf_full_specification.md"
                "documents/gemini_cicd_briefing.md") ;;
    4)   DOCS+=("documents/development_method_dreamflow.md") ;;
    5)   DOCS+=("documents/cicd_pipeline_reference.md") ;;
  esac
  prepare_staging "$CLAUDE_STAGING" "${DOCS[@]}"
  echo ""
  echo "  Files included:"
  ls "$CLAUDE_STAGING" | sed 's/^/  ✦  /'
  echo ""
  [ "$SESSION_TYPE" = "5" ] && echo "  Also drag any document being updated from documents/ into Claude." && echo ""

  echo "  🌐  Opening Claude..."
  open "https://claude.ai/new"
  echo "  📂  Opening staging folder in Finder..."
  open "$CLAUDE_STAGING"
  sleep 1

  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║  STEP 1 — Drag all files into Claude     ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Select all (⌘A) in the Finder window and drag into Claude."
  echo "  No GitHub repo link needed."
  echo ""

  case $SESSION_TYPE in
    1)
      echo "  Model: Claude Sonnet 4.6"
      echo ""
      read -p "  ✋  Press Enter when documents are attached..."
      echo ""
      echo "╔══════════════════════════════════════════╗"
      echo "║  STEP 2 — Payload audit template         ║"
      echo "╚══════════════════════════════════════════╝"
      echo ""
      echo "  Open your logic_payload.txt now."
      read -p "  ✋  Press Enter when logic_payload.txt is open..."
      printf '%s' "Audit this payload.

[PASTE FULL logic_payload.txt CONTENT HERE — replace this line]

Known baseline:
- DEV orchestrator node count: $DEV_NODES
- PROD orchestrator node count: $PROD_NODES
- relay.sh version: $RELAY_VERSION
- Current prod version: $VERSION

Check against all rules in ai_context_rules.md and judge_layer_architecture.md.
Return CLEARED (with any minor notes) or BLOCKED (with specific line-level issues and fixes)." | pbcopy
      echo ""
      echo "  Audit template copied to clipboard ✓"
      echo "  → Paste in Claude (⌘V)"
      echo "  → Replace [PASTE FULL...] with your payload content"
      echo "  → Send"
      echo ""
      echo "  If CLEARED  →  run ./scripts/relay.sh"
      echo "  If BLOCKED  →  paste issues back to Gemini, then re-run this script"
      ;;
    2)
      echo "  Model: Claude Sonnet 4.6"
      echo ""
      read -p "  ✋  Press Enter when documents are attached..."
      printf '%s' "Diagnose this issue in the L2LAAF codebase.

Error output:
[PASTE ERROR OUTPUT HERE]

Relevant file content:
[PASTE FILE CONTENT HERE]

Expected behaviour:
[DESCRIBE WHAT YOU EXPECTED]

Actual behaviour:
[DESCRIBE WHAT HAPPENED]" | pbcopy
      echo ""
      echo "  Debug template copied to clipboard ✓"
      echo "  → Paste in Claude (⌘V), fill in the placeholders, send"
      ;;
    3)
      echo "  Model: Claude Opus 4.6  (switch in claude.ai model selector)"
      echo ""
      read -p "  ✋  Press Enter when documents are attached..."
      echo ""
      echo "  Start with your question directly — no template needed."
      echo "  Claude will orient itself from the attached documents."
      ;;
    4)
      echo "  Model: Claude Sonnet 4.6"
      echo ""
      read -p "  ✋  Press Enter when documents are attached..."
      printf '%s' "Review this Flutter/Dart code for the L2LAAF codebase.

File: [FILE PATH]

[PASTE FILE CONTENT HERE]

Concern:
[DESCRIBE WHAT YOU WANT REVIEWED]" | pbcopy
      echo ""
      echo "  Flutter review template copied to clipboard ✓"
      echo "  → Paste in Claude (⌘V), fill in the placeholders, send"
      ;;
    5)
      echo "  Model: Claude Sonnet 4.6"
      echo ""
      read -p "  ✋  Press Enter when documents are attached..."
      echo ""
      echo "  Describe what needs to change in the document and why."
      echo "  Claude will produce updated content ready to commit."
      ;;
  esac

  echo ""
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║  ✅  CLAUDE SESSION READY                ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLAUDE END
# ═══════════════════════════════════════════════════════════════════════════════
claude_end() {
  clear
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║   ⚖️   Claude Session — End              ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Version: $VERSION  |  Phase: $ACTIVE_PHASE"
  echo ""

  echo "  If Claude produced updated document files during this session,"
  echo "  save them to ~/Downloads/claude_session_documents/ now."
  echo "  The script will copy them into documents/ automatically."
  echo ""
  read -p "  ✋  Press Enter when any updated files are saved to the staging folder..."
  echo ""

  read -p "  One-line summary of what was accomplished: " SESSION_SUMMARY
  echo ""

  commit_documents "Claude" "$SESSION_SUMMARY"

  echo ""
  echo "  🗑   Clearing staging folder..."
  clear_staging "$CLAUDE_STAGING"

  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║  ✅  CLAUDE SESSION CLOSED               ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Session logged. Documents committed. Staging folder cleared."
  echo "  Run ./scripts/ai_chat.sh to start the next session."
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════════════════════
clear
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       L2LAAF  AI Chat Manager            ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Version: $VERSION  |  Phase: $ACTIVE_PHASE  |  relay.sh: $RELAY_VERSION"
echo ""
echo "  Select AI action:"
echo "  ─────────────────────────────────────────"
echo "  1  Gemini AI chat — Start"
echo "  2  Gemini AI chat — End"
echo "  3  Claude AI chat — Start"
echo "  4  Claude AI chat — End"
echo "  5  Cancel"
echo ""
read -p "  Enter choice [1-5]: " ACTION
echo ""

case $ACTION in
  1) gemini_start ;;
  2) gemini_end ;;
  3) claude_start ;;
  4) claude_end ;;
  5) echo "  Cancelled." ; echo "" ; exit 0 ;;
  *) echo "  ❌ Invalid choice." ; echo "" ; exit 1 ;;
esac
