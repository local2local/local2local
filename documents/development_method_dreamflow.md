# Development Method: Dreamflow

**Source tag:** `[DREAM]`  
**Tooling:** Dreamflow AI agent + Cursor IDE (for integration)  
**Use cases:** Flutter UI/UX feature development, screen scaffolding, widget implementation, theme changes, navigation updates

---

## Overview

The Dreamflow method uses the Dreamflow AI agent to generate Flutter/Dart code for UI and UX features. Dreamflow operates within the Dreamflow canvas environment and produces production-ready Flutter code that follows the L2LAAF flutter-first architecture. The developer takes the generated code, integrates it into the repo, and pushes it through the standard CI/CD pipeline.

Dreamflow is the primary tool for anything visual — new screens, widget libraries, navigation flows, and theme changes. Backend logic, Cloud Functions, and pipeline changes always use the Manual or Assisted method instead.

---

## Dreamflow AI Agent

Dreamflow has a built-in Claude Opus AI agent accessible from the right panel of the Dreamflow canvas. The agent can make rapid UI changes by accepting natural language prompts and modifying the Flutter code directly in Dreamflow's environment.

### Workflow

```
Describe UI change to Dreamflow agent
    → Agent modifies Flutter code in Dreamflow
    → Preview updates live in the canvas
    → Iterate with further prompts or revert to a thread checkpoint
    → When satisfied: commit with [DREAM] source tag
    → CI/CD pipeline: Bump Version → Build → Deploy → HITL gate
```

### Thread checkpoints

Dreamflow saves checkpoints between agent interactions. If a change produces an unsatisfactory result, you can revert to a previous checkpoint without affecting git history. Use checkpoints liberally — they are the Dreamflow equivalent of local `git stash`.

### Direct code editing

When the agent is not the right tool for a precise change, Dreamflow's code editor allows direct Flutter file editing. This is useful for surgical fixes, import corrections, or changes that require exact Dart syntax the agent struggles with.

---

## Architecture constraints for Dreamflow

Dreamflow generates code that must conform to the L2LAAF flutter-first architecture. When prompting Dreamflow, the following constraints apply:

**File structure** — all Flutter code lives in `lib/` using feature-first organisation:

```
lib/
├── features/{feature}/
│   ├── data/           # Firestore repositories
│   ├── domain/         # Freezed models
│   └── presentation/   # Screens, widgets, controllers
├── core/
│   ├── routing/        # app_router.dart (GoRouter)
│   ├── providers/      # Global providers
│   └── widgets/        # Shared UI components
```

**Naming conventions:**
- Firestore field names: `snake_case`
- Dart model fields: `camelCase` (mapped to snake_case in `toFirestore`)
- Local imports: `package:local2local/...` (never `local2local_app`)

**State management:** Riverpod for all controllers and providers.

**Routing:** GoRouter with role-based guards. New routes are added to `lib/nav.dart`.

**Authentication:** Admin access is identified via `token.admin == true` custom claim. Superadmin access uses `token.superadmin == true`.

**Theme:** Use `AdminColors` from `lib/features/triage_hub/theme/admin_theme.dart` for all triage hub UI. Use `L2LColors` from `lib/theme.dart` for global brand UI.

**Environments:** The environment is set at build time via `lib/core/utils/environment_config.dart`. Dreamflow targets `DEV` during development. Do not hardcode environment-specific URLs or project IDs in generated code.

---

## CRITICAL: Firestore type checking in production builds

**Never use `runtimeType.toString().contains(...)` to detect Firestore types.**

Dart's `runtimeType.toString()` works correctly in debug builds and in Dreamflow's canvas preview, but production builds use minification which obfuscates runtime type names. This causes silent failures where type detection returns false for all values.

**Wrong — breaks in production:**

```dart
if (value.runtimeType.toString().contains('Timestamp')) {
  return (value as dynamic).toDate();
}
```

**Correct — always use `is` for type checking:**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

