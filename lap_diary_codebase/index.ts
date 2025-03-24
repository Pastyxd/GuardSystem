import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const sendChatNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const messageData = snap.data();
      if (!messageData) {
        console.log('Žádná data zprávy');
        return null;
      }

      const senderId = messageData.sender;
      const senderName = messageData.senderName || 'Neznámý uživatel';
      const messageText = messageData.text || '';

      // Získání chat dokumentu
      const chatDoc = await admin.firestore()
        .collection('chats')
        .doc(context.params.chatId)
        .get();

      if (!chatDoc.exists) {
        console.log('Chat neexistuje');
        return null;
      }

      const chatData = chatDoc.data();
      if (!chatData || !chatData.participants) {
        console.log('Chybí data chatu nebo účastníci');
        return null;
      }

      // Filtrujeme příjemce (všichni kromě odesílatele)
      const recipients = chatData.participants.filter((uid: string) => uid !== senderId);

      // Pro každého příjemce
      const notificationPromises = recipients.map(async (recipientId: string) => {
        try {
          const userDoc = await admin.firestore()
            .collection('users')
            .doc(recipientId)
            .get();

          const userData = userDoc.data();
          if (!userData?.fcmToken) {
            console.log(`Uživatel ${recipientId} nemá FCM token`);
            return;
          }

          await admin.messaging().send({
            token: userData.fcmToken,
            notification: {
              title: senderName,
              body: messageText
            },
            android: {
              notification: {
                channelId: 'chat_messages',
                priority: 'high',
                defaultSound: true,
                icon: '@drawable/ic_notification'
              }
            },
            data: {
              chatId: context.params.chatId,
              messageId: context.params.messageId,
              click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
          });

          console.log(`Notifikace odeslána uživateli ${recipientId}`);
        } catch (error) {
          console.error(`Chyba při odesílání notifikace uživateli ${recipientId}:`, error);
        }
      });

      await Promise.all(notificationPromises);
      return null;
    } catch (error) {
      console.error('Chyba při zpracování notifikace:', error);
      return null;
    }
  }); 