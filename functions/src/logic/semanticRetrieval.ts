import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

let internalDb: admin.firestore.Firestore;

export const semanticRetrievalV1 = onCall(async (request) => {
  const queryText = request.data.query;
  if (!queryText) throw new HttpsError("invalid-argument", "Query text is required");

  if (!internalDb) {
    try {
      const internalApp = admin.app('internal');
      internalDb = internalApp.firestore();
    } catch (e) {
      const internalApp = admin.initializeApp({ projectId: 'local2local-internal' }, 'internal');
      internalDb = internalApp.firestore();
    }
  }

  const token = await admin.credential.applicationDefault().getAccessToken();
  const aiUrl = `https://us-central1-aiplatform.googleapis.com/v1/projects/local2local-internal/locations/us-central1/publishers/google/models/text-embedding-004:predict`;

  const aiRes = await fetch(aiUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token.access_token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      instances: [{ task_type: "RETRIEVAL_DOCUMENT", title: "", content: queryText }]
    })
  });

  if (!aiRes.ok) {
    throw new HttpsError('internal', `Failed to get embedding: ${await aiRes.text()}`);
  }

  const aiData = await aiRes.json() as any;
  const queryVector = aiData.predictions[0].embeddings.values;

  const fetchAndSort = async (useAs: string) => {
      try {
          const snap = await internalDb.collection('lessons_learned')
              .where('use_as', '==', useAs)
              .findNearest('embedding', FieldValue.vector(queryVector), { limit: 5, distanceMeasure: 'COSINE' })
              .get();
          return snap.docs.map(d => {
              const data = d.data();
              delete data.embedding;
              return data;
          });
      } catch (e) {
          const snap = await internalDb.collection('lessons_learned').where('use_as', '==', useAs).get();

          const docs = snap.docs.map(d => d.data()).filter(d =>
              d.embedding && (Array.isArray(d.embedding) || typeof d.embedding.toArray === 'function')
          );

          const getVec = (val: any) => typeof val.toArray === 'function' ? val.toArray() : val;
          const dotProduct = (a: number[], b: number[]) => a.reduce((sum, val, i) => sum + val * b[i], 0);
          const magnitude = (vec: number[]) => Math.sqrt(vec.reduce((sum, val) => sum + val * val, 0));

          const scored = docs.map(d => {
              const vecB = getVec(d.embedding);
              const magA = magnitude(queryVector);
              const magB = magnitude(vecB);
              const similarity = magA && magB ? dotProduct(queryVector, vecB) / (magA * magB) : 0;
              return { ...d, similarity };
          });

          scored.sort((a, b) => b.similarity - a.similarity);
          return scored.slice(0, 5).map(d => {
              const { similarity, embedding, ...rest } = d as any;
              return rest;
          });
      }
  };

  const instructions = await fetchAndSort('INSTRUCTION');
  const evidence = await fetchAndSort('EVIDENCE');

  return { instructions, evidence };
});