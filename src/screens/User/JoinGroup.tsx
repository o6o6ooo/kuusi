import { arrayUnion, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import React, { useEffect, useState } from "react";
import { Text, TextInput, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";
import { auth, db } from "../../lib/firebase";

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
            const docRef = doc(db, 'groups', rawGroupId);
            const snapshot = await getDoc(docRef);

            if (!snapshot.exists() || snapshot.data()?.password !== rawPassword) {
                setMessageType('error');
                setMessage("No matching group found. Please check the ID and password.");
                setCanJoin(false);
                return;
            }

            setMessageType('success');
            setMessage("Found a group!");
            setCanJoin(true);
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
        const uid = auth.currentUser?.uid;
        const rawGroupId = groupId.trim().toLowerCase();
        if (!uid || !canJoin) return;

        try {
            await setDoc(
                doc(db, 'users', uid),
                {
                    groups: arrayUnion(rawGroupId),
                },
                { merge: true }
            );

            await updateDoc(
                doc(db, 'groups', rawGroupId),
                {
                    members: arrayUnion(uid),
                }
            );

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
                placeholderTextColor={theme.grayText}
                value={groupId}
                onChangeText={setGroupId}
            />
            <TextInput
                style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                placeholder="Password"
                secureTextEntry
                placeholderTextColor={theme.grayText}
                value={password}
                onChangeText={setPassword}
            />

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