import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const sendChatNotification = functions
  .region('us-central1')
  .firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    try {
      const messageData = snap.data();
      if (!messageData) {
        console.log('❌ Žádná data zprávy');
        return null;
      }

      const senderId = messageData.sender;
      const senderName = messageData.senderName || 'Neznámý uživatel';
      const messageText = messageData.text || '';

      console.log('\n📱 ====== NOVÁ ZPRÁVA ======');
      console.log(`👤 Odesílatel: ${senderName} (${senderId})`);
      console.log(`💬 Text zprávy: ${messageText}`);
      console.log(`📝 Chat ID: ${context.params.chatId}`);
      console.log(`📝 Message ID: ${context.params.messageId}`);

      // Získání chat dokumentu
      const chatDoc = await admin.firestore()
        .collection('chats')
        .doc(context.params.chatId)
        .get();

      if (!chatDoc.exists) {
        console.log('❌ Chat neexistuje');
        return null;
      }

      const chatData = chatDoc.data();
      if (!chatData || !chatData.participants) {
        console.log('❌ Chybí data chatu nebo účastníci');
        return null;
      }

      // Filtrujeme příjemce (všichni kromě odesílatele)
      const recipients = chatData.participants.filter((uid: string) => uid !== senderId);
      console.log(`\n👥 Příjemci notifikace (${recipients.length}):`);
      recipients.forEach((uid: string) => console.log(`   - ${uid}`));

      // Pro každého příjemce
      const notificationPromises = recipients.map(async (recipientId: string) => {
        try {
          const userDoc = await admin.firestore()
            .collection('users')
            .doc(recipientId)
            .get();

          const userData = userDoc.data();
          if (!userData?.fcmToken) {
            console.log(`\n⚠️ Uživatel ${recipientId} nemá FCM token`);
            return;
          }

          // Kontrola, zda má uživatel povolené notifikace
          if (userData.notificationsEnabled === false) {
            console.log(`\n🔕 Uživatel ${recipientId} má vypnuté notifikace`);
            return;
          }

          console.log(`\n📱 Odesílám notifikaci:`);
          console.log(`   Příjemce: ${recipientId}`);
          console.log(`   FCM Token: ${userData.fcmToken}`);

          const message = {
            token: userData.fcmToken,
            notification: {
              title: `${senderName} Vám posílá zprávu`,
              body: "Klikněte pro zobrazení zprávy"
            },
            android: {
              notification: {
                channelId: 'chat_messages',
                priority: 'max' as const,
                defaultSound: true,
                icon: '@drawable/ic_notification'
              }
            },
            data: {
              chatId: context.params.chatId,
              messageId: context.params.messageId,
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              senderName: senderName,
              senderEmail: messageData.senderEmail || ''
            }
          };

          const response = await admin.messaging().send(message);
          console.log(`\n✅ Notifikace odeslána:`);
          console.log(`   Message ID: ${response}`);
          console.log(`   Příjemce: ${recipientId}`);
          console.log(`   Status: Úspěšně doručeno na zařízení`);
        } catch (error) {
          console.error(`\n❌ Chyba při odesílání notifikace:`);
          console.error(`   Příjemce: ${recipientId}`);
          console.error(`   Chyba: ${error}`);
        }
      });

      await Promise.all(notificationPromises);
      console.log('\n✨ ====== ZPRACOVÁNÍ DOKONČENO ======\n');
      return null;
    } catch (error) {
      console.error('\n❌ ====== KRITICKÁ CHYBA ======');
      console.error('Chyba při zpracování notifikace:', error);
      console.error('================================\n');
      return null;
    }
  });

// Funkce pro odesílání notifikací přímo z aplikace
export const sendDirectNotification = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    try {
      const { senderName, message, fcmToken } = data;

      if (!fcmToken) {
        console.log('❌ Chybí FCM token');
        return null;
      }

      console.log('\n📱 ====== PŘÍMÁ NOTIFIKACE ======');
      console.log(`👤 Odesílatel: ${senderName}`);
      console.log(`💬 Text zprávy: ${message}`);
      console.log(`📱 FCM Token: ${fcmToken}`);

      const notificationMessage = {
        token: fcmToken,
        notification: {
          title: `${senderName} Vám posílá zprávu`,
          body: message
        },
        android: {
          notification: {
            channelId: 'chat_messages',
            priority: 'max' as const,
            defaultSound: true,
            icon: '@drawable/ic_notification'
          }
        },
        data: {
          senderName: senderName,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
      };

      const response = await admin.messaging().send(notificationMessage);
      console.log(`\n✅ Notifikace odeslána:`);
      console.log(`   Message ID: ${response}`);
      console.log(`   Status: Úspěšně doručeno na zařízení`);
      console.log('\n✨ ====== ZPRACOVÁNÍ DOKONČENO ======\n');

      return { success: true, messageId: response };
    } catch (error) {
      console.error('\n❌ ====== KRITICKÁ CHYBA ======');
      console.error('Chyba při odesílání notifikace:', error);
      console.error('================================\n');
      throw new functions.https.HttpsError('internal', 'Chyba při odesílání notifikace');
    }
  }); 