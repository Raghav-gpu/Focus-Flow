// functions/index.js
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

exports.checkUpcomingTasks = onSchedule('every 5 minutes', async () => {
  console.log('Function started at:', new Date().toISOString());
  const now = new Date();
  const tenMinutesFromNow = new Date(now.getTime() + 10 * 60 * 1000);
  const fifteenMinutesFromNow = new Date(now.getTime() + 15 * 60 * 1000);
  console.log('Checking tasks between:', tenMinutesFromNow.toISOString(), 'and', fifteenMinutesFromNow.toISOString());

  try {
    const tasksSnapshot = await db.collectionGroup('tasks')
      .where('date', '>=', Timestamp.fromDate(tenMinutesFromNow))
      .where('date', '<=', Timestamp.fromDate(fifteenMinutesFromNow))
      .orderBy('date')
      .get();
    console.log('Query succeeded, found:', tasksSnapshot.size, 'tasks');
    if (tasksSnapshot.empty) {
      console.log('No tasks due in the next 10-15 minutes');
      return null;
    }

    const notifications = [];
    for (const doc of tasksSnapshot.docs) {
      const taskData = doc.data();
      const userId = doc.ref.parent.parent.id;
      const taskId = doc.id;
      console.log('Processing task:', taskId, 'for user:', userId, 'title:', taskData.title, 'date:', taskData.date.toDate().toISOString());

      const payload = {
        notification: {
          title: "Get ready for "+taskData.title,
          body: 'Due in 10 minutes!',
        },
        data: {
          taskId: taskId,
        },
        topic: userId,
      };

      notifications.push(
        messaging.send(payload)
          .then(() => console.log(`Notification sent to ${userId} for task ${taskId}`))
          .catch(error => console.error(`Error sending to ${userId}:`, error))
      );
    }

    await Promise.all(notifications);
  } catch (error) {
    console.error('Query failed:', error.code, error.message);
    throw error;
  }
  return null;
});