import auth from "@react-native-firebase/auth";
import { useNavigation } from "@react-navigation/native";
import * as ImagePicker from "expo-image-picker";
import { FolderOpen } from "phosphor-react-native";
import React, { useState } from "react";
import { ActionSheetIOS, Alert, Image, Platform, Pressable, ScrollView, Text, TextInput, TouchableOpacity, useColorScheme, View } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";

export default function Post() {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;
    const navigation = useNavigation();
    const [selectedGroup, setSelectedGroup] = useState<string | null>(null);
    const [userGroups, setUserGroups] = useState<string[]>([]);
    const [year, setYear] = useState("");
    const [hashtagInput, setHashtagInput] = useState("");
    const [hashtags, setHashtags] = useState<string[]>([]);
    const [images, setImages] = useState<any[]>([]);
    const [showPreviewRow, setShowPreviewRow] = useState(false);

    const currentUser = auth().currentUser;

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

    const handleHashtagSubmit = () => {
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
                    <TouchableOpacity onPress={() => setShowPreviewRow(!showPreviewRow)}>
                        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={tw`mb-4`}>
                            {images.map((img, idx) => (
                                <Image key={idx} source={{ uri: img.uri }} style={tw`w-16 h-16 rounded-lg mr-2`} />
                            ))}
                        </ScrollView>
                    </TouchableOpacity>
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
                    onSubmitEditing={handleHashtagSubmit}
                />
                <View style={tw`flex-row flex-wrap gap-2 mb-4`}>
                    {hashtags.map((tag, i) => (
                        <Text key={i} style={[tw`text-xs px-2 py-1 rounded-full font-medium text-white`, { backgroundColor: theme.primary }]}>
                            #{tag}
                        </Text>
                    ))}
                </View>

                <View style={tw`flex-row items-center justify-end gap-4`}>
                    <TouchableOpacity onPress={openGroupPicker}>
                        <Text style={[tw`text-sm underline`, { color: theme.text }]}>
                            {selectedGroup || "Choose a group"}
                        </Text>
                    </TouchableOpacity>
                    <Pressable
                        onPress={() => console.log("Upload pressed")}
                        disabled={!selectedGroup || images.length === 0}
                        style={({ pressed }) => [tw`px-4 py-2 rounded-xl`,
                        { backgroundColor: !selectedGroup || images.length === 0 ? theme.gray : theme.primary, opacity: pressed ? 0.8 : 1, },]}>
                        <Text style={[tw`text-sm font-semibold`, { color: !selectedGroup || images.length === 0 ? theme.grayText : 'text-white' }]}>
                            Upload
                        </Text>
                    </Pressable>
                </View>
            </View>
        </View>
    );
}