import auth from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import React, { useEffect, useState } from 'react';
import { ScrollView, Text, TextInput, TouchableOpacity, View, useColorScheme } from 'react-native';
import tw from 'twrnc';
import { DarkTheme, LightTheme } from "../../constants/theme";


type Group = {
    id: string;
    name: string;
    password: string;
};

export default function EditGroup() {
    const [groups, setGroups] = useState<Group[]>([]);
    const [selectedGroupId, setSelectedGroupId] = useState<string | null>(null);
    const [groupName, setGroupName] = useState('');
    const [password, setPassword] = useState('');
    const [success, setSuccess] = useState('');
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    useEffect(() => {
        const fetchGroups = async () => {
            const uid = auth().currentUser?.uid;
            if (!uid) return;

            const userDoc = await firestore().collection('users').doc(uid).get();
            const groupIds: string[] = userDoc.data()?.groups || [];

            const groupDocs = await Promise.all(groupIds.map(id => firestore().collection('groups').doc(id).get()));
            const fetchedGroups = groupDocs.map(doc => ({ id: doc.id, ...doc.data() })) as Group[];
            setGroups(fetchedGroups);

            if (fetchedGroups.length > 0) {
                const first = fetchedGroups[0];
                setSelectedGroupId(first.id);
                setGroupName(first.name);
                setPassword(first.password);
            }
        };

        fetchGroups();
    }, []);

    const handleSelectGroup = (group: Group) => {
        setSelectedGroupId(group.id);
        setGroupName(group.name);
        setPassword(group.password);
        setSuccess('');
    };

    const handleSave = async () => {
        if (!selectedGroupId) return;

        await firestore().collection('groups').doc(selectedGroupId).update({
            name: groupName.trim(),
            password: password.trim(),
        });

        setSuccess('Group updated successfully!');
        setTimeout(() => setSuccess(''), 3000);
    };

    return (
        <View style={[tw`mb-4 p-4 rounded-xl flex-col`, { backgroundColor: theme.card }]}>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                {groups.map(group => {
                    const isSelected = group.id === selectedGroupId;

                    return (
                        <TouchableOpacity
                            key={group.id}
                            onPress={() => handleSelectGroup(group)}
                            style={[tw`px-3 py-1 mr-2 rounded-full`,
                            { backgroundColor: isSelected ? theme.primary : theme.card, borderWidth: 1, borderColor: theme.primary }]}>
                            <Text style={[tw`text-xs font-medium`, { color: isSelected ? "#ffffff" : theme.primary }]}>{group.name}</Text>
                        </TouchableOpacity>
                    );
                })}
            </ScrollView>

            {selectedGroupId && (
                <View style={tw`p-4 rounded-xl`}>
                    <Text style={[tw`text-xs m-2`, { color: theme.text }]}>Group ID:{' '}
                        <Text style={[tw`mb-2 font-semibold`, { color: theme.primary }]}>{selectedGroupId}</Text>
                    </Text>

                    <Text style={[tw`text-xs m-2`, { color: theme.text }]}>Name</Text>
                    <TextInput
                        value={groupName}
                        onChangeText={setGroupName}
                        style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                    />

                    <Text style={[tw`text-xs m-2`, { color: theme.text }]}>Password</Text>
                    <TextInput
                        value={password}
                        onChangeText={setPassword}
                        style={[tw`rounded-xl px-4 py-3 mb-2`, { backgroundColor: theme.background, color: theme.text }]}
                        secureTextEntry
                    />

                    <TouchableOpacity
                        style={[tw`text-white px-4 py-2 rounded-full self-end`, { backgroundColor: theme.primary }]}
                        onPress={handleSave}
                    >
                        <Text style={tw`text-white font-medium`}>Save</Text>
                    </TouchableOpacity>

                    {success !== '' && (
                        <Text style={tw`text-green-600 mt-2 text-sm text-center`}>{success}</Text>
                    )}
                </View>
            )}
        </View>
    );
}