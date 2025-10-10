import MasonryList from "@react-native-seoul/masonry-list";
import { collection, doc, getDoc, getDocs, orderBy, query, where } from "firebase/firestore";
import React, { useEffect, useState } from "react";
import { ActivityIndicator, Image, ScrollView, Text, TouchableOpacity, useColorScheme, useWindowDimensions, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import { auth, db } from "../lib/firebase";

type Photo = {
    id: string;
    photo_url?: string;
    thumbnail_url?: string;
    previewUrl?: string;
    created_at?: any;
    group_id?: string;
    year?: number;
    [key: string]: any;
};

export default function Home() {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;
    const { width: screenWidth } = useWindowDimensions();
    const [photos, setPhotos] = useState<Photo[]>([]);
    const [groups, setGroups] = useState<any[]>([]);
    const [hashtags, setHashtags] = useState<any[]>([]);
    const [selectedTab, setSelectedTab] = useState("all");
    const [loading, setLoading] = useState(true);

    // number of columns: iPhone: 2, iPad: 3, larger: 4
    const numColumns = screenWidth < 600 ? 2 : screenWidth < 1000 ? 3 : 4;

    useEffect(() => {
        const fetchData = async () => {
            setLoading(true);
            try {
                // groups
                const userDoc = await getDoc(doc(db, "users", auth.currentUser!.uid));
                const groupIds = userDoc.exists() ? userDoc.data().groups || [] : [];

                const groupDocs = await Promise.all(
                    groupIds.map(async (gid: string) => {
                        const gDoc = await getDoc(doc(db, "groups", gid));
                        return gDoc.exists() ? { id: gDoc.id, ...gDoc.data() } : null;
                    })
                );
                setGroups(groupDocs.filter(Boolean));

                // hashtags
                const q = query(
                    collection(db, "hashtags"),
                    where("user_id", "==", auth.currentUser!.uid),
                    where("show_in_feed", "==", true)
                );
                const hashtagSnap = await getDocs(q);
                setHashtags(hashtagSnap.docs.map((d) => d.data()));
            } catch (e) {
                console.error("Error fetching groups/hashtags", e);
            } finally {
                setLoading(false);
            }
        };
        fetchData();

        const fetchPhotos = async () => {
            try {
                const q = query(collection(db, "photos"), orderBy("created_at", "desc"));
                const snapshot = await getDocs(q);

                const photoData = snapshot.docs.map((docSnap) => {
                    const data = docSnap.data();
                    return {
                        id: docSnap.id,
                        ...data,
                        previewUrl: data.thumbnail_url || data.photo_url || null,
                    };
                }) as Photo[];

                setPhotos(photoData.filter((p) => p.previewUrl));
            } catch (err) {
                console.error("Error fetching photos:", err);
            } finally {
                setLoading(false);
            }
        };
        fetchPhotos();
    }, []);

    // Tabs: All, Groups..., Hashtags...
    const tabs = [
        { key: "all", label: "All" },
        ...groups.map((g) => ({ key: `group-${g.id}`, label: g.name })),
        ...hashtags.map((h) => ({ key: `hashtag-${h.hashtag}`, label: `#${h.hashtag}` })),
    ];

    // Filter photos based on selected tab
    const filteredPhotos = photos.filter((p) => {
        if (selectedTab === "all") return true;
        if (selectedTab.startsWith("group-"))
            return p.group_id === selectedTab.replace("group-", "");
        if (selectedTab.startsWith("hashtag-"))
            return p.hashtags?.includes(selectedTab.replace("hashtag-", ""));
        return true;
    });

    if (loading) {
        return (
            <View style={[tw`flex-1 items-center justify-center`, { backgroundColor: theme.background }]}>
                <ActivityIndicator size="large" color={theme.text} />
                <Text style={[tw`mt-4`, { color: theme.text }]}>Loading photos...</Text>
            </View>
        );
    }

    return (
        <SafeAreaView style={[tw`flex-1 px-3`, { backgroundColor: theme.background }]}>
            {/* Hashtag bar */}
            <View style={tw`py-2`}>
                <ScrollView
                    horizontal
                    showsHorizontalScrollIndicator={false}
                >
                    {tabs.map((tab) => {
                        const isSelected = tab.key === selectedTab;
                        return (
                            <TouchableOpacity
                                key={tab.key}
                                onPress={() => setSelectedTab(tab.key)}
                                style={[
                                    tw`px-3 py-1 mr-2 rounded-full`,
                                    {
                                        alignSelf: "flex-start",
                                        backgroundColor: isSelected ? theme.primary : theme.card,
                                        borderWidth: 1,
                                        borderColor: theme.primary,
                                    },
                                ]}
                            >
                                <Text
                                    style={[
                                        tw`text-xs font-medium`,
                                        { color: isSelected ? "#ffffff" : theme.primary },
                                    ]}
                                >
                                    {tab.label}
                                </Text>
                            </TouchableOpacity>
                        );
                    })}
                </ScrollView>
            </View>

            {/* Masonry layout */}
            <MasonryList
                data={photos}
                keyExtractor={(item) => item.id}
                numColumns={numColumns}
                showsVerticalScrollIndicator={false}
                style={{ marginHorizontal: -6 }}
                contentContainerStyle={tw`pb-20`}
                renderItem={({ item, i }: { item: unknown; i: number }) => {
                    const photo = item as Photo;
                    const [ratio, setRatio] = useState(1);

                    useEffect(() => {
                        if (photo.previewUrl) {
                            Image.getSize(
                                photo.previewUrl,
                                (width, height) => setRatio(width / height),
                                () => setRatio(1)
                            );
                        }
                    }, [photo.previewUrl]);

                    return (
                        <TouchableOpacity
                            onPress={() => console.log("Tapped:", photo.id)}
                            activeOpacity={0.8}
                            style={tw`m-1.5 rounded-2xl overflow-hidden`}
                        >
                            <Image
                                source={{ uri: photo.previewUrl }}
                                style={[tw`w-full rounded-2xl`, { aspectRatio: ratio }]}
                                resizeMode="cover"
                            />
                        </TouchableOpacity>
                    );
                }}
            />
        </SafeAreaView>
    );
}