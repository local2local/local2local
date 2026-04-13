import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

export const listSubcollectionsV2 = onRequest({ cors: true }, async (req, res) => {
  try {
    const { documentPath } = req.body;
    if (!documentPath) {
      res.status(400).json({ error: "Missing documentPath" });
      return;
    }
    const docRef = admin.firestore().doc(documentPath);
    const collections = await docRef.listCollections();
    res.json({ subcollections: collections.map((col) => col.id) });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});