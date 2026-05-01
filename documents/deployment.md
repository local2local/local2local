# Deployment Reference

This document summarises the deployment paths for the local2local app. For full details on each method, see the relevant development method document.

---

## Summary of deployment methods

| Method | Source tag | Entry point | Pipeline triggered by |
|---|---|---|---|
| Manual | `[MANUAL]` | `git push origin develop` | Git push |
| Assisted | `[ASSISTED]` | `./scripts/relay.sh` | Git push (via relay.sh) |
| Autonomous | `[AUTO]` | Agent bus (Firestore) | n8n webhook |
| Dreamflow | `[DREAM]` | `git push origin develop` | Git push |

All four methods produce a HITL card in Google Chat and follow the same promote/abandon flow.

---

## The CI/CD pipeline

Every push to `develop` triggers `.github/workflows/deploy.yml`, which:

1. Bumps the version in `pubspec.yaml` and pushes an `[AUTO] CHORE(version)` commit with `[skip ci]`
2. Builds Flutter web and deploys to `local2local-dev`
3. Deploys the DEV n8n workflow JSON
4. Fires the DEV n8n webhook with the deployment payload

See `documents/cicd_pipeline_reference.md` for the full pipeline reference.

---

## Assisted method: relay.sh

The `scripts/relay.sh` script is the entry point for the Assisted method. It:

1. Runs `scripts/patcher.js` to extract files from `scripts/logic_payload.txt`
2. Validates Cloud Functions TypeScript (`npm run build` in `functions/`)
3. Validates Flutter code (`flutter analyze`)
4. Validates n8n workflow JSON syntax and webhook IDs
5. Commits using the `COMMIT_MSG` from the bundle
6. Pushes to `develop`, rebasing automatically if the remote is ahead

```bash
./scripts/relay.sh
```

The `COMMIT_MSG` block in the bundle must use the `[ASSISTED]` source tag and follow the standard commit format. No version prefix — the pipeline adds it.

See `documents/development_method_assisted.md` for the full workflow.

---

## Manual method: deploy.sh

The `scripts/deploy.sh` script is an optional convenience wrapper for the Manual method. It runs `flutter analyze`, prompts for a commit message, and pushes to `develop`.

```bash
./scripts/deploy.sh
```

When prompted for a commit message, use the standard format:
```
[MANUAL] TYPE(scope): Description
```

See `documents/development_method_manual.md` for the full workflow.

---

## Production promotion

Production deployments are never triggered directly. All production changes go through the HITL gate in Google Chat. Pressing `PROMOTE TO PROD` causes n8n to force-update the `main` branch ref and create a promotion commit, which triggers the GitHub Actions pipeline on `main` to deploy to `local2local-prod`.

Never commit directly to `main`.
