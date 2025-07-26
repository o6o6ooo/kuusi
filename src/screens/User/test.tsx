import { getAuth } from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import React, { useEffect, useState } from "react";
import { Text, TextInput, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";

export default function Profile({ onSave }: { onSave: (displayName: string, bgColour: string) => void }) {
    const [displayName, setDisplayName] = useState('');
    const [icon, setIcon] = useState('');
    const [bgColour, setBgColour] = useState('#ccc');
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

    const handleSave = () => {
        onSave(displayName, bgColour);
    };

    return (
        <View style={[tw`mb-8 p-4 rounded-xl flex-row`, { backgroundColor: theme.card }]}>
            {/* current icon */}
            <View style={tw`items-center justify-center w-1/3`}>
                <View
                    style={[
                        tw`w-20 h-20 rounded-full items-center border-2 justify-center shadow-md`,
                        { backgroundColor: bgColour, borderColor: "white" },
                    ]}
                >
                    <Text style={tw`text-4xl`}>{icon}</Text>
                </View>
            </View>

            {/* name input & bg color buttons */}
            <View style={tw`w-2/3 justify-center px-2 gap-4`}>
                <TextInput
                    style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                    value={displayName}
                    onChangeText={setDisplayName}
                />
                <View style={tw`flex-row flex-wrap gap-3`}>
                    {avatarColors.map((color, index) => (
                        <TouchableOpacity
                            key={index}
                            onPress={() => setBgColour(color)}
                            style={[tw`w-8 h-8 rounded-full border-2 shadow-md`, { backgroundColor: color, borderColor: "white" }]}
                        />
                    ))}
                </View>
                <TouchableOpacity
                    style={[tw`text-white px-4 py-2 rounded-full self-end`, { backgroundColor: theme.primary }]}
                    onPress={handleSave}
                >
                    <Text style={tw`text-white font-medium`}>Save</Text>
                </TouchableOpacity>
            </View>
        </View>
    );
}