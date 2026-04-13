# Firestore Schema and Security

This document is the source of truth for the Firestore data model and the corresponding security posture. All field names stored in Firestore use snake_case. Dart models use camelCase and map to snake_case in toFirestore.

Collections
1) users (users/{userId})
   - uid, email, displayName, photoUrl, roles[], isSuperAdmin
   - created_at, updated_at

2) buyer_profiles (buyer_profiles/{userId})
   - owner_id, first_name, last_name, preferences{}, favorite_sellers[], wishlist[], location{}
   - created_at, updated_at

3) seller_profiles (seller_profiles/{userId})
   - owner_id, business_name, business_description, business_type, contact_info{}, social_links{}
   - images[], tags[], is_verified, is_active, created_at, updated_at

4) products (products/{productId})
   - seller_id, title, description, category, subcategory, price, images[], tags[], status, quantity_available
   - created_at, updated_at

5) shows (shows/{showId})
   - owner_id, title, description, category, event_date, ticket_price?, max_attendees?, current_attendees, images[], tags[], is_public, status
   - created_at, updated_at

6) orders (orders/{orderId})
   - buyer_id, seller_id, product_id, quantity, total_amount, status, payment_status, payment_method, delivery_address{}, notes?
   - created_at, updated_at, completed_at?

7) chats (chats/{chatId})
   - participant_ids[], participant_names{}, last_message, last_message_at, last_message_sender_id, is_active, chat_type, order_id?, product_id?
   - created_at, updated_at
   - Subcollection: messages (chats/{chatId}/messages/{messageId})
     - chat_id, sender_id, content, message_type, media_url?, is_read, created_at

8) tags (tags/{tagId})
   - name, category, usage_count, is_active
   - created_at, updated_at

Security Rules (to deploy via Dreamflow Firebase panel)
Firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }
    function isOwner(userId) { return isSignedIn() && request.auth.uid == userId; }
    function isAdmin() { return isSignedIn() && request.auth.token.admin == true; }

    // Admin override
    match /{path=**} {
      allow read, write: if isAdmin();
    }

    // Users
    match /users/{userId} { allow read, write: if isOwner(userId); }

    // Profiles
    match /buyer_profiles/{userId} { allow read, write: if isOwner(userId); }
    match /seller_profiles/{userId} { allow read, write: if isOwner(userId); }

    // Products (public read; owner write)
    match /products/{productId} {
      allow read: if true;
      allow create, update, delete: if isSignedIn() && request.resource.data.seller_id == request.auth.uid;
    }

    // Shows (public read; owner write)
    match /shows/{showId} {
      allow read: if true;
      allow create, update, delete: if isSignedIn() && request.resource.data.owner_id == request.auth.uid;
    }

    // Orders (buyer or seller on the document)
    match /orders/{orderId} {
      allow read: if isSignedIn() && (
        resource.data.buyer_id == request.auth.uid ||
        resource.data.seller_id == request.auth.uid
      );
      allow write: if isSignedIn() && (
        (request.method == 'create' && (
          request.resource.data.buyer_id == request.auth.uid ||
          request.resource.data.seller_id == request.auth.uid
        )) ||
        (request.method != 'create' && (
          resource.data.buyer_id == request.auth.uid ||
          resource.data.seller_id == request.auth.uid
        ))
      );
    }

    // Chats and messages (participants only)
    match /chats/{chatId} {
      function isChatParticipant() {
        return request.auth.uid in resource.data.participant_ids ||
               request.auth.uid in request.resource.data.participant_ids;
      }
      allow read, write: if isSignedIn() && isChatParticipant();

      match /messages/{messageId} {
        allow read, write: if isSignedIn() && (
          request.auth.uid == resource.data.sender_id ||
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participant_ids
        );
      }
    }

    // Tags (public read; admin write via override)
    match /tags/{tagId} {
      allow read: if true;
      allow write: if false;
    }

    // Default deny
    match /{document=**} { allow read, write: if false; }
  }
}

Storage
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() { return request.auth != null; }
    function isOwner(userId) { return isSignedIn() && request.auth.uid == userId; }
    function isAdmin() { return isSignedIn() && request.auth.token.admin == true; }

    // Admin override
    match /{allPaths=**} { allow read, write: if isAdmin(); }

    // Public assets
    match /public/{file=**} {
      allow read: if true;
      allow write: if false;
    }

    // Per-user folders
    match /users/{userId}/{file=**} {
      allow read, write: if isOwner(userId);
    }

    // Default deny
    match /{path=**} { allow read, write: if false; }
  }
}

Deployment
- In Dreamflow, open the Firebase panel, connect your Firebase project, then paste these rules into the Firestore Rules and Storage Rules editors and publish.
