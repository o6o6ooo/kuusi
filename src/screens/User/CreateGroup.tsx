import { getApp } from "firebase/app";
import { getAuth } from 'firebase/auth';
import { arrayUnion, doc, getFirestore, serverTimestamp, setDoc } from 'firebase/firestore';
import React, { useState } from "react";
import { Text, TextInput, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";

export default function CreateGroup() {
    const [groupId, setGroupId] = useState('');
    const [groupName, setGroupName] = useState('');
    const [password, setPassword] = useState('');
    const [message, setMessage] = useState('');
    const [messageType, setMessageType] = useState<'success' | 'error' | ''>('');
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    const handleCreateGroup = async () => {
        setMessage('');
        setMessageType('');

        const rawGroupId = groupId.trim().toLowerCase();
        const rawGroupName = groupName.trim();
        const rawPassword = password.trim();

        if (!rawGroupId || !rawGroupName || !rawPassword) {
            setMessageType('error');
            setMessage("All fields are required.");
            setTimeout(() => {
                setMessage('');
                setMessageType('');
            }, 3000);
            return;
        }

        try {
            const app = getApp();
            const db = getFirestore(app);
            const uid = getAuth(app).currentUser?.uid;
            if (!uid) throw new Error("User not authenticated");

            await setDoc(doc(db, "groups", rawGroupId), {
                name: rawGroupName,
                password: rawPassword,
                members: [uid],
                createdAt: serverTimestamp(),
            });

            await setDoc(doc(db, "users", uid), {
                groups: arrayUnion(rawGroupId),
            }, { merge: true });

            setGroupId('');
            setGroupName('');
            setPassword('');
            setMessageType('success');
            setMessage("Group created successfully!");
            setTimeout(() => {
                setMessage('');
                setMessageType('');
            }, 3000);
        } catch (error) {
            console.error("❌ Failed to create group:", error);
            setMessageType('error');
            setMessage("Failed to create group. Please try again.");
        }
    };

    return (
        <View style={[tw`mb-4 p-4 rounded-xl flex-col`, { backgroundColor: theme.card }]}>
            <TextInput
                style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                placeholder="group ID"
                autoCapitalize="none"
                value={groupId}
                onChangeText={setGroupId}
            />
            <TextInput
                style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                placeholder="group name"
                value={groupName}
                onChangeText={setGroupName}
            />
            <TextInput
                style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                placeholder="password"
                value={password}
                onChangeText={setPassword}
                secureTextEntry
            />

            {/* messages */}
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
                style={[tw`text-white px-4 py-2 rounded-full self-end`, { backgroundColor: theme.primary }]}
                onPress={handleCreateGroup}
            >
                <Text style={tw`text-white font-medium`}>Create</Text>
            </TouchableOpacity>
        </View>
    );
}