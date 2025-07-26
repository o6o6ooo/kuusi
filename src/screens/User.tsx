import { getAuth, signOut } from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import { useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import React, { useEffect, useState } from "react";
import { ScrollView, Text, TextInput, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import type { RootStackParamList } from "../navigation/RootNavigator";

export default function User() {
    const [displayName, setDisplayName] = useState('');
    const [email, setEmail] = useState('');
    const [icon, setIcon] = useState('');
    const [bgColour, setBgColour] = useState('#ccc');
    const avatarColors = ['#A5C3DE', '#C7E9F1', '#C8E3D4', '#D9E5FF', '#DCD6F7', '#FADADD', '#FBE7A1', '#FFB3C1', '#FFD6A5', '#FFF9B1'];

    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;
    const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();

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
                    setEmail(data.email);
                }
            } catch (error) {
                console.error('❌ Failed to fetch user:', error);
            }
        };

        fetchUser();
    }, []);

    async function handleSignOut() {
        try {
            await signOut(getAuth());
            console.log('✅ Signed out');
            navigation.replace("SignIn");
        } catch (error) {
            console.error('❌ Sign-out error:', error);
        }
    }

    return (
        <View style={[tw`flex-1 items-center px-4 pt-10`, { backgroundColor: theme.background }]}>
            {/* Header */}
            <View style={tw`flex flex-row px-4 pt-12 pb-4 gap-3`}>
                <Text style={[tw`text-xl font-semibold`, { color: theme.text }]}>Hi, {displayName}</Text>
                <Text style={[tw`text-xs mt-2`, { color: theme.grayText }]}>{email}</Text>
            </View>
            <ScrollView style={tw`px-4`}>
                {/* Edit Profile Section */}
                <View style={[tw`mb-8 p-4 rounded-xl flex-row`, { backgroundColor: theme.card }]}>

                    {/* current icon */}
                    <View style={tw`items-center justify-center w-1/3`}>
                        <View style={[
                            tw`w-20 h-20 rounded-full items-center border-2 justify-center shadow-md`,
                            { backgroundColor: bgColour, borderColor: 'white' }
                        ]}>
                            <Text style={tw`text-4xl`}>{icon}</Text>
                        </View>
                    </View>

                    {/* name input & bg color buttons */}
                    <View style={tw`w-2/3 justify-center px-2 gap-4`}>
                        <TextInput
                            style={[tw`rounded-lg px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                            value={displayName}
                            onChangeText={setDisplayName}
                        />
                        <View style={tw`flex-row flex-wrap gap-3`}>
                            {avatarColors.map((color, index) => (
                                <TouchableOpacity
                                    key={index}
                                    onPress={() => setBgColour(color)}
                                    style={[
                                        tw`w-8 h-8 rounded-full border-2 shadow-md`,
                                        { backgroundColor: color, borderColor: 'white' }
                                    ]}
                                />
                            ))}
                        </View>
                        <TouchableOpacity style={[tw`text-white px-4 py-2 rounded-full self-end`, { backgroundColor: theme.primary }]}>
                            <Text style={tw`text-white font-medium`}>Save</Text>
                        </TouchableOpacity>
                    </View>
                </View>
            </ScrollView>
            {/* アイコン */}
            <View
                style={[
                    tw`mt-10 relative w-24 h-24 rounded-full border-2 shadow-md items-center justify-center`,
                    { backgroundColor: bgColour, borderColor: 'white' },
                ]}
            >
                <Text style={tw`text-5xl`}>{icon}</Text>
            </View>

            {/* Sign Out ボタン */}
            <TouchableOpacity
                onPress={handleSignOut}
                style={[tw`mt-10 px-5 py-3 rounded-lg`, { backgroundColor: theme.primary }]}
            >
                <Text style={tw`text-white text-center`}>Sign Out</Text>
            </TouchableOpacity>

        </View>
    );
}