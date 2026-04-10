import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

/**
 * listSubcollectionsV2
 * Migrated to 2nd Gen SDK to support consistent CPU/Memory configuration.
 * Includes built-in CORS handling.
 */
export const listSubcollectionsV2 = onRequest({ cors: true }, async (req, res) => {
  try {
    const { documentPath } = req.body;
    if (!documentPath) {
      res.status(400).json({ error: "Missing documentPath in request body" });
      return;
    }
    const docRef = admin.firestore().doc(documentPath);
    const collections = await docRef.listCollections();
    const subcollections = collections.map((col) => col.id);
    
    res.json({ subcollections });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});