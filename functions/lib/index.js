"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendChatNotification = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
exports.sendChatNotification = functions.firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
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
        const recipients = chatData.participants.filter((uid) => uid !== senderId);
        console.log(`\n👥 Příjemci notifikace (${recipients.length}):`);
        recipients.forEach((uid) => console.log(`   - ${uid}`));
        // Pro každého příjemce
        const notificationPromises = recipients.map(async (recipientId) => {
            try {
                const userDoc = await admin.firestore()
                    .collection('users')
                    .doc(recipientId)
                    .get();
                const userData = userDoc.data();
                if (!(userData === null || userData === void 0 ? void 0 : userData.fcmToken)) {
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
                            priority: 'max',
                            defaultSound: true,
                            icon: '@drawable/ic_notification'
                        }
                    },
                    data: {
                        chatId: context.params.chatId,
                        messageId: context.params.messageId,
                        click_action: 'FLUTTER_NOTIFICATION_CLICK'
                    }
                };
                const response = await admin.messaging().send(message);
                console.log(`\n✅ Notifikace odeslána:`);
                console.log(`   Message ID: ${response}`);
                console.log(`   Příjemce: ${recipientId}`);
                console.log(`   Status: Úspěšně doručeno na zařízení`);
            }
            catch (error) {
                console.error(`\n❌ Chyba při odesílání notifikace:`);
                console.error(`   Příjemce: ${recipientId}`);
                console.error(`   Chyba: ${error}`);
            }
        });
        await Promise.all(notificationPromises);
        console.log('\n✨ ====== ZPRACOVÁNÍ DOKONČENO ======\n');
        return null;
    }
    catch (error) {
        console.error('\n❌ ====== KRITICKÁ CHYBA ======');
        console.error('Chyba při zpracování notifikace:', error);
        console.error('================================\n');
        return null;
    }
});
//# sourceMappingURL=index.js.map