import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const listSubcollectionsV2 = functions.https.onRequest(async (req, res) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    res.status(204).set(CORS_HEADERS).send("");
    return;
  }

  // Set CORS headers for actual request
  res.set(CORS_HEADERS);

  try {
    const { documentPath } = req.body;
    const docRef = admin.firestore().doc(documentPath);
    const collections = await docRef.listCollections();
    const subcollections = collections.map((col) => col.id);
    
    res.json({ subcollections });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});