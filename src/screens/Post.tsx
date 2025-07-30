import * as ImageManipulator from 'expo-image-manipulator';
import * as ImagePicker from "expo-image-picker";
import { addDoc, collection, doc, getDoc, increment, serverTimestamp, updateDoc } from "firebase/firestore";
import { getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import { FolderOpen } from "phosphor-react-native";
import React, { useEffect, useState } from "react";
import { ActionSheetIOS, Alert, Image, Platform, Pressable, ScrollView, Text, TextInput, TouchableOpacity, useColorScheme, View } from "react-native";
import uuid from 'react-native-uuid';
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import { auth, db, storage } from "../lib/firebase";

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
    const [loading, setLoading] = useState(false);
    const [message, setMessage] = useState("");
    const [messageType, setMessageType] = useState<"success" | "error" | "">("");

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
            mediaTypes: ["images"],
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

    const compressImage = async (uri: string, width: number, compressRatio = 0.7) => {
        const result = await ImageManipulator.manipulateAsync(
            uri,
            [{ resize: { width } }],
            {
                compress: compressRatio,
                format: ImageManipulator.SaveFormat.JPEG,
            }
        );
        return result;
    };

    const handleUpload = async () => {
        // validation checks
        const currentYear = new Date().getFullYear();
        const yearNumber = parseInt(year);

        if (!year || isNaN(yearNumber) || yearNumber < 1950 || yearNumber > currentYear) {
            setMessage("Please enter a valid year between 1950 and " + currentYear);
            setMessageType("error");
            return;
        }

        if (hashtags.length > 5) {
            setMessage("You can only add up to 5 hashtags.");
            setMessageType("error");
            return;
        }

        if (!selectedGroup || images.length === 0) {
            setMessage("Group and image selection is required.");
            setMessageType("error");
            return;
        }

        setLoading(true);
        setMessage("");
        setMessageType("");
        const userId = auth.currentUser?.uid;
        let totalUploadedMB = 0;
        let uploadedCount = 0;

        for (const image of images) {
            try {
                const id = uuid.v4() as string;

                // 1. preview image (compressed to 1000px width)
                const preview = await compressImage(image.uri, 800, 0.65);
                console.log("Compressed image URI:", preview.uri);
                const previewBlob = await (await fetch(preview.uri)).blob();
                console.log("Blob:", previewBlob);
                const previewRef = ref(storage, `photos/${userId}/${id}_preview.jpg`);
                const previewMetadata = { contentType: "image/jpeg", };
                await uploadBytes(previewRef, previewBlob, previewMetadata);
                const previewURL = await getDownloadURL(previewRef);
                const photoSizeMB = Number((previewBlob.size / 1024 / 1024).toFixed(2));
                totalUploadedMB += photoSizeMB;
                uploadedCount += 1;

                // 2. thumbnail image (compressed to 200px width)
                const thumbnail = await compressImage(image.uri, 140, 0.5);
                const thumbBlob = await (await fetch(thumbnail.uri)).blob();
                const thumbRef = ref(storage, `photos/${userId}/${id}_thumb.jpg`);
                const thumbMetadata = { contentType: "image/jpeg" };
                await uploadBytes(thumbRef, thumbBlob, thumbMetadata);
                const thumbURL = await getDownloadURL(thumbRef);
                const thumbSizeMB = Number((thumbBlob.size / 1024 / 1024).toFixed(2));
                totalUploadedMB += thumbSizeMB;
                const subtotalSizeMB = Number((photoSizeMB + thumbSizeMB).toFixed(2));

                // 3. store photo metadata in photos collection
                await addDoc(collection(db, 'photos'), {
                    photo_url: previewURL,
                    thumbnail_url: thumbURL,
                    group_id: selectedGroup,
                    posted_by: userId,
                    year: yearNumber,
                    hashtags,
                    size_mb: subtotalSizeMB,
                    created_at: serverTimestamp(),
                });

                // 4. store hashtags in hashtags collection
                if (hashtags.length > 0) {
                    const hashtagsRef = collection(db, 'hashtags');
                    for (const tag of hashtags) {
                        await addDoc(hashtagsRef, {
                            hashtag: tag,
                            group_id: selectedGroup,
                            user_id: userId,
                            show_in_feed: true,
                            updated_at: serverTimestamp(),
                        });
                    }
                }

            } catch (err: any) {
                console.warn("Upload failed for one image:", image.uri, err);
                console.warn("Error code:", err.code);
                console.warn("Error message:", err.message);
                setMessage("Some uploads failed. Check your connection.");
                setMessageType("error");
            }
        }

        if (uploadedCount > 0) {
            await updateDoc(doc(db, 'users', auth.currentUser!.uid), {
                upload_count: increment(uploadedCount),
                upload_total_mb: increment(Number(totalUploadedMB.toFixed(2))),
            });
        }

        setMessage("Upload finished!");
        setMessageType("success");
        setTimeout(() => setMessage(""), 3000);
        setYear("");
        setHashtags([]);
        setImages([]);
        setLoading(false);
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
                            <View key={idx} style={tw`relative mr-2`}>
                                <Image
                                    source={{ uri: img.uri }}
                                    style={tw`w-24 h-24 rounded-lg`}
                                />
                                <TouchableOpacity
                                    onPress={() => {
                                        setImages(prev => prev.filter((_, i) => i !== idx));
                                    }}
                                    style={[tw`absolute top-1 right-1 rounded-full w-4 h-4 items-center justify-center`, { backgroundColor: theme.background, opacity: 0.6 }]}
                                >
                                    <Text style={[tw`text-xs font-bold`, { color: theme.text }]}>×</Text>
                                </TouchableOpacity>
                            </View>
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

                {message !== "" && (
                    <Text
                        style={[
                            tw`mb-2 text-center font-medium`,
                            messageType === 'success'
                                ? { color: theme.primary }
                                : { color: 'tomato' },
                        ]}
                    >
                        {message}
                    </Text>
                )}

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
                                onPress={handleUpload}
                                disabled={!selectedGroup || images.length === 0 || loading}
                                style={({ pressed }) => [
                                    tw`px-4 py-2 rounded-full`,
                                    {
                                        backgroundColor: !selectedGroup || images.length === 0 || loading
                                            ? theme.gray
                                            : theme.primary,
                                        opacity: pressed ? 0.8 : 1,
                                    },
                                ]}
                            >
                                <Text style={[tw`text-sm font-semibold`, {
                                    color: !selectedGroup || images.length === 0 || loading ? theme.grayText : 'white',
                                }]}>
                                    {loading ? "Uploading..." : "Upload"}
                                </Text>
                            </Pressable>
                        </>
                    )}
                </View>
            </View>
        </View>
    );
}