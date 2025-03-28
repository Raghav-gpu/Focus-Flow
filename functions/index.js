const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const fetch = require('node-fetch');

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// Helper to fetch username
async function getUsername(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  return userDoc.exists ? userDoc.data().username : 'Unknown';
}

// Randomized streak messages
const streakMessages = [
  { title: 'Streak on Fire! 🔥', body: (username, streak) => `${username}, your ${streak}-day streak is blazing—keep it alive!` },
  { title: 'Don’t Break It! 💪', body: (username, streak) => `${username}, ${streak} days strong—task time to stay unstoppable!` },
  { title: 'Streak Hero! 🌟', body: (username, streak) => `${username}, ${streak} days of focus—don’t let it slip now!` },
  { title: 'Keep the Flame! 🕯️', body: (username, streak) => `${username}, your ${streak}-day streak needs fuel—task up!` },
];

const noStreakMessages = [
  { title: 'Start a Streak! 🚀', body: (username) => `${username}, daily tasks = epic streaks—begin your legend today!` },
  { title: 'Streak Time! 🌈', body: (username) => `${username}, no streak yet? Crush a task daily to shine!` },
  { title: 'Be a Streaker! 💥', body: (username) => `${username}, streaks are cool—start with one task today!` },
  { title: 'Streak Starter! ⚡', body: (username) => `${username}, zero streaks? One task daily changes that!` },
];

// Randomized milestone messages
const milestoneMessages = [
  { title: 'Milestone Master! 🏅', body: (username, streak) => `${username}, ${streak} days? You’re a focus legend—party time!` },
  { title: 'Streak Titan! ⚡', body: (username, streak) => `${username}, ${streak}-day streak unlocked—epic vibes only!` },
  { title: 'Focus Champion! 🌟', body: (username, streak) => `${username}, ${streak} days of glory—bow to your greatness!` },
  { title: 'Streak Slayer! 🔥', body: (username, streak) => `${username}, ${streak} days crushed—unstoppable force alert!` },
];

// Randomized task reminder messages
const taskReminderMessages = [
  { title: 'Task Time, Hero! ⚡', body: (username, title) => `${username}, ${title} is 10 mins away—zap it!` },
  { title: 'Ready, Champ? 🏆', body: (username, title) => `${username}, ${title} in 10—crush it like a boss!` },
  { title: 'Mission Alert! 🚀', body: (username, title) => `${username}, ${title} looms in 10—launch now!` },
  { title: 'Focus Up! 🌟', body: (username, title) => `${username}, ${title} hits in 10—be the star!` },
];

// Gamified challenge submission reminder messages
const challengeReminderMessages = [
  { title: 'Snap It, Legend! 📸', body: (username, title) => `${username}, ${title} awaits your epic shot—go!` },
  { title: 'Photo Quest! ⚔️', body: (username, title) => `${username}, conquer ${title} with a pic today!` },
  { title: 'Challenge Champ! 🏆', body: (username, title) => `${username}, ${title} calls—snap it, win it!` },
  { title: 'Pic Power! 💥', body: (username, title) => `${username}, unleash your ${title} photo now!` },
];

// --- Task Notifications ---

exports.checkUpcomingTasks = onSchedule('every 5 minutes', async () => {
  const now = new Date();
  const tenMinutesFromNow = new Date(now.getTime() + 10 * 60 * 1000);
  const fifteenMinutesFromNow = new Date(now.getTime() + 15 * 60 * 1000);

  const tasksSnapshot = await db.collectionGroup('tasks')
    .where('date', '>=', Timestamp.fromDate(tenMinutesFromNow))
    .where('date', '<=', Timestamp.fromDate(fifteenMinutesFromNow))
    .where('notificationSent', '!=', true)
    .orderBy('date')
    .get();

  if (tasksSnapshot.empty) return null;

  const notifications = [];
  for (const doc of tasksSnapshot.docs) {
    const taskData = doc.data();
    const userId = doc.ref.parent.parent.id;
    const taskId = doc.id;
    const username = await getUsername(userId);
    const randomIndex = Math.floor(Math.random() * taskReminderMessages.length);
    const message = taskReminderMessages[randomIndex];

    const payload = {
      notification: {
        title: message.title,
        body: message.body(username, taskData.title),
      },
      data: {
        type: 'task_reminder',
        taskId: taskId,
      },
      topic: userId,
    };

    notifications.push(
      messaging.send(payload)
        .then(async () => {
          await doc.ref.update({ notificationSent: true });
          console.log(`Task notification sent to ${userId} for task ${taskId}`);
        })
        .catch(error => console.error(`Error sending to ${userId}:`, error))
    );
  }

  await Promise.all(notifications);
});

