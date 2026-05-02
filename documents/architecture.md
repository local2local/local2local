# Local2Local App Architecture

This document describes the application layers, environment setup, and project structure for the local2local Flutter web app.

For the CI/CD pipeline architecture, see `documents/cicd_pipeline_reference.md`. For the full L2LAAF agent framework specification, see `documents/l2laaf_full_specification.md`.

---

## Environments

| Environment | GCP Project | Firebase Project | Branch |
|---|---|---|---|
| Development | `local2local-dev` | local2local-dev | `develop` |
| Production | `local2local-prod` | local2local-prod | `main` |

There is no staging environment. The HITL gate in Google Chat serves as the validation layer between dev and prod. See `documents/cicd_pipeline_reference.md` for the promotion flow.

The environment is configured at build time by the CI/CD pipeline via the Firebase project target — not by `environment_config.dart`. In Dreamflow preview sessions, `lib/core/utils/environment_config.dart` is used to hardcode `DEV`, or `PROD`. To switch, edit `currentEnvironment` and fully stop and restart the preview. Never commit environment config changes — always leave `currentEnvironment` set to `Environment.dev` in the repo.

---

## Application layers

**Features** (`lib/features/...`): Screens, widgets, and presentation logic. Organised feature-first — each feature has its own `data/`, `domain/`, and `presentation/` subdirectory.

**Core** (`lib/core/...`): Repositories, services, shared utilities, and errors. Shared across all features.

**Models** (`lib/models/...`): Immutable data models with Firestore serialization/deserialization.

**Firestore Schema Reference** (`lib/firestore/firestore_data_schema.dart`): Constants and inline schema reference for Firestore collection paths and field names.

---

## Data access

Repositories encapsulate all reads and writes to Firestore and Storage. They enforce a `snake_case` field naming convention in persisted documents. Models expose `camelCase` fields in Dart and convert to `snake_case` in `toFirestore`.

---

## Authentication and authorisation

Firebase Authentication is used for all auth. Two privilege levels exist above regular users:

- **Admin:** identified via custom claim `token.admin == true`
- **Superadmin:** identified via custom claim `token.superadmin == true`

Firestore and Storage security rules enforce per-user access with admin override. See `documents/firestore_schema.md` for the full rule set.

---

## Storage structure

- Public assets: `public/`
- Per-user assets: `users/{uid}/...`

---

## Routing

GoRouter is used with role-based guards. Routes are defined in `lib/core/routing/app_router.dart`. New routes must be added there — do not create standalone navigators.

---

## Flutter file structure

```
lib/
├── main.dart                    # Entry point (Firebase init + ProviderScope)
├── app.dart                     # MaterialApp.router (Theme + Router wiring)
├── firebase_options.dart        # Firebase config
├── theme.dart                   # Master theme (palettes + extensions)
├── core/
│   ├── application/             # App-wide logic (theme_mode_controller.dart)
│   ├── api/                     # Dio client & interceptors
│   ├── routing/                 # app_router.dart (GoRouter)
│   ├── providers/               # Global providers (Storage, Firebase)
│   ├── utils/                   # Formatters, constants, environment_config.dart
│   └── widgets/                 # Shared UI components (app_shell_scaffold.dart)
├── features/
│   ├── triage_hub/              # SuperAdmin Hub
│   │   ├── data/                # Firestore repositories
│   │   ├── domain/              # Freezed models
│   │   └── presentation/        # Screens, widgets, controllers
│   ├── marketplace/             # Marketplace logic
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── auth/                    # Firebase Auth
│       ├── application/         # auth_providers.dart
│       ├── data/                # firebase_auth_service.dart
│       └── presentation/        # login_page.dart, account_page.dart
├── models/                      # Shared immutable data models
└── l10n/                        # Localisation (ARB files)
assets/
├── images/
├── icons/
└── fonts/
```

---

## State management

Riverpod is used for all state management. Controllers live in `presentation/` alongside the screens they serve. Global providers live in `lib/core/providers/`.

---

## GCP projects

| Project | Purpose |
|---|---|
| `local2local-dev` | Development environment + CI/CD source of truth (Firestore tracking) |
| `local2local-prod` | Production environment |
| `local2local-internal` | Governance hub (Agent Registry, Policy, Vector DB) |
| `n8n-bot-prod` | n8n chat handler service account host |
