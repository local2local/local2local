# Superadmin Setup Guide

This guide provides step-by-step instructions for implementing Firebase Cloud Functions to manage superadmin custom claims for the Local2Local app.

## Overview

The app now supports **superadmin accounts** with elevated privileges using:
- **Firebase Custom Claims**: Securely stored in Firebase Auth tokens
- **Firestore Fields**: Track superadmin status in user documents
- **Route Guards**: Protect admin-only routes using `superAdminGuard`

## What's Already Implemented

✅ **Frontend (Flutter)**:
- `AuthService` now includes methods to check custom claims (`isSuperAdmin()`, `hasCustomClaim()`)
- `RoleBasedGuard` has a new `superAdminGuard()` for superadmin-only routes
- `UserModel` includes an `isSuperAdmin` field
- `AdminService` to manage superadmin status in Firestore
- `SuperAdminManagementScreen` UI for managing superadmin accounts
- New admin route: `/admin/superadmins` (protected by `superAdminGuard`)

## What You Need to Implement (Backend)

⚠️ **Custom claims MUST be set via Firebase Cloud Functions** - they cannot be set from client-side code for security reasons.

---

## Step-by-Step Backend Implementation

### Step 1: Set Up Firebase Functions

1. **Navigate to your Firebase Functions directory** (create one if it doesn't exist):
   ```bash
   # If you don't have a functions directory yet:
   firebase init functions
   
   # Select your project
   # Choose TypeScript or JavaScript
   # Install dependencies
   ```

2. **Install required dependencies**:
   ```bash
   cd functions
   npm install firebase-admin firebase-functions
   ```

### Step 2: Create Cloud Functions

Create or edit `functions/src/index.ts` (TypeScript) or `functions/index.js` (JavaScript):

#### TypeScript Version:

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Set superadmin custom claim for a user
 * This function should be called via Firebase Functions Shell or through an HTTPS callable
 */
export const setSuperAdminClaim = functions.https.onCall(async (data, context) => {
  // Security: Only existing superadmins can create new superadmins
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be authenticated to perform this action.'
    );
  }

  // Check if caller is already a superadmin
  const callerToken = await admin.auth().getUser(context.auth.uid);
  const callerClaims = callerToken.customClaims || {};
  
  if (!callerClaims['superadmin']) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only superadmins can create other superadmins.'
    );
  }

  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'userId is required'
    );
  }

  try {
    // Set the custom claim
    await admin.auth().setCustomUserClaims(userId, { superadmin: true });

    // Update Firestore
    await admin.firestore().collection('users').doc(userId).update({
      isSuperAdmin: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: `Superadmin claim set for user ${userId}` };
  } catch (error) {
    console.error('Error setting superadmin claim:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to set superadmin claim'
    );
  }
});

/**
 * Remove superadmin custom claim from a user
 */
export const removeSuperAdminClaim = functions.https.onCall(async (data, context) => {
  // Security: Only existing superadmins can remove superadmin status
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be authenticated to perform this action.'
    );
  }

  const callerToken = await admin.auth().getUser(context.auth.uid);
  const callerClaims = callerToken.customClaims || {};
  
  if (!callerClaims['superadmin']) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only superadmins can remove superadmin status.'
    );
  }

  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'userId is required'
    );
  }

  // Prevent removing your own superadmin status
  if (userId === context.auth.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You cannot remove your own superadmin status.'
    );
  }

  try {
    // Remove the custom claim
    await admin.auth().setCustomUserClaims(userId, { superadmin: false });

    // Update Firestore
    await admin.firestore().collection('users').doc(userId).update({
      isSuperAdmin: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: `Superadmin claim removed for user ${userId}` };
  } catch (error) {
    console.error('Error removing superadmin claim:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to remove superadmin claim'
    );
  }
});

/**
 * Firestore trigger: Sync custom claims when user document is updated
 * This ensures custom claims stay in sync with Firestore
 */
