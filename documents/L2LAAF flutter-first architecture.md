# L2LAAF Flutter File Shell
Based on the architecture, here is the empty shell structure for the **Triage Hub** (Phase 17.1). You should direct Dreamflow to populate these specific paths.

### 1. Core Infrastructure Shells
- lib/core/api/dio_client.dart
- lib/core/routing/router.dartlib/core/providers/shared_prefs_provider.dart

### 2. Triage Hub Feature Shell (Admin Hub)
- lib/features/triage_hub/domain/intervention_model.dart (Freezed)
- lib/features/triage_hub/data/intervention_repository.dart
- lib/features/triage_hub/presentation/triage_controller.dart (Riverpod)
- lib/features/triage_hub/presentation/triage_screen.dart

### 3. Marketplace Feature Shell (Marketplace Logic)
- lib/features/marketplace/domain/order_model.dart
- lib/features/marketplace/presentation/order_list_screen.dart

### 4. Localization Shell
- lib/l10n/app_en.arb


lib/
|-- main.dart                   # Entry point (Firebase init + ProviderScope)
|-- app.dart                    # MaterialApp.router (Theme + Router wiring)
|-- firebase_options.dart        # Dreamflow-standard Firebase config
|-- theme.dart                  # Master Theme (Dreamflow Style: Palettes + Extensions)
|-- core/                       # Shared Nervous System
|   |-- application/            # Logic affecting the whole app
|   |   |-- theme/              # theme_mode_controller.dart
|   |-- api/                    # Dio client & Interceptors
|   |-- routing/                # app_router.dart (GoRouter)
|   |-- providers/              # Global providers (Storage, Firebase)
|   |-- utils/                  # Formatters & Constants (app_sizes.dart)
|   |-- widgets/                # Common UI components (app_shell_scaffold.dart)
|-- features/                   # Feature-First Modules
|   |-- triage_hub/             # Super Admin Hub
|   |   |-- data/               # Firestore Repositories
|   |   |-- domain/             # Freezed Models
|   |   |-- presentation/       # UI (Screens, Widgets, Controllers)
|   |-- marketplace/            # Kaskflow & Moonlitely Logic
|   |   |-- data/ | -- domain/ | -- presentation/
|   |-- auth/                   # Identity Bridge & Firebase Auth
|   |   |-- application/        # auth_providers.dart
|   |   |-- data/               # firebase_auth_service.dart
|   |   |-- presentation/       # login_page.dart, account_page.dart
|-- l10n/                       # Localization (ARB files)
assets/                         # Dreamflow-standard Asset paths
|-- images/                     # Stock images, brand assets
|-- icons/                      # App launcher icons
|-- fonts/                      # Custom typography