// --- Friend Request Notifications ---

exports.notifyFriendRequest = onDocumentCreated('users/{receiverId}/friend_requests/{senderId}', async (event) => {
  const { senderId } = event.data.data();
  const receiverId = event.params.receiverId;
  const senderUsername = await getUsername(senderId);

  const payload = {
    notification: {
      title: 'New Friend Request!',
      body: `${senderUsername} wants to be your friend! 👋`,
    },
    data: {
      type: 'friend_request',
      requestId: event.params.senderId,
      senderId: senderId,
    },
    topic: receiverId,
  };

  await messaging.send(payload);
  console.log(`Friend request notification sent to ${receiverId}`);
});

exports.notifyFriendRequestAccepted = onDocumentDeleted('users/{receiverId}/friend_requests/{senderId}', async (event) => {
  const deletedData = event.data.data();
  if (!deletedData) return;
  const senderId = event.params.senderId;
  const receiverId = event.params.receiverId;

  const senderFriendDoc = await db.collection('users').doc(senderId).collection('friends').doc(receiverId).get();
  if (!senderFriendDoc.exists) return;

  const receiverUsername = await getUsername(receiverId);

  const payload = {
    notification: {
      title: 'Friend Request Accepted!',
      body: `${receiverUsername} is now your friend! 🎉`,
    },
    data: {
      type: 'friend_accepted',
      receiverId: receiverId,
    },
    topic: senderId,
  };

  await messaging.send(payload);
  console.log(`Friend accepted notification sent to ${senderId}`);
});

exports.notifyFriendRequestRejected = onDocumentDeleted('users/{receiverId}/friend_requests/{senderId}', async (event) => {
  const deletedData = event.data.data();
  if (!deletedData) return;
  const senderId = event.params.senderId;
  const receiverId = event.params.receiverId;

  const senderFriendDoc = await db.collection('users').doc(senderId).collection('friends').doc(receiverId).get();
  if (senderFriendDoc.exists) return;

  const receiverUsername = await getUsername(receiverId);

  const payload = {
    notification: {
      title: 'Friend Request Rejected',
      body: `${receiverUsername} declined your request. 😕`,
    },
    data: {
      type: 'friend_rejected',
      receiverId: receiverId,
    },
    topic: senderId,
  };

  await messaging.send(payload);
  console.log(`Friend rejected notification sent to ${senderId}`);
});

// --- Challenge Notifications ---

exports.notifyChallengeSent = onDocumentCreated('challenges/{challengeId}', async (event) => {
  const challenge = event.data.data();
  const { senderId, receiverId, title } = challenge;
  const senderUsername = await getUsername(senderId);

  const payload = {
    notification: {
      title: 'New Challenge!',
      body: `${senderUsername} challenged you: ${title}! 💪`,
    },
    data: {
      type: 'challenge_sent',
      challengeId: event.params.challengeId,
      senderId: senderId,
    },
    topic: receiverId,
  };

  await messaging.send(payload);
  console.log(`Challenge sent notification to ${receiverId}`);
});

