# Superadmin Setup Guide

This guide covers setting up Firebase superadmin custom claims for the Local2Local app.

---

## Overview

The app supports two elevated privilege levels above regular users:

- **Admin:** `token.admin == true` — access to admin routes and Firestore admin overrides
- **Superadmin:** `token.superadmin == true` — access to the SuperAdmin Triage Hub and CI/CD system status

Custom claims are stored in Firebase Auth tokens and cannot be set from client-side code. They must be set via Firebase Cloud Functions or the Firebase CLI.

---

## What is already implemented

**Frontend (Flutter):**
- `AuthService` includes `isSuperAdmin()` and `hasCustomClaim()` methods
- `RoleBasedGuard` has a `superAdminGuard()` for superadmin-only routes
- `UserModel` includes an `isSuperAdmin` field
- `AdminService` manages superadmin status in Firestore
- `SuperAdminManagementScreen` UI at `/admin/superadmins`

**Backend (Cloud Functions):**
- `setSuperAdminClaim` — callable function to grant superadmin status
- `removeSuperAdminClaim` — callable function to revoke superadmin status
- `syncSuperAdminClaim` — Firestore trigger to keep claims in sync with user documents

---

## Creating the first superadmin

Since `setSuperAdminClaim` requires an existing superadmin to call it, the first superadmin must be set manually via the Firebase CLI.

**Step 1: Open the Firebase Functions shell**
```bash
firebase functions:shell --project local2local-prod
```

**Step 2: Set the custom claim** (replace `USER_UID` with the actual Firebase Auth UID)
```javascript
const admin = require('firebase-admin');
admin.auth().setCustomUserClaims('USER_UID', { superadmin: true, admin: true })
```

**Step 3: Update Firestore**
```javascript
admin.firestore().collection('users').doc('USER_UID').update({
  isSuperAdmin: true,
  updatedAt: admin.firestore.FieldValue.serverTimestamp()
})
```

**Step 4: Exit**
```
.exit
```

The user must sign out and back in for the new custom claim to take effect in their ID token.

---

## Managing superadmins via the app

Once the first superadmin exists, additional superadmins can be managed through the app:

1. Sign in as a superadmin
2. Navigate to `/admin/superadmins`
3. Use the UI to add or remove superadmin status for other users

---

## Troubleshooting

**Custom claims not taking effect**  
The user must sign out and sign back in. Custom claims are cached in the ID token and only refresh on sign-in.

**`permission-denied` when calling Cloud Function**  
Verify the caller has `superadmin: true` in their custom claims. Check Firebase Auth in the console.

**Firestore and claims out of sync**  
The `syncSuperAdminClaim` Firestore trigger handles this automatically. If manual correction is needed, call `setSuperAdminClaim` again or use the Firebase Functions shell.

---

## Security notes

- Never set custom claims from client-side Flutter code
- The `setSuperAdminClaim` function verifies the caller is already a superadmin before proceeding
- A superadmin cannot remove their own superadmin status
- All superadmin changes are logged to `admin_audit_log` in Firestore
