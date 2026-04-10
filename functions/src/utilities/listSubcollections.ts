import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

export const listSubcollectionsV2 = functions.https.onRequest(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.set(CORS_HEADERS).status(204).send("");
    return;
  }
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