exports.notifyChallengeAccepted = onDocumentUpdated('challenges/{challengeId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status !== 'pending' || after.status !== 'active') return;

  const { senderId, receiverId, title } = after;
  const receiverUsername = await getUsername(receiverId);

  const payload = {
    notification: {
      title: 'Challenge Accepted!',
      body: `${receiverUsername} accepted your challenge: ${title}! 🚀`,
    },
    data: {
      type: 'challenge_accepted',
      challengeId: event.params.challengeId,
    },
    topic: senderId,
  };

  await messaging.send(payload);
  console.log(`Challenge accepted notification sent to ${senderId}`);
});

exports.notifyChallengeDeclined = onDocumentDeleted('challenges/{challengeId}', async (event) => {
  const challenge = event.data.data();
  if (challenge.status !== 'pending') return;

  const { senderId, receiverId, title } = challenge;
  const receiverUsername = await getUsername(receiverId);

  const payload = {
    notification: {
      title: 'Challenge Declined',
      body: `${receiverUsername} declined your challenge: ${title}. 😞`,
    },
    data: {
      type: 'challenge_declined',
      challengeId: event.params.challengeId,
    },
    topic: senderId,
  };

  await messaging.send(payload);
  console.log(`Challenge declined notification sent to ${senderId}`);
});

exports.notifyPhotoSubmitted = onDocumentCreated('challenges/{challengeId}/submissions/{submissionId}', async (event) => {
  const submission = event.data.data();
  const challengeId = event.params.challengeId;
  const challengeDoc = await db.collection('challenges').doc(challengeId).get();
  const challenge = challengeDoc.data();
  const { senderId, receiverId, title } = challenge;
  const submitterId = submission.userId;
  const opponentId = submitterId === senderId ? receiverId : senderId;
  const submitterUsername = await getUsername(submitterId);

  const payload = {
    notification: {
      title: 'Progress Sent!',
      body: `${submitterUsername} submitted a photo for ${title}. 📸`,
    },
    data: {
      type: 'photo_submitted',
      challengeId: challengeId,
      submissionId: event.params.submissionId,
    },
    topic: opponentId,
  };

  await messaging.send(payload);
  console.log(`Photo submitted notification sent to ${opponentId}`);
});

exports.notifyPhotoVerifiedOrDeclined = onDocumentUpdated('challenges/{challengeId}/submissions/{submissionId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.verified !== null || after.verified === null) return;

  const challengeId = event.params.challengeId;
  const challengeDoc = await db.collection('challenges').doc(challengeId).get();
  const challenge = challengeDoc.data();
  const { title } = challenge;
  const submitterId = after.userId;
  const isVerified = after.verified;

  const payload = {
    notification: {
      title: isVerified ? 'Photo Verified!' : 'Photo Declined',
      body: isVerified
        ? `Your photo for ${title} was approved! ✅`
        : `Your photo for ${title} was rejected. 😔`,
    },
    data: {
      type: isVerified ? 'photo_verified' : 'photo_declined',
      challengeId: challengeId,
      submissionId: event.params.submissionId,
    },
    topic: submitterId,
  };

  await messaging.send(payload);
  console.log(`Photo ${isVerified ? 'verified' : 'declined'} notification sent to ${submitterId}`);
});

exports.notifyChallengeCompleted = onDocumentUpdated('challenges/{challengeId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === 'completed' || after.status !== 'completed') return;

  const { senderId, receiverId, title, winner } = after;
  const senderUsername = await getUsername(senderId);
  const receiverUsername = await getUsername(receiverId);

  const senderPayload = {
    notification: {
      title: winner === senderId ? 'You Won!' : winner === 'tie' ? 'Challenge Tied!' : 'Challenge Lost',
      body: winner === senderId
        ? `Congrats, you beat ${receiverUsername} in ${title}! 🏆`
        : winner === 'tie'
          ? `${title} ended in a tie with ${receiverUsername}! 🤝`
          : `${receiverUsername} won ${title}. Better luck next time! 💪`,
    },
    data: {
      type: winner === senderId ? 'challenge_won' : winner === 'tie' ? 'challenge_tied' : 'challenge_lost',
      challengeId: event.params.challengeId,
    },
    topic: senderId,
  };

  const receiverPayload = {
    notification: {
      title: winner === receiverId ? 'You Won!' : winner === 'tie' ? 'Challenge Tied!' : 'Challenge Lost',
      body: winner === receiverId
        ? `Congrats, you beat ${senderUsername} in ${title}! 🏆`
        : winner === 'tie'
          ? `${title} ended in a tie with ${senderUsername}! 🤝`
          : `${senderUsername} won ${title}. Better luck next time! 💪`,
    },
    data: {
      type: winner === receiverId ? 'challenge_won' : winner === 'tie' ? 'challenge_tied' : 'challenge_lost',
      challengeId: event.params.challengeId,
    },
    topic: receiverId,
  };

  await Promise.all([
    messaging.send(senderPayload),
    messaging.send(receiverPayload),
  ]);
  console.log(`Challenge completed notifications sent to ${senderId} and ${receiverId}`);
});

