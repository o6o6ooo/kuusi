import MasonryList from "@react-native-seoul/masonry-list";
import { collection, doc, getDoc, getDocFromCache, getDocs, getDocsFromCache, orderBy, query, where } from "firebase/firestore";
import React, { useCallback, useEffect, useMemo, useState } from "react";
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
    const [refreshing, setRefreshing] = useState(false);

    // columns: iPhone: 2, iPad: 3, large: 4
    const numColumns = screenWidth < 600 ? 2 : screenWidth < 1000 ? 3 : 4;

    // Firestore fetch function キャッシュが空なら自動でサーバーから取得（フォールバック）
    const fetchAllData = useCallback(async () => {
        if (!auth.currentUser) return;
        setLoading(true);

        try {
            console.log("🔄 Fetching all data...");

            // --- users
            let userDoc;
            try {
                userDoc = await getDocFromCache(doc(db, "users", auth.currentUser.uid));
                if (userDoc.exists()) {
                    console.log("✅ Loaded user from cache");
                } else {
                    console.log("⚠️ Cache empty → fetching user from server");
                    userDoc = await getDoc(doc(db, "users", auth.currentUser.uid));
                }
            } catch {
                console.log("⚠️ Cache miss → fetching user from server");
                userDoc = await getDoc(doc(db, "users", auth.currentUser.uid));
            }

            const groupIds = userDoc?.exists() ? userDoc.data().groups || [] : [];
            console.log("User groups:", groupIds);

            // --- groups
            const groupDocs = await Promise.all(
                groupIds.map(async (gid: string) => {
                    const ref = doc(db, "groups", gid);
                    try {
                        const gDoc = await getDocFromCache(ref);
                        if (gDoc.exists()) {
                            console.log(`✅ Group ${gid} from cache`);
                            return { id: gDoc.id, ...gDoc.data() };
                        }
                        console.log(`⚠️ Group ${gid} cache empty → fetching from server`);
                        const freshDoc = await getDoc(ref);
                        return freshDoc.exists() ? { id: freshDoc.id, ...freshDoc.data() } : null;
                    } catch {
                        console.log(`⚠️ Cache miss → fetching group ${gid} from server`);
                        const gDoc = await getDoc(ref);
                        return gDoc.exists() ? { id: gDoc.id, ...gDoc.data() } : null;
                    }
                })
            );
            setGroups(groupDocs.filter(Boolean));

            // --- hashtags
            const hashtagQuery = query(
                collection(db, "hashtags"),
                where("user_id", "==", auth.currentUser.uid),
                where("show_in_feed", "==", true)
            );

            let hashtagSnap;
            try {
                hashtagSnap = await getDocsFromCache(hashtagQuery);
                if (!hashtagSnap.empty) {
                    console.log("✅ Loaded hashtags from cache");
                } else {
                    console.log("⚠️ Hashtag cache empty → fetching from server");
                    hashtagSnap = await getDocs(hashtagQuery);
                }
            } catch {
                console.log("⚠️ Cache miss → fetching hashtags from server");
                hashtagSnap = await getDocs(hashtagQuery);
            }
            setHashtags(hashtagSnap.docs.map((d) => d.data()));

            // --- photos
            const photoQuery = query(collection(db, "photos"), orderBy("created_at", "desc"));

            let snapshot;
            try {
                snapshot = await getDocsFromCache(photoQuery);
                if (!snapshot.empty) {
                    console.log("✅ Loaded photos from cache");
                } else {
                    console.log("⚠️ Photo cache empty → fetching from server");
                    snapshot = await getDocs(photoQuery);
                }
            } catch {
                console.log("⚠️ Cache miss → fetching photos from server");
                snapshot = await getDocs(photoQuery);
            }

            const photoData = snapshot.docs.map((docSnap) => {
                const data = docSnap.data();
                return {
                    id: docSnap.id,
                    ...data,
                    previewUrl: data.thumbnail_url || data.photo_url || null,
                };
            }) as Photo[];

            setPhotos(photoData.filter((p) => p.previewUrl));

            console.log(`📸 Loaded ${photoData.length} photos`);

        } catch (err) {
            console.error("❌ Error fetching data:", err);
        } finally {
            setLoading(false);
        }
    }, []);

    // 初回マウント時のみロード（Fast Refresh対策）
    useEffect(() => {
        fetchAllData();
    }, [fetchAllData]);

    // Pull-to-refresh handler
    const onRefresh = useCallback(async () => {
        setRefreshing(true);
        await fetchAllData();
        setRefreshing(false);
    }, [fetchAllData]);

    // Filtered photos
    const filteredPhotos = useMemo(() => {
        return photos.filter((p) => {
            if (selectedTab === "all") return true;
            if (selectedTab.startsWith("group-"))
                return p.group_id === selectedTab.replace("group-", "");
            if (selectedTab.startsWith("hashtag-"))
                return p.hashtags?.includes(selectedTab.replace("hashtag-", ""));
            return true;
        });
    }, [photos, selectedTab]);

    // Loading screen
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
            {/* Tab bar */}
            <View style={tw`py-2`}>
                <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                    {[
                        { key: "all", label: "All" },
                        ...groups.map((g) => ({ key: `group-${g.id}`, label: g.name })),
                        ...hashtags.map((h) => ({ key: `hashtag-${h.hashtag}`, label: `#${h.hashtag}` })),
                    ].map((tab) => {
                        const isSelected = tab.key === selectedTab;
                        return (
                            <TouchableOpacity
                                key={tab.key}
                                onPress={() => setSelectedTab(tab.key)}
                                style={[
                                    tw`px-3 py-1 mr-2 rounded-full`,
                                    {
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
                data={filteredPhotos}
                key={selectedTab}
                keyExtractor={(item) => item.id}
                numColumns={numColumns}
                showsVerticalScrollIndicator={false}
                style={{ marginHorizontal: -6 }}
                contentContainerStyle={tw`pb-20`}
                refreshing={refreshing}
                onRefresh={onRefresh}
                renderItem={({ item }: { item: unknown }) => {
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