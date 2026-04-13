# L2LAAF Comprehensive Test Plan

## 1. Automated Verification (n8n Node 24)
- **Log Scraper**: Scan Google Cloud Logs for `EXCEPTION` or `ERROR` strings during the first 60 seconds post-deploy.
- **Firestore Integrity**: Verify that new documents in the orders collection strictly follow the `snake_case` naming convention.
- **Auth Claims**: Execute a trigger function to verify that `superadmin: true` is present in the custom claims of the test user.

## 2. Evolution Engine Audit (Phase 36)
- **Memory Check**: Ensure `COMMIT_PROPOSAL` successfully writes to the `lessons_learned` collection.
- **Mutex Verification**: Confirm that `logic_locks` are automatically released after n8n confirms a successful deploy.

## 3. Environment Parity
- **Config Check**: Verify `lib/core/utils/environment_config.dart` matches the target GCP Project ID (`local2local-dev`, `local2local-staging`, or `local2local-prod`).