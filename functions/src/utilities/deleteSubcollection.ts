import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export const deleteSubcollectionV2 = functions.https.onRequest(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.set(CORS_HEADERS).status(204).send("");
    return;
  }

  res.set(CORS_HEADERS);

  try {
    const { collectionPath } = req.body;
    if (!collectionPath || typeof collectionPath !== "string") {
      res.status(400).json({ error: "collectionPath is required" });
      return;
    }

    const firestore = admin.firestore();
    const collectionRef = firestore.collection(collectionPath);
    const snapshot = await collectionRef.get();
    
    const batch = firestore.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    res.status(200).json({ deletedCount: snapshot.size, collectionPath });
  } catch (error: any) {
    res.status(500).json({ error: error.message || "Internal server error" });
  }
});
