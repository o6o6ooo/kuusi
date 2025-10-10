import { useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { signOut } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import React, { useEffect, useState } from "react";
import { ScrollView, Text, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";
import { auth, db } from "../../lib/firebase";
import type { RootStackParamList } from "../../navigation/RootNavigator";
import CreateGroup from "./CreateGroup";
import EditGroup from "./EditGroup";
import JoinGroup from "./JoinGroup";
import Profile from "./Profile";
import Subscription from "./Subscription";

export default function User() {
    const [displayName, setDisplayName] = useState('');
    const [email, setEmail] = useState('');
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;
    const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();

    useEffect(() => {
        const fetchUser = async () => {
            const uid = auth.currentUser?.uid;
            if (!uid) return;

            try {
                const userRef = doc(db, "users", uid);
                const docSnap = await getDoc(userRef);
                const data = docSnap.data();
                if (data) {
                    setDisplayName(data.name || '');
                    setEmail(data.email || '');
                }
            } catch (error) {
                console.error("❌ Failed to fetch user:", error);
            }
        };

        fetchUser();
    }, []);

    async function handleSignOut() {
        try {
            await signOut(auth);
            console.log("✅ Signed out");
            navigation.replace("SignIn");
        } catch (error) {
            console.error("❌ Sign-out error:", error);
        }
    }

    return (
        <View style={[tw`flex-1 items-center px-4 pt-10`, { backgroundColor: theme.background }]}>
            <ScrollView style={tw`px-4`}>
                {/* Header */}
                <View style={tw`flex flex-row px-4 pt-12 pb-4 gap-3`}>
                    <Text style={[tw`text-xl font-semibold`, { color: theme.text }]}>Hi, {displayName}</Text>
                    <Text style={[tw`text-xs mt-2`, { color: theme.grayText }]}>{email}</Text>
                </View>

                <Profile />
                {/* Your groups section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Your groups</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>Manage your groups.</Text>
                <EditGroup />

                {/* Create group section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Create a group</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>Invite your beloved ones.</Text>
                <CreateGroup />

                {/* Join a group section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Join a group</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>Search for a group with ID and password.</Text>
                <JoinGroup />

                {/* Your storage section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Your storage</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>You've posted so far.</Text>
                <View style={[tw`p-4 rounded-xl flex-row`, { backgroundColor: theme.card }]} />
                <Text style={[tw`text-xs mb-8`, { color: theme.grayText }]}>Need more storage?{' '}
                    <Text style={[tw`text-xs`, { color: theme.primary }]}>Get premium.</Text>
                </Text>

                {/* Your hashtags section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Your hashtags</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>Display your hashtags.</Text>
                <View style={[tw`mb-4 p-4 rounded-xl flex-row`, { backgroundColor: theme.card }]} />

                {/* Subscription section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Subscription</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>Upgrade to premium, cancel anytime.</Text>
                <Subscription />
                <Text style={[tw`text-xs mb-8`, { color: theme.grayText }]}>Already got premium?{' '}
                    <Text style={[tw`text-xs`, { color: theme.primary }]}>Restore purchase.</Text>
                </Text>
                {/* Link to your accounts section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Link to your accounts</Text>
                <View style={[tw`mb-4 p-4 rounded-xl flex-row`, { backgroundColor: theme.card }]} />

                {/* Footer */}
                <Text style={[tw`underline my-8`, { color: theme.primary }]} onPress={handleSignOut}>Sign Out</Text>
                <Text style={[tw`text-xs mb-1`, { color: theme.grayText }]}>Contact to get help</Text>
                <Text style={[tw`text-xs mb-1`, { color: theme.grayText }]}>Privacy policy</Text>
                <Text style={[tw`text-xs mb-1`, { color: theme.grayText }]}>Terms of service</Text>
                <Text style={[tw`text-xs mb-8`, { color: theme.grayText }]}>Made with love by{' '}
                    <Text style={[tw`text-xs`, { color: theme.primary }]}>Sakura Wallace</Text>
                </Text>
            </ScrollView>
        </View>
    );
}