export const syncSuperAdminClaim = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;

    // Only process if isSuperAdmin field changed
    if (before.isSuperAdmin === after.isSuperAdmin) {
      return null;
    }

    try {
      await admin.auth().setCustomUserClaims(userId, {
        superadmin: after.isSuperAdmin === true,
      });
      console.log(`Synced superadmin claim for user ${userId}: ${after.isSuperAdmin}`);
      return null;
    } catch (error) {
      console.error(`Failed to sync superadmin claim for user ${userId}:`, error);
      return null;
    }
  });
```

#### JavaScript Version:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.setSuperAdminClaim = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be authenticated to perform this action.'
    );
  }

  const callerToken = await admin.auth().getUser(context.auth.uid);
  const callerClaims = callerToken.customClaims || {};
  
  if (!callerClaims['superadmin']) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only superadmins can create other superadmins.'
    );
  }

  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId is required');
  }

  try {
    await admin.auth().setCustomUserClaims(userId, { superadmin: true });
    await admin.firestore().collection('users').doc(userId).update({
      isSuperAdmin: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: `Superadmin claim set for user ${userId}` };
  } catch (error) {
    console.error('Error setting superadmin claim:', error);
    throw new functions.https.HttpsError('internal', 'Failed to set superadmin claim');
  }
});

exports.removeSuperAdminClaim = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be authenticated to perform this action.'
    );
  }

  const callerToken = await admin.auth().getUser(context.auth.uid);
  const callerClaims = callerToken.customClaims || {};
  
  if (!callerClaims['superadmin']) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only superadmins can remove superadmin status.'
    );
  }

  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId is required');
  }

  if (userId === context.auth.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You cannot remove your own superadmin status.'
    );
  }

  try {
    await admin.auth().setCustomUserClaims(userId, { superadmin: false });
    await admin.firestore().collection('users').doc(userId).update({
      isSuperAdmin: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: `Superadmin claim removed for user ${userId}` };
  } catch (error) {
    console.error('Error removing superadmin claim:', error);
    throw new functions.https.HttpsError('internal', 'Failed to remove superadmin claim');
  }
});

exports.syncSuperAdminClaim = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;

    if (before.isSuperAdmin === after.isSuperAdmin) {
      return null;
    }

    try {
      await admin.auth().setCustomUserClaims(userId, {
        superadmin: after.isSuperAdmin === true,
      });
      console.log(`Synced superadmin claim for user ${userId}: ${after.isSuperAdmin}`);
      return null;
    } catch (error) {
      console.error(`Failed to sync superadmin claim for user ${userId}:`, error);
      return null;
    }
  });
```

### Step 3: Deploy Cloud Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:setSuperAdminClaim,functions:removeSuperAdminClaim,functions:syncSuperAdminClaim
```

### Step 4: Create Your First Superadmin

Since the Cloud Function requires an existing superadmin to create new ones, you need to manually create the first superadmin using Firebase CLI:

1. **Open Firebase Functions Shell**:
   ```bash
   firebase functions:shell
   ```

2. **Set the first superadmin** (replace `USER_ID_HERE` with the actual user's UID):
   ```javascript
   const admin = require('firebase-admin');
   admin.auth().setCustomUserClaims('USER_ID_HERE', { superadmin: true })
   ```

3. **Update Firestore manually** for the first user:
   ```javascript
   admin.firestore().collection('users').doc('USER_ID_HERE').update({
     isSuperAdmin: true,
     updatedAt: admin.firestore.FieldValue.serverTimestamp()
   })
   ```

4. **Exit the shell**:
   ```
   .exit
   ```

### Step 5: Update Flutter App to Call Cloud Functions

Add the Firebase Functions package to your `pubspec.yaml`:

```yaml
dependencies:
  cloud_functions: ^5.1.4
```

Update `AdminService` to call the Cloud Functions:

```dart
import 'package:cloud_functions/cloud_functions.dart';

