import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
const db = admin.firestore();

export const listSubcollectionsV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/discovery_requests/{reqId}"
}, async (event) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "pending") return;
  const { docPath } = data;
  const collections = await db.doc(docPath).listCollections();
  const names = collections.map(c => c.id);
  await event.data?.after.ref.update({ status: "discovered", collections: names });
});