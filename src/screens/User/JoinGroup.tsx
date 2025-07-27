import { getAuth } from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import React, { useEffect, useState } from "react";
import { Text, TextInput, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";

let debounceTimer: NodeJS.Timeout;

export default function JoinGroup() {
    const [groupId, setGroupId] = useState('');
    const [password, setPassword] = useState('');
    const [message, setMessage] = useState('');
    const [messageType, setMessageType] = useState<'success' | 'error' | ''>('');
    const [canJoin, setCanJoin] = useState(false);
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    useEffect(() => {
        // 入力が揃っていない場合はメッセージと状態をクリア
        if (!groupId.trim() || !password.trim()) {
            setMessage('');
            setMessageType('');
            setCanJoin(false);
            return;
        }

        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            handleSearchGroup();
        }, 300);
    }, [groupId, password]);

    const handleSearchGroup = async () => {
        const rawGroupId = groupId.trim().toLowerCase();
        const rawPassword = password.trim();

        try {
            const doc = await firestore().collection("groups").doc(rawGroupId).get();
            if (!doc.exists) {
                setMessageType('error');
                setMessage("No matching group found. Please check the ID and password.");
                setCanJoin(false);
                return;
            }

            const data = doc.data();
            if (data?.password === rawPassword) {
                setMessageType('success');
                setMessage("Found a group!");
                setCanJoin(true);
            } else {
                setMessageType('error');
                setMessage("No matching group found. Please check the ID and password.");
                setCanJoin(false);
            }

            setTimeout(() => {
                setMessage('');
                setMessageType('');
            }, 3000);
        } catch (error) {
            console.error("❌ Failed to search group:", error);
            setMessageType('error');
            setMessage("Failed to search group. Please try again.");
            setCanJoin(false);
            setTimeout(() => {
                setMessage('');
                setMessageType('');
            }, 3000);
        }
    };

    const handleJoinGroup = async () => {
        const uid = getAuth().currentUser?.uid;
        const rawGroupId = groupId.trim().toLowerCase();

        if (!uid || !canJoin) return;

        try {
            await firestore().collection("users").doc(uid).set({
                groups: firestore.FieldValue.arrayUnion(rawGroupId),
            }, { merge: true });

            await firestore().collection("groups").doc(rawGroupId).update({
                members: firestore.FieldValue.arrayUnion(uid),
            });

            setGroupId('');
            setPassword('');
            setCanJoin(false);
            setMessageType('success');
            setMessage("Joined the group!");
            setTimeout(() => {
                setMessage('');
                setMessageType('');
            }, 3000);
        } catch (error) {
            console.error("❌ Failed to join group:", error);
            setMessageType('error');
            setMessage("Failed to join group. Please try again.");
            setTimeout(() => {
                setMessage('');
                setMessageType('');
            }, 3000);
        }
    };

    return (
        <View style={[tw`mb-4 p-4 rounded-xl flex-col`, { backgroundColor: theme.card }]}>
            <TextInput
                style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                placeholder="Group ID"
                autoCapitalize="none"
                value={groupId}
                onChangeText={setGroupId}
            />
            <TextInput
                style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                placeholder="Password"
                value={password}
                onChangeText={setPassword}
                secureTextEntry
            />

            {/* メッセージ表示 */}
            {message !== '' && (
                <Text
                    style={[
                        tw`mb-2 text-center font-medium`,
                        messageType === 'success' ? { color: theme.primary } : { color: 'tomato' }
                    ]}
                >
                    {message}
                </Text>
            )}

            <TouchableOpacity
                style={[
                    tw`px-4 py-2 rounded-full self-end`,
                    {
                        backgroundColor: canJoin ? theme.primary : theme.gray,
                    }
                ]}
                onPress={handleJoinGroup}
                disabled={!canJoin}
            >
                <Text style={[
                    tw`font-medium`,
                    { color: canJoin ? "#fff" : theme.grayText }
                ]}>
                    Join
                </Text>
            </TouchableOpacity>
        </View>
    );
}