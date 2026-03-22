# Local2Local App Architecture

This document summarizes the application layers and environment setup used in Dreamflow.

Environments
- Dreamflow currently runs one environment at a time. We use lib/core/utils/environment_config.dart to hardcode DEV, STAGING, or PROD.
- To switch, edit currentEnvironment in environment_config.dart and fully stop and restart the preview.

Layers
- Features (lib/features/...): Screens, widgets, and presentation logic.
- Core (lib/core/...): Repositories, services, shared utilities, and errors.
- Models (lib/models/...): Immutable data models with Firestore (de)serialization.
- Firestore Schema Reference (lib/firestore/firestore_data_schema.dart): Constants and inline schema reference.

Data Access
- Repositories encapsulate reads/writes to Firestore and Storage and enforce a snake_case field naming convention in persisted documents.
- Models expose camelCase fields in Dart and convert to snake_case in toFirestore.

Authentication and Authorization
- Firebase Authentication is expected. Admins are identified via a custom claim token.admin = true.
- Firestore and Storage rules enforce per-user access and admin override (see firestore_schema.md for details).

Storage Structure
- Public assets live under public/.
- Per-user assets live under users/{uid}/..., aligning with Storage rules.

Routing
- GoRouter is used with role-based guards. See lib/app/navigation/app_router.dart.