exports.notifyChallengeExited = onDocumentUpdated('challenges/{challengeId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === 'exited' || after.status !== 'exited') return;

  const { senderId, receiverId, title, exitedBy } = after;
  const exiterUsername = await getUsername(exitedBy);
  const opponentId = exitedBy === senderId ? receiverId : senderId;

  const payload = {
    notification: {
      title: 'You Won! 🥳🎉',
      body: `${exiterUsername} left the challenge: ${title}.`,
    },
    data: {
      type: 'challenge_exited',
      challengeId: event.params.challengeId,
    },
    topic: opponentId,
  };

  await messaging.send(payload);
  console.log(`Challenge exited notification sent to ${opponentId}`);
});

// --- Daily Tips Notifications ---

exports.generateDailyTips = onSchedule('0 0 * * *', async () => { // Midnight UTC = 5:30 AM IST
  const now = new Date();
  const dateStr = now.toISOString().split('T')[0].split('-').reverse().join(''); // DDMMYYYY
  const weekday = now.toLocaleString('en-US', { weekday: 'long' });
  const time = now.toISOString().split('T')[1].slice(0, 5); // HH:mm

  const prompt = `Current date: ${dateStr}, Current day: ${weekday}, Current time: ${time}. Generate 3 unique, concise tips (max 15 words each) for focus and productivity tailored to today. Use a warm, motivating tone with 1 emoji per tip.`;
  
  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer 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',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'google/gemini-2.0-flash-001',
      messages: [
        {
          role: 'system',
          content: 'You are a warm, friendly assistant generating unique focus and productivity tips. Just give the tips and nothing else, be motivating and give really helpful tips for daily life productivity.',
        },
        { role: 'user', content: prompt },
      ],
    }),
  });

  const data = await response.json();
  const tipsText = data.choices[0].message.content.trim();
  const tips = tipsText.split('\n').map(tip => tip.replace(/^\d+\.\s*/, ''));

  const tipDoc = {
    tip1: tips[0] || 'Start small—tiny steps build big focus! 🌟',
    tip2: tips[1] || 'Clear your desk—less clutter, more clarity! 🧹',
    tip3: tips[2] || 'Take a break—refresh for sharper focus! ☕',
    timestamp: Timestamp.fromDate(now),
  };

  await db.collection('tips').doc(dateStr).set(tipDoc);
  console.log(`Generated tips for ${dateStr}:`, tipDoc);

  const usersSnapshot = await db.collection('users').get();
  if (usersSnapshot.empty) {
    console.log('No users found for daily tips');
    return;
  }

  const times = [
    { hour: 3, tip: 'tip1', number: '1' },  // 3:00 AM UTC = 9 AM IST
    { hour: 8, tip: 'tip2', number: '2' },  // 8:00 AM UTC = 2 PM IST
    { hour: 13, tip: 'tip3', number: '3' }, // 1:00 PM UTC = 7 PM IST
  ];

  for (const { hour, tip, number } of times) {
    const scheduledTime = new Date(now);
    scheduledTime.setUTCHours(hour, 0, 0, 0);
    if (scheduledTime < now) scheduledTime.setDate(scheduledTime.getDate() + 1);

    const delayMs = scheduledTime - now;
    setTimeout(async () => {
      const notifications = [];
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const payload = {
          notification: {
            title: `Focus Tip #${number}`,
            body: tipDoc[tip],
          },
          data: {
            type: 'daily_tip',
            tipNumber: number,
            date: dateStr,
          },
          topic: userId,
        };

        notifications.push(
          messaging.send(payload)
            .then(() => console.log(`Tip #${number} sent to ${userId}`))
            .catch(error => console.error(`Error sending tip #${number} to ${userId}:`, error))
        );
      }
      await Promise.all(notifications);
      console.log(`Sent tip #${number} to ${usersSnapshot.size} users`);
    }, delayMs);
  }
});