if (value is Timestamp) {
  return value.toDate();
}
```

This applies to all Firestore types: `Timestamp`, `DocumentReference`, `GeoPoint`, etc. Always import `cloud_firestore` and use `is` checks. Include this rule explicitly in any Dreamflow prompt that involves Firestore data formatting.

---

## Firebase connection in Dreamflow

Dreamflow's Firebase panel must be connected to `local2local-dev` at the start of each session. The platform and bundle ID settings do not persist between sessions — reset them each time:

- **Target platforms:** Web only
- **Bundle ID:** `ca.local2local`

This is a Dreamflow quirk and does not affect the deployed app. The CI/CD pipeline controls the actual Firebase project via `firebase_options.dart`.

When Dreamflow's Firebase integration runs, it may modify `android/app/build.gradle`, `settings.gradle`, `google-services.json`, and `firebase.json`. These are Dreamflow's own runtime artifacts — do not commit them. Only commit `firebase_options.dart` if its contents have legitimately changed.

---

## Step 1: Prepare context for Dreamflow

Before starting a Dreamflow session, gather the relevant context:

- The screen or feature spec (from `documents/project_plan.md` or your own notes)
- The relevant Firestore schema from `documents/firestore_schema.md`
- The existing file structure for the feature being extended
- The current `documents/architecture.md` for layer boundaries

---

## Step 2: Prompt the Dreamflow agent

Describe the UI feature to the agent clearly. Always include:

- The screen name and which file to modify
- The data it reads from Firestore and the exact collection path
- The Riverpod provider it should use (reference existing providers by name)
- The interactions (buttons, forms, navigation)
- The admin role required (admin vs superadmin)
- Any existing widgets or components to reuse from `lib/core/widgets/` or `lib/features/triage_hub/widgets/`
- Explicit instruction: **use `is Timestamp` from `cloud_firestore` for any Firestore type checking — never `runtimeType.toString()`**

---

## Step 3: Review and iterate

Review the preview in the Dreamflow canvas. Use thread checkpoints before each agent prompt so you can revert cleanly if needed. Iterate with follow-up prompts until the UI is correct.

If the agent produces code that works in the canvas but fails after publishing, the most common cause is the minification bug described above — check all type checks and replace any `runtimeType.toString()` calls with `is` checks.

---

## Step 4: Commit

When satisfied with the result, commit from Dreamflow's source control panel using the `[DREAM]` source tag. The entire commit message must be on a single line:

```
[DREAM] FEAT(superadmin): Add phase history panel with promoted/abandoned tabs
```

With a BUMP tag if warranted:

```
[DREAM] FEAT(dashboard): Add version display to SuperAdmin triage hub BUMP: MINOR
```

Do not prefix the version number — the pipeline adds it automatically.

---

## Step 5: Watch the pipeline and respond to the HITL card

Same as the Manual method — see `development_method_manual.md` Steps 5–7.

The HITL card will show `Originator: DREAM`.

---

## What Dreamflow should NOT generate

Dreamflow is scoped to Flutter/Dart UI code. Do not ask Dreamflow to generate:

- Cloud Functions TypeScript (`functions/src/`)
- `deploy.yml` or any GitHub Actions configuration
- n8n workflow JSON
- Firestore security rules
- `pubspec.yaml` dependency changes (verify with `flutter pub get` locally after Dreamflow adds them)
- Environment configuration files

If a UI feature requires a new Cloud Function backend, implement the Cloud Function first using the Manual or Assisted method, deploy it, then build the UI against it using Dreamflow.

---

## Updating the SuperAdmin dashboard

The SuperAdmin dashboard (`lib/features/triage_hub/pages/superadmin_dashboard.dart`) reads from these Firestore collections in `local2local-dev`:

| Collection / Document path | Content |
|---|---|
| `artifacts/system_status/public/data/telemetry/last_heartbeat` | System health status and version |
| `artifacts/system_status/public/data/promoted_phases/{auto-id}` | Promotion history |
| `artifacts/system_status/public/data/abandoned_phases/{auto-id}` | Abandoned phase history |
| `artifacts/system_status/public/data/agent_bus` | System-wide agent bus |
| `artifacts/local2local_kaskflow/public/data/agent_bus` | Kaskflow agent bus |
| `artifacts/local2local_moonlitely/public/data/agent_bus` | Moonlitely agent bus |

Providers are defined in `lib/features/triage_hub/providers/superadmin_providers.dart`. Always reference existing providers rather than creating inline streams in the widget.

---

## Tips for effective Dreamflow prompting

**Always specify the Firestore type checking rule.** Include in every prompt that involves Firestore data: "Use `is Timestamp` from `cloud_firestore` for type checking, never `runtimeType.toString()`."

**Provide the full Firestore document structure.** Dreamflow generates better repository code when it knows the exact field names and types.

**Reference existing components.** Mention reusable widgets by name so Dreamflow uses them rather than generating duplicates.

**Ask for complete files.** Always instruct Dreamflow to output the full file content — Zero Abbreviation Policy applies.

**One screen per session.** Keep sessions focused on a single screen or feature.

**Confirm the route before generating.** Agree on the GoRouter route path before Dreamflow generates a new screen.

**Use thread checkpoints.** Save a checkpoint before each agent prompt. This is the safety net for rapid iteration.