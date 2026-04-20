import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const deleteSubcollectionV2 = onRequest({ cors: true }, async (req, res): Promise<void> => {
  const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (req.method === "OPTIONS") {
    res.status(204).set(CORS_HEADERS).send("");
    return;
  }
  res.set(CORS_HEADERS);
  try {
    const { path } = req.body;
    if (!path) {
      res.status(400).send({ error: "Missing collection path" });
      return;
    }
    const snapshot = await db.collection(path).get();
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    res.send({ status: "deleted", count: snapshot.size });
    return;
  } catch (error: any) {
    res.status(500).send({ error: error.message });
    return;
  }
});