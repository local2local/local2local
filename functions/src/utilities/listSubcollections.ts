import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

export const listSubcollectionsV2 = functions.https.onRequest(async (req, res) => {
  // Handle CORS preflight request
  if (req.method === "OPTIONS") {
    res.set(CORS_HEADERS);
    res.status(204).send("");
    return;
  }

  // Set CORS headers for actual request
  res.set(CORS_HEADERS);

  try {
    const { documentPath } = req.body;

    if (!documentPath || typeof documentPath !== "string") {
      res.status(400).json({ error: "documentPath is required" });
      return;
    }

    const docRef = admin.firestore().doc(documentPath);
    const collections = await docRef.listCollections();
    const subcollections = collections.map((col) => col.id);

    res.status(200).json({ subcollections });
  } catch (error) {
    console.error("Error listing subcollections:", error);
    res.status(500).json({ error: "Failed to list subcollections" });
  }
});
