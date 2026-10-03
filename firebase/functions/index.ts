import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * Cloud Function: onSplitActivityCreated
 * Triggered automatically when an activity document is created under splitGroups/{groupId}/activities/{activityId}
 */
export const onSplitActivityCreated = functions.firestore
  .document("splitGroups/{groupId}/activities/{activityId}")
  .onCreate(async (snapshot, context) => {
    const activity = snapshot.data();
    if (!activity) return;

    const { groupId, actorId, title, body, expenseId, type } = activity;

    // 1. Fetch Split Group document to retrieve all group member UIDs / IDs
    const groupDoc = await admin.firestore().collection("splitGroups").doc(groupId).get();
    if (!groupDoc.exists) return;
    const groupData = groupDoc.data()!;
    const memberIds: string[] = groupData.memberIds || [];
    const memberUids: string[] = groupData.memberUids || [];

    // Combine members to ensure all recipients are matched
    const allMembers = Array.from(new Set([...memberIds, ...memberUids]));

    // 2. Exclude actor (The user who triggered the action must NOT receive push)
    const recipientIds = allMembers.filter((id) => id !== actorId && id !== activity.actorName);
    if (recipientIds.length === 0) return;

    // 3. Fetch recipient FCM tokens & verify notification preferences
    const tokensToSend: string[] = [];
    
    // Chunk query to respect Firestore 'in' limit of 30
    for (let i = 0; i < recipientIds.length; i += 30) {
      const chunk = recipientIds.slice(i, i + 30);
      const usersSnapshot = await admin.firestore()
        .collection("users")
        .where("userId", "in", chunk)
        .get();

      usersSnapshot.forEach((userDoc) => {
        const uData = userDoc.data();
        // Check user preferences (Do not send if user disabled splitNotifications)
        if (uData.preferences?.splitNotifications !== false) {
          if (Array.isArray(uData.fcmTokens)) {
            tokensToSend.push(...uData.fcmTokens);
          }
        }
      });
    }

    if (tokensToSend.length === 0) {
      console.log(`No active FCM tokens found for group ${groupId} recipients.`);
      return;
    }

    // 4. Construct FCM Multicast Push Payload
    const payload: admin.messaging.MulticastMessage = {
      tokens: tokensToSend,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: type || "expense_activity",
        groupId: groupId,
        expenseId: expenseId || "",
        actorId: actorId || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "eleghart_split_channel",
          icon: "ic_notification",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    // 5. Send FCM Multicast Push Notification
    const response = await admin.messaging().sendEachForMulticast(payload);
    console.log(`Sent FCM push for group ${groupId}. Success: ${response.successCount}, Failures: ${response.failureCount}`);

    // 6. Automatically clean up invalid/expired FCM tokens
    const invalidTokens: string[] = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const error = resp.error;
        if (
          error?.code === "messaging/invalid-registration-token" ||
          error?.code === "messaging/registration-token-not-registered"
        ) {
          invalidTokens.push(tokensToSend[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      console.log(`Cleaning up ${invalidTokens.length} expired FCM tokens.`);
      for (const userId of recipientIds) {
        await admin.firestore().collection("users").doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });
      }
    }
  });
