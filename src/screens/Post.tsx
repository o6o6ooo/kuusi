import * as ImagePicker from "expo-image-picker";
import { doc, getDoc } from "firebase/firestore";
import { FolderOpen } from "phosphor-react-native";
import React, { useEffect, useState } from "react";
import { ActionSheetIOS, Alert, Image, Platform, Pressable, ScrollView, Text, TextInput, TouchableOpacity, useColorScheme, View } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import { auth, db } from "../lib/firebase";

export default function Post() {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;
    const [selectedGroup, setSelectedGroup] = useState<string | null>(null);
    const [userGroups, setUserGroups] = useState<string[]>([]);
    const [year, setYear] = useState("");
    const [hashtagInput, setHashtagInput] = useState("");
    const [hashtags, setHashtags] = useState<string[]>([]);
    const [images, setImages] = useState<any[]>([]);
    const currentUser = auth.currentUser;

    useEffect(() => {
        setSelectedGroup(null);
    }, []);

    useEffect(() => {
        const fetchUserGroups = async () => {
            if (!currentUser) return;
            try {
                const userDoc = await getDoc(doc(db, "users", currentUser.uid));
                const groupIds = userDoc.data()?.groups ?? [];

                if (groupIds.length > 0) {
                    const groupNames: string[] = [];

                    for (const groupId of groupIds) {
                        const groupDoc = await getDoc(doc(db, "groups", groupId));
                        const name = groupDoc.data()?.name;
                        if (name) groupNames.push(name);
                    }

                    setUserGroups(groupNames);
                }
            } catch (err) {
                console.warn("Failed to fetch groups:", err);
            }
        };

        fetchUserGroups();
    }, [currentUser]);

    const pickImages = async () => {
        const result = await ImagePicker.launchImageLibraryAsync({
            allowsMultipleSelection: true,
            quality: 0.5,
            mediaTypes: ImagePicker.MediaTypeOptions.Images,
        });
        if (!result.canceled) {
            setImages(result.assets);
        }
    };

    const handleTagKeyDown = () => {
        if (hashtagInput.trim()) {
            const clean = hashtagInput.trim().toLowerCase().replace(/^#/, "");
            if (!hashtags.includes(clean)) setHashtags([...hashtags, clean]);
            setHashtagInput("");
        }
    };

    const openGroupPicker = () => {
        if (Platform.OS === "ios") {
            ActionSheetIOS.showActionSheetWithOptions(
                {
                    options: [...userGroups, "Cancel"],
                    cancelButtonIndex: userGroups.length,
                },
                (index) => {
                    if (index < userGroups.length) setSelectedGroup(userGroups[index]);
                }
            );
        } else {
            Alert.alert("Select Group", "Group selection not implemented yet on Android");
        }
    };

    return (
        <View style={[tw`flex-1 items-center justify-center px-4`, { backgroundColor: theme.background }]}>
            <Text style={[tw`text-2xl font-semibold mb-4`, { color: theme.text }]}>
                Upload photos
            </Text>

            <View style={[tw`w-full p-4 rounded-2xl mb-6`, { backgroundColor: theme.card }]}>
                <TouchableOpacity onPress={pickImages} style={tw`flex-row items-center mb-4`}>
                    <FolderOpen size={24} color={theme.text} />
                    <Text style={[tw`ml-2 text-base`, { color: theme.text }]}>
                        {images.length === 0 ? "Choose photos" : `${images.length} selected`}
                    </Text>
                </TouchableOpacity>

                {images.length > 0 && (
                    <ScrollView horizontal showsHorizontalScrollIndicator={false} style={tw`mb-4`}>
                        {images.map((img, idx) => (
                            <Image key={idx} source={{ uri: img.uri }} style={tw`w-24 h-24 rounded-lg mr-2`} />
                        ))}
                    </ScrollView>
                )}

                <TextInput
                    style={[tw`rounded-xl px-4 py-3 mb-4`, { backgroundColor: theme.background, color: theme.text }]}
                    placeholder="Year"
                    value={year}
                    onChangeText={setYear}
                    keyboardType="numeric"
                />

                <TextInput
                    style={[tw`rounded-xl px-4 py-3 mb-4`, { backgroundColor: theme.background, color: theme.text }]}
                    placeholder="Hashtags"
                    value={hashtagInput}
                    onChangeText={setHashtagInput}
                    onSubmitEditing={handleTagKeyDown}
                />

                <View style={tw`flex-row flex-wrap gap-2 mb-4`}>
                    {hashtags.map((tag, i) => (
                        <View key={i} style={[tw`flex-row items-center px-2 py-1 rounded-full`, { backgroundColor: theme.primary }]}>
                            <Text style={[tw`text-xs font-medium text-white`]}>#{tag}</Text>
                            <TouchableOpacity onPress={() => { setHashtags(prev => prev.filter((_, index) => index !== i)); }}>
                                <Text style={[tw`text-xs font-bold ml-1`, { color: 'white' }]}>×</Text>
                            </TouchableOpacity>
                        </View>
                    ))}
                </View>

                <View style={tw`flex-row items-center justify-end gap-4`}>
                    {userGroups.length === 0 ? (
                        <Text style={[tw`text-xs`, { color: theme.text }]}>
                            Join a group to post photos.
                        </Text>
                    ) : (
                        <>
                            <TouchableOpacity onPress={openGroupPicker}>
                                <Text style={[tw`text-sm underline`, { color: theme.text }]}>
                                    {selectedGroup || "Pick a group to post"}
                                </Text>
                            </TouchableOpacity>
                            <Pressable
                                onPress={() => console.log("Upload pressed")}
                                disabled={!selectedGroup || images.length === 0}
                                style={({ pressed }) => [
                                    tw`px-4 py-2 rounded-full`,
                                    {
                                        backgroundColor: !selectedGroup || images.length === 0 ? theme.gray : theme.primary,
                                        opacity: pressed ? 0.8 : 1,
                                    },
                                ]}
                            >
                                <Text style={[tw`text-sm font-semibold`, { color: !selectedGroup || images.length === 0 ? theme.grayText : 'white' }]}>
                                    Upload
                                </Text>
                            </Pressable>
                        </>
                    )}
                </View>
            </View>
        </View>
    );
}