/* eslint-disable */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.database();

exports.sendPushOnNewNotification = functions.database
    .ref("/Walkers/{walkerId}/notification/{notifId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.val();
        const {walkerId, notifId} = context.params;

        console.log(`[FCM] Notif baru: ${notifId} untuk walker: ${walkerId}`);
        console.log("[FCM] Data:", JSON.stringify(data));

        const tokenSnap = await db
            .ref(`/Walkers/${walkerId}/fcmToken`)
            .get();

        if (!tokenSnap.exists() || !tokenSnap.val()) {
            console.warn(`[FCM] Token tidak ditemukan untuk ${walkerId}`);
            return null;
        }

        const fcmToken = tokenSnap.val();

        const levelLabel = {
            darurat: "DARURAT",
            tinggi: "Tinggi",
            waspada: "Waspada",
        };
        const levelPrefix = levelLabel[data.level] || "Peringatan";

        const message = {
            token: fcmToken,
            notification: {
                title: levelPrefix + " - " + (data.title || "SmartWalker Alert"),
                body: data.description || "Periksa kondisi lansia segera.",
            },
            data: {
                notifId: notifId,
                walkerId: walkerId,
                level: data.level || "tinggi",
                title: data.title || "",
                desc: data.description || "",
                latitude: String(data.latitude || 0),
                longitude: String(data.longitude || 0),
                timestamp: data.timestamp || "",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "smartwalker_alerts",
                    sound: "default",
                    color: data.level === "darurat" ? "#EF4444"
                        : data.level === "tinggi" ? "#F97316"
                            : "#22C55E",
                },
            },
            apns: {
                headers: {"apns-priority": "10"},
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        "content-available": 1,
                    },
                },
            },
        };

        try {
            const resp = await admin.messaging().send(message);
            console.log(`[FCM] Berhasil dikirim: ${resp}`);
        } catch (err) {
            if (
                err.code === "messaging/invalid-registration-token" ||
                err.code === "messaging/registration-token-not-registered"
            ) {
                console.warn("[FCM] Token invalid, hapus dari RTDB");
                await db.ref(`/Walkers/${walkerId}/fcmToken`).remove();
            } else {
                console.error("[FCM] Error:", err);
            }
        }

        return null;
    });