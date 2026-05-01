# Development Method: Dreamflow

**Source tag:** `[DREAM]`  
**Tooling:** Dreamflow AI agent + Cursor IDE (for integration)  
**Use cases:** Flutter UI/UX feature development, screen scaffolding, widget implementation, theme changes, navigation updates

---

## Overview

The Dreamflow method uses the Dreamflow AI agent to generate Flutter/Dart code for UI and UX features. Dreamflow operates within the Dreamflow canvas environment and produces production-ready Flutter code that follows the L2LAAF flutter-first architecture. The developer takes the generated code, integrates it into the repo, and pushes it through the standard CI/CD pipeline.

Dreamflow is the primary tool for anything visual — new screens, widget libraries, navigation flows, and theme changes. Backend logic, Cloud Functions, and pipeline changes always use the Manual or Assisted method instead.

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

**Routing:** GoRouter with role-based guards. New routes are added to `lib/core/routing/app_router.dart`.

**Authentication:** Admin access is identified via `token.admin == true` custom claim. Superadmin access uses `token.superadmin == true`.

**Environments:** The environment is set at build time via `lib/core/utils/environment_config.dart`. Dreamflow targets `DEV` during development. Do not hardcode environment-specific URLs or project IDs in generated code.

---

## Step 1: Prepare context for Dreamflow

Before starting a Dreamflow session, gather the relevant context:

- The screen or feature spec (from `documents/l2laaf_full_specification.md` or your own notes)
- The relevant Firestore schema from `documents/firestore_schema.md`
- The existing file structure for the feature being extended (use `audit.sh` to bundle it)
- The current `documents/architecture.md` for layer boundaries

Paste this context at the start of the Dreamflow session.

---

## Step 2: Generate the Flutter code

Describe the UI feature to Dreamflow. Be specific about:

- The screen name and route (e.g. `/admin/triage`)
- The data it reads from Firestore and which collection
- The interactions (buttons, forms, navigation)
- The admin role required (admin vs superadmin)
- Any existing widgets or components it should reuse from `lib/core/widgets/`

Dreamflow will generate the full file content for each file that needs to be created or modified.

---

## Step 3: Copy the generated code into the repo

Dreamflow output is copied manually into the repo using Cursor IDE. For each generated file:

1. Open the target file path in Cursor (create it if it doesn't exist)
2. Replace the full file content with Dreamflow's output
3. Save the file

Do not use partial updates or try to merge Dreamflow output into existing files manually — always take the full file content that Dreamflow generates.

### If Dreamflow generates a logic_payload bundle

Some Dreamflow configurations output code in the `L2LAAF_BLOCK` format. In this case, use `relay.sh` exactly as in the Assisted method, but use a `COMMIT_MSG` with the `[DREAM]` source tag:

```
L2LAAF_BLOCK_START(commit:message:COMMIT_MSG)
[DREAM] FEAT(triage): Add abandoned phases list to SuperAdmin dashboard
L2LAAF_BLOCK_END
```

---

## Step 4: Verify locally

Run Flutter analysis after copying the files:

```bash
flutter analyze
```

If Dreamflow generated any code with errors, take the error output back to the Dreamflow session and ask for a fix. Do not push code that fails analysis.

For changes that affect routing or state, do a quick visual check in the Dreamflow preview environment before committing.

---

## Step 5: Commit

Use the `[DREAM]` source tag. Dreamflow **does not support multi-line commit messages**, so the entire commit message including any `BUMP:` tag must be on a single line:

```bash
git add .
git commit -m "[DREAM] FEAT(triage): Add abandoned phases list to SuperAdmin dashboard"
```

With a BUMP tag:
```bash
git commit -m "[DREAM] FEAT(dashboard): Add version display to SuperAdmin triage hub BUMP: MINOR"
```

Do not prefix the version number — the pipeline adds it automatically.

If the remote is ahead, rebase before pushing:

```bash
git pull --rebase origin develop
git push origin develop
```

---

## Step 6: Watch the pipeline and respond to the HITL card

Same as the Manual method — see `development_method_manual.md` Steps 5–7.

The HITL card will show `Originator: DREAM`.

---

## What Dreamflow should NOT generate

Dreamflow is scoped to Flutter/Dart UI code. Do not ask Dreamflow to generate:

- Cloud Functions TypeScript (`functions/src/`)
- `deploy.yml` or any GitHub Actions configuration
- n8n workflow JSON
- Firestore security rules
- `pubspec.yaml` dependency changes (do these manually and validate with `flutter pub get`)
- Environment configuration files

If a UI feature requires a new Cloud Function backend, implement the Cloud Function first using the Manual or Assisted method, deploy it, then build the UI against it using Dreamflow.

---

## Updating the SuperAdmin dashboard

The SuperAdmin dashboard (`lib/features/triage_hub/`) is the primary target for Dreamflow development. It reads from several CI/CD system status collections in `local2local-dev`:

| Collection path | Content |
|---|---|
| `artifacts/system_status/public/data/version` | Current deployed version |
| `artifacts/system_status/public/data/telemetry` | System health (GREEN/YELLOW/RED) |
| `artifacts/system_status/public/data/promoted_phases` | Promotion history |
| `artifacts/system_status/public/data/abandoned_phases` | Abandoned phase history |

When prompting Dreamflow to build dashboard features, provide the Firestore document structures from `documents/cicd_pipeline_reference.md` so Dreamflow generates the correct field mappings.

---

## Dreamflow and the environment config

Dreamflow previews run in a single environment at a time, configured in `lib/core/utils/environment_config.dart`:

```dart
static const Environment currentEnvironment = Environment.dev;
```

To switch environments for preview:
1. Edit `currentEnvironment` in `environment_config.dart`
2. Fully stop and restart the Dreamflow preview

Do not commit environment config changes — always leave `currentEnvironment` set to `Environment.dev` in the repo. The CI/CD pipeline controls which environment the app deploys to via the Firebase project target, not via this config file.

---

## Tips for effective Dreamflow prompting

**Provide the full Firestore document structure.** Dreamflow generates better repository code when it knows the exact field names and types it will be reading. Paste the relevant document structure from `documents/firestore_schema.md`.

**Reference existing components.** If `lib/core/widgets/` contains relevant reusable widgets, mention them by name. Dreamflow will use them rather than generating duplicates.

**Ask for complete files.** Always instruct Dreamflow to output the full file content, never partial snippets. The L2LAAF workflow manifest rule applies: Zero Abbreviation Policy — no `// ... rest of code`.

**One screen per session.** Keep Dreamflow sessions focused on a single screen or feature. Cross-feature sessions produce tangled output that is harder to verify and review at the HITL gate.

**Confirm the route before generating.** Agree on the GoRouter route path (e.g. `/admin/triage/abandoned-phases`) before Dreamflow generates the screen, so the routing wiring is correct in the first pass.