// --- Streak Reminders ---

exports.sendStreakReminders = onSchedule('every day 14:30', async () => { // 8 PM IST = 2:30 PM UTC
  const usersSnapshot = await db.collection('users').get();
  const now = new Date();
  const todayStr = now.toISOString().split('T')[0];

  const notifications = [];
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();
    const username = userData.username || 'User';
    const streak = userData.streak || 0;

    let message;
    if (streak > 0) {
      const randomIndex = Math.floor(Math.random() * streakMessages.length);
      message = streakMessages[randomIndex];
    } else {
      const randomIndex = Math.floor(Math.random() * noStreakMessages.length);
      message = noStreakMessages[randomIndex];
    }

    const payload = {
      notification: {
        title: message.title,
        body: message.body(username, streak),
      },
      data: {
        type: 'streak_reminder',
        date: todayStr,
      },
      topic: userId,
    };

    notifications.push(
      messaging.send(payload)
        .then(() => console.log(`Streak reminder sent to ${userId}`))
        .catch(error => console.error(`Error sending to ${userId}:`, error))
    );
  }

  await Promise.all(notifications);
});

// --- Challenge Submission Reminders ---

async function sendChallengeSubmissionRemindersLogic() {
  const now = new Date();
  const todayStr = now.toISOString().split('T')[0]; // YYYY-MM-DD
  const startOfDay = new Date(todayStr); // Midnight today UTC
  const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000 - 1); // 23:59:59 today UTC

  console.log('Current time (UTC):', now.toISOString());

  // Query all active challenges
  const challengesSnapshot = await db.collection('challenges')
    .where('status', '==', 'active')
    .get();

  if (challengesSnapshot.empty) {
    console.log('No active challenges found');
    return null;
  }

  console.log(`Found ${challengesSnapshot.size} active challenges`);
  challengesSnapshot.forEach(doc => {
    console.log(`Challenge ${doc.id}:`, doc.data());
  });

  const userReminders = new Map();
  for (const doc of challengesSnapshot.docs) {
    const challenge = doc.data();
    const { senderId, receiverId, title } = challenge;
    const challengeId = doc.id;

    for (const userId of [senderId, receiverId]) {
      const submissionsSnapshot = await db.collection('challenges')
        .doc(challengeId)
        .collection('submissions')
        .where('userId', '==', userId)
        .where('timestamp', '>=', Timestamp.fromDate(startOfDay))
        .where('timestamp', '<=', Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

      if (submissionsSnapshot.empty) {
        console.log(`No submission today for ${userId} in ${challengeId}`);
        const userMessage = userReminders.get(userId) || { count: 0, titles: [] };
        userMessage.count++;
        userMessage.titles.push(title);
        userReminders.set(userId, userMessage);
      } else {
        console.log(`Submission found for ${userId} in ${challengeId}`);
      }
    }
  }

  if (userReminders.size === 0) {
    console.log('No users need reminders today');
    return null;
  }

  const notifications = [];
  for (const [userId, { count, titles }] of userReminders) {
    const username = await getUsername(userId);
    const randomIndex = Math.floor(Math.random() * challengeReminderMessages.length);
    const message = challengeReminderMessages[randomIndex];
    const body = count > 1
      ? `${username}, conquer ${count} challenges with photo power today! ⚡`
      : message.body(username, titles[0]);

    const payload = {
      notification: {
        title: count > 1 ? 'Multi-Challenge Mayhem! 🎮' : message.title,
        body,
      },
      data: {
        type: 'challenge_submission_reminder',
        date: todayStr,
      },
      topic: userId,
    };

    notifications.push(
      messaging.send(payload)
        .then(() => console.log(`Challenge reminder sent to ${userId} for ${titles.join(', ')}`))
        .catch(error => console.error(`Error sending to ${userId}:`, error))
    );
  }

  await Promise.all(notifications);
  console.log(`Sent ${notifications.length} reminders`);
}

