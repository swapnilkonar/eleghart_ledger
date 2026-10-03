const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onSplitActivityCreated = onDocumentCreated(
  "splitGroups/{groupId}/activities/{activityId}",
  async (event) => {
    const activity = event.data.data();
    if (!activity) return;

    const groupId = event.params.groupId;
    
    // Fetch group members
    const groupSnap = await admin.firestore().doc(`splitGroups/${groupId}`).get();
    const memberUids = groupSnap.data()?.memberUids || [];
    const memberIds = groupSnap.data()?.memberIds || [];
    const allMembers = Array.from(new Set([...memberUids, ...memberIds]));

    // Filter out the actor who triggered the activity
    const recipients = allMembers.filter(id => id !== activity.actorId && id !== activity.actorName);

    for (const uid of recipients) {
      const userSnap = await admin.firestore().doc(`users/${uid}`).get();
      if (!userSnap.exists) continue;
      const user = userSnap.data();

      // Skip if push is disabled or if user has no registered FCM tokens
      if (user?.preferences?.splitNotifications === false || user?.preferences?.pushEnabled === false || !user?.fcmTokens?.length) {
        continue;
      }

      await admin.messaging().sendEachForMulticast({
        tokens: user.fcmTokens,
        notification: {
          title: activity.title,
          body: activity.body
        },
        data: {
          type: activity.type || "expense_activity",
          groupId: groupId,
          expenseId: activity.expenseId || "",
          actorId: activity.actorId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        android: {
          notification: { channelId: "eleghart_split_channel" }
        },
        apns: {
          payload: { aps: { sound: "default" } }
        }
      });
    }
  }
);
