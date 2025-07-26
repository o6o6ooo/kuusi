import { getAuth, signOut } from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import { useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import React, { useEffect, useState } from "react";
import { ScrollView, Text, TextInput, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";
import type { RootStackParamList } from "../../navigation/RootNavigator";
import Profile from "./Profile";

export default function User() {
    const [displayName, setDisplayName] = useState('');
    const [email, setEmail] = useState('');
    const [newGroupName, setNewGroupName] = useState('');
    const [groupName, setGroupName] = useState('');
    const [groupId, setGroupId] = useState('');
    const [groups, setGroups] = useState<any[]>([]);
    const [currentGroupId, setCurrentGroupId] = useState<string | null>(null);
    const [groupLink, setGroupLink] = useState('');
    const [members, setMembers] = useState<any[]>([]);
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
                    setEmail(data.email);
                }
            } catch (error) {
                console.error('❌ Failed to fetch user:', error);
            }
        };

        fetchUser();
    }, []);


    const handleSaveProfile = () => {
        // update firestore
    };

    const handleSwitchGroup = (groupId: string) => {
        const selectedGroup = groups.find(group => group.id === groupId);
        if (!selectedGroup) return;

        setCurrentGroupId(groupId);
        setGroupName(selectedGroup.name || '');
        setGroupLink(selectedGroup.shareLink || '');
        setMembers(selectedGroup.membersData || []);
    };

    const handleSaveGroup = async () => {
    };

    const handleCreateGroup = () => {
        if (!groupId.trim() || !newGroupName.trim()) {
            // set error message 'Please fill in all fields.'
            return;
        }
        setGroupId('');
        setGroupName('');
        // create group process
    };

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
                <Profile onSave={handleSaveProfile} />
                {/* Your groups section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Your groups</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>Manage your groups.</Text>
                <View style={[tw`mb-4 p-4 rounded-xl`, { backgroundColor: theme.card }]}>

                </View>
                {/* Create a groups section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Create a groups</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>Invite your beloved ones.</Text>
                <View style={[tw`mb-4 p-4 rounded-xl flex-col`, { backgroundColor: theme.card }]}>
                    <TextInput
                        style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                        placeholder="group ID"
                    />
                    <TextInput
                        style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                        placeholder="group name"
                    />
                    <Text style={[tw`text-center text-xs self-start mb-1 underline`, { color: theme.grayText }]}>Group link</Text>
                    <TouchableOpacity style={[tw`text-white px-4 py-2 rounded-full self-end`, { backgroundColor: theme.primary }]} onPress={handleSaveProfile}>
                        <Text style={tw`text-white font-medium`}>Create</Text>
                    </TouchableOpacity>
                </View>
                {/* Your storage section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Your storage</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>You've posted so far.</Text>
                <View style={[tw`mb-4 p-4 rounded-xl flex-row`, { backgroundColor: theme.card }]}>

                </View>
                {/* Your hashtags section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Your hashtags</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>Display your hashtags.</Text>
                <View style={[tw`mb-4 p-4 rounded-xl flex-row`, { backgroundColor: theme.card }]}>

                </View>
                {/* Subscription section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Subscription</Text>
                <Text style={[tw`text-center text-xs self-start mb-1`, { color: theme.grayText }]}>Upgrade to premium, cancel anytime.</Text>
                <View style={[tw`mb-4 p-4 rounded-xl flex-row`, { backgroundColor: theme.card }]}>

                </View>
                {/* Link to your accounts section */}
                <Text style={[tw`text-center text-lg self-start font-semibold`, { color: theme.text }]}>Link tou your accounts</Text>
                <View style={[tw`mb-4 p-4 rounded-xl flex-row`, { backgroundColor: theme.card }]}>

                </View>
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