class AdminService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Add this method to call the Cloud Function
  Future<void> setSuperAdminClaim(String userId) async {
    try {
      final callable = _functions.httpsCallable('setSuperAdminClaim');
      final result = await callable.call({'userId': userId});
      print('Result: ${result.data}');
    } catch (e) {
      print('Error calling setSuperAdminClaim: $e');
      rethrow;
    }
  }
  
  Future<void> removeSuperAdminClaim(String userId) async {
    try {
      final callable = _functions.httpsCallable('removeSuperAdminClaim');
      final result = await callable.call({'userId': userId});
      print('Result: ${result.data}');
    } catch (e) {
      print('Error calling removeSuperAdminClaim: $e');
      rethrow;
    }
  }
}
```

---

## Testing Your Implementation

### Test 1: Create a Superadmin

1. Log in as your initial superadmin
2. Navigate to `/admin/superadmins`
3. Click "Add Superadmin"
4. Enter a valid user ID
5. Verify the user appears in the list

### Test 2: Access Control

1. Try accessing `/admin/superadmins` with a regular admin account (should redirect to dashboard)
2. Try accessing with a superadmin account (should succeed)
3. Sign out and back in to ensure custom claims are loaded

### Test 3: Remove Superadmin

1. Log in as a superadmin
2. Try to remove another superadmin (should succeed)
3. Try to remove yourself (should be blocked)

---

## Security Best Practices

1. **Never expose superadmin functions to public APIs** - Always check authentication and authorization
2. **Log all superadmin changes** - Keep an audit trail
3. **Limit superadmin count** - Only create as many as necessary
4. **Use environment variables** - For production vs. development configurations
5. **Monitor Cloud Function logs** - Check Firebase Console regularly

---

## Troubleshooting

### Custom Claims Not Working

**Issue**: User still can't access superadmin routes after being promoted

**Solution**:
- The user must sign out and sign back in for custom claims to refresh
- Or call `AuthService.refreshToken()` in the app
- Custom claims are cached in the ID token

### Cloud Function Permission Denied

**Issue**: "permission-denied" when calling Cloud Function

**Solution**:
- Verify the caller is already a superadmin
- Check Firebase Authentication rules
- Ensure the function is deployed correctly

### Firestore and Claims Out of Sync

**Issue**: Firestore shows `isSuperAdmin: true` but custom claim is false

**Solution**:
- The `syncSuperAdminClaim` trigger should handle this automatically
- Manually sync by calling the Cloud Function again
- Check Cloud Function logs for errors

---

## Additional Enhancements (Optional)

### Email Notifications

Add email notifications when superadmin status changes:

```typescript
import * as nodemailer from 'nodemailer';

// After setting custom claim:
const transporter = nodemailer.createTransport({ /* config */ });
await transporter.sendMail({
  to: userEmail,
  subject: 'Superadmin Access Granted',
  text: 'You have been granted superadmin access to Local2Local.',
});
```

### Audit Logging

Create a separate Firestore collection to track all superadmin changes:

```typescript
await admin.firestore().collection('admin_audit_log').add({
  action: 'SUPERADMIN_GRANTED',
  targetUserId: userId,
  performedBy: context.auth.uid,
  timestamp: admin.firestore.FieldValue.serverTimestamp(),
});
```

### Automatic Cleanup

Set up a scheduled function to remove inactive superadmins:

```typescript
export const cleanupInactiveSuperadmins = functions.pubsub
  .schedule('every 30 days')
  .onRun(async (context) => {
    // Implementation here
  });
```

---

## Questions or Issues?

If you encounter any problems during setup:

1. Check Firebase Console logs
2. Verify all dependencies are installed
3. Ensure proper Firebase project configuration
4. Review security rules in Firestore

For more information, see:
- [Firebase Custom Claims Documentation](https://firebase.google.com/docs/auth/admin/custom-claims)
- [Firebase Cloud Functions Guide](https://firebase.google.com/docs/functions)
