# Phase 45.6 Patch: Repair HITL Promote Data Flow

## Root cause
Inserting Prepare Promote Ack Body + Post Promote Ack before Payload Filter caused
`$json` inside Payload Filter to be the Google Chat API response (no `filePath` field).
`undefined !== "IGNORE"` evaluated TRUE, routing to the code-mutation path instead
of the version-bump path. The mutation chain immediately returned empty
(Prepare Mutate Payload exits when filePath=IGNORE), so Get pubspec on Develop
was never reached and main was never updated.

## Fix
Two nodes updated to use explicit cross-node references instead of `$json`:
- Payload Filter: leftValue uses `$('Automated Testing Suite').first().json.filePath`
- Prepare Context Query: filePath and reason read from `$('Automated Testing Suite').first().json`

## Test
Click PROMOTE TO PROD on the next HITL card. Expected sequence:
1. ⏳ Acknowledge card within ~5 seconds
2. GitHub Actions run appears on main branch (~10 seconds after click)
3. 🚀 Final Alert promoted card after GH Actions completes (~5 minutes)