exports.sendChallengeSubmissionRemindersMorning = onSchedule('30 4 * * *', async () => { // 10 AM IST = 4:30 AM UTC
  await sendChallengeSubmissionRemindersLogic();
});

exports.sendChallengeSubmissionRemindersAfternoon = onSchedule('30 8 * * *', async () => { // 2 PM IST = 8:30 AM UTC
  await sendChallengeSubmissionRemindersLogic();
});

exports.sendChallengeSubmissionRemindersEvening = onSchedule('30 13 * * *', async () => { // 7 PM IST = 1:30 PM UTC
  await sendChallengeSubmissionRemindersLogic();
});

// --- Weekly Recap ---

exports.weeklyRecap = onSchedule('0 8 * * 0', async () => { // Every Sunday at 8 AM UTC (1:30 PM IST)
  const usersSnapshot = await db.collection('users').get();
  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const notifications = [];
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();
    const username = userData.username || 'User';
    const streak = userData.streak || 0;

    const tasksSnapshot = await db.collection('users').doc(userId).collection('tasks')
      .where('date', '>=', Timestamp.fromDate(weekAgo))
      .where('status', '==', 'Done')
      .get();

    const taskCount = tasksSnapshot.size;

    const payload = {
      notification: {
        title: 'Weekly Recap! 📊',
        body: `${username}, ${taskCount} tasks done, ${streak}-day streak—great week! 🌟`,
      },
      data: {
        type: 'weekly_recap',
        taskCount: taskCount.toString(),
        streak: streak.toString(),
      },
      topic: userId,
    };

    notifications.push(
      messaging.send(payload)
        .then(() => console.log(`Weekly recap sent to ${userId}`))
        .catch(error => console.error(`Error sending to ${userId}:`, error))
    );
  }

  await Promise.all(notifications);
});

// --- Milestone Celebrations ---

exports.notifyMilestoneCelebration = onSchedule('every day 15:00', async () => { // 8:30 PM IST = 3:00 PM UTC
  const milestoneThresholds = [5, 10, 20, 30, 50];
  const usersSnapshot = await db.collection('users').get();
  const now = new Date();
  const todayStr = now.toISOString().split('T')[0];

  const notifications = [];
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();
    const username = userData.username || 'User';
    const streak = userData.streak || 0;

    if (!milestoneThresholds.includes(streak)) continue;

    const tasksSnapshot = await db.collection('users').doc(userId).collection('tasks')
      .where('date', '>=', Timestamp.fromDate(new Date(todayStr)))
      .where('status', '==', 'Done')
      .limit(1)
      .get();

    if (tasksSnapshot.empty) continue;

    const randomIndex = Math.floor(Math.random() * milestoneMessages.length);
    const message = milestoneMessages[randomIndex];

    const payload = {
      notification: {
        title: message.title,
        body: message.body(username, streak),
      },
      data: {
        type: 'milestone_celebration',
        streak: streak.toString(),
        date: todayStr,
      },
      topic: userId,
    };

    notifications.push(
      messaging.send(payload)
        .then(() => console.log(`Milestone celebration sent to ${userId} for ${streak}-day streak`))
        .catch(error => console.error(`Error sending to ${userId}:`, error))
    );
  }

  await Promise.all(notifications);
});