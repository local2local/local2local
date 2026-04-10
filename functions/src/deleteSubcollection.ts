import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
const db = admin.firestore();
export const deleteSubcollectionV2 = onDocumentWritten("artifacts/{appId}/public/data/cleanup_requests/{reqId}", async (event) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "pending") return;
  const { path } = data;
  const snapshot = await db.collection(path).get();
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  await event.data?.after.ref.update({ status: "deleted", completed_at: admin.firestore.FieldValue.serverTimestamp() });
});