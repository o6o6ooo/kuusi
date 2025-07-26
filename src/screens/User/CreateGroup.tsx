import { getAuth } from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import React, { useState } from "react";
import { Text, TextInput, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";

export default function CreateGroup() {
    const [groupId, setGroupId] = useState('');
    const [groupName, setGroupName] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    const handleCreateGroup = async () => {
        setError('');
        setSuccess('');
        const rawGroupId = groupId.trim().toLowerCase();
        const rawGroupName = groupName.trim();
        const rawPassword = password.trim();

        if (!rawGroupId || !rawGroupName || !rawPassword) {
            setError("All fields are required.");
            return;
        }

        try {
            await firestore().collection("groups").doc(rawGroupId).set({
                name: rawGroupName,
                password: rawPassword,
                members: [getAuth().currentUser?.uid],
                createdAt: firestore.FieldValue.serverTimestamp(),
            });

            await firestore().collection("users").doc(getAuth().currentUser?.uid).set({
                groups: firestore.FieldValue.arrayUnion(rawGroupId),
            }, { merge: true });

            setGroupId('');
            setGroupName('');
            setPassword('');
            setSuccess("Group created successfully!");
        } catch (error) {
            console.error("❌ Failed to create group:", error);
            setError("Failed to create group. Please try again.");
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

            {error ? (
                <Text style={tw`text-red-500 mb-2`}>{error}</Text>
            ) : null}
            {success ? (
                <Text style={[tw`text-green-500 mb-2`, { color: theme.primary }]}>{success}</Text>
            ) : null}

            <TouchableOpacity
                style={[tw`text-white px-4 py-2 rounded-full self-end`, { backgroundColor: theme.primary }]}
                onPress={handleCreateGroup}
            >
                <Text style={tw`text-white font-medium`}>Create</Text>
            </TouchableOpacity>
        </View>
    );
}