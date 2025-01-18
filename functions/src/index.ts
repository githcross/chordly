import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const purgeSongs = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const threshold = new Date(now.toDate().getTime() - (7 * 24 * 60 * 60 * 1000));

    const snapshot = await admin.firestore()
      .collection('songs')
      .where('isActive', '==', false)
      .where('deletedAt', '<', threshold)
      .get();

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
  }); 