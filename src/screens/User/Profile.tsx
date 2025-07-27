import { getAuth } from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import React, { useEffect, useState } from "react";
import { Text, TextInput, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";

export default function Profile() {
    const [displayName, setDisplayName] = useState('');
    const [icon, setIcon] = useState('');
    const [bgColour, setBgColour] = useState('#ccc');
    const [loading, setLoading] = useState(false);
    const [message, setMessage] = useState('');
    const [messageType, setMessageType] = useState<'success' | 'error' | ''>('');

    const avatarColors = ['#A5C3DE', '#C7E9F1', '#C8E3D4', '#D9E5FF', '#DCD6F7', '#FADADD', '#FBE7A1', '#FFB3C1', '#FFD6A5', '#FFF9B1'];
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    useEffect(() => {
        const fetchUser = async () => {
            const uid = getAuth().currentUser?.uid;
            if (!uid) return;

            try {
                const doc = await firestore().collection('users').doc(uid).get();
                const data = doc.data();
                if (data) {
                    setDisplayName(data.name);
                    setIcon(data.icon);
                    setBgColour(data.bgColour);
                }
            } catch (error) {
                console.error('❌ Failed to fetch user:', error);
            }
        };
        fetchUser();
    }, []);

    const handleSave = async () => {
        const uid = getAuth().currentUser?.uid;
        if (!uid) {
            setMessageType('error');
            setMessage('User not logged in');
            return;
        }
        if (!displayName.trim()) {
            setMessageType('error');
            setMessage('Display name cannot be empty');
            setTimeout(() => {
                setMessage('');
                setMessageType('');
            }, 3000);
            return;
        }

        setLoading(true);
        setMessage('');
        try {
            await firestore().collection('users').doc(uid).update({
                name: displayName,
                icon: icon,
                bgColour: bgColour,
                updatedAt: firestore.FieldValue.serverTimestamp(),
            });
            setMessageType('success');
            setMessage('Profile saved successfully!');
            setTimeout(() => {
                setMessage('');
                setMessageType('');
            }, 3000);
        } catch (error) {
            console.error('❌ Failed to save profile:', error);
            setMessageType('error');
            setMessage('Failed to save profile');
        } finally {
            setLoading(false);
        }
    };

    return (
        <View style={[tw`mb-8 p-4 rounded-xl`, { backgroundColor: theme.card }]}>
            <View style={tw`flex-row items-center mb-4`}>
                {/* icon */}
                <View
                    style={[
                        tw`w-20 h-20 rounded-full items-center border-2 justify-center shadow-md`,
                        { backgroundColor: bgColour, borderColor: "white" },
                    ]}
                >
                    <Text style={tw`text-4xl`}>{icon}</Text>
                </View>
                {/* display name */}
                <TextInput
                    style={[tw`flex-1 ml-4 rounded-xl px-4 py-3`, { backgroundColor: theme.background, color: theme.text }]}
                    value={displayName}
                    onChangeText={setDisplayName}
                    editable={!loading}
                />
            </View>

            {/* bg colours */}
            <View style={tw`flex-row flex-wrap mb-4`}>
                {avatarColors.map((color, index) => (
                    <TouchableOpacity
                        key={index}
                        onPress={() => setBgColour(color)}
                        style={[tw`w-8 h-8 rounded-full border-2 shadow-md mr-3 mb-3`, { backgroundColor: color, borderColor: "white" }]}
                        disabled={loading}
                    />
                ))}
            </View>

            {/* Save */}
            <View style={tw`flex-row justify-end mb-3`}>
                <TouchableOpacity
                    style={[tw`px-4 py-2 rounded-full`, { backgroundColor: theme.primary, opacity: loading ? 0.6 : 1 }]}
                    onPress={handleSave}
                    disabled={loading}
                >
                    <Text style={tw`text-white font-medium`}>{loading ? "Saving..." : "Save"}</Text>
                </TouchableOpacity>
            </View>

            {/* message */}
            {message !== '' && (
                <Text
                    style={[
                        tw`text-center font-medium`,
                        messageType === 'success' ? { color: theme.primary } : { color: 'tomato' }
                    ]}
                >
                    {message}
                </Text>
            )}
        </View>
    );
}