import MasonryList from "@react-native-seoul/masonry-list";
import { collection, getDocs, orderBy, query } from "firebase/firestore";
import { getDownloadURL, ref } from "firebase/storage";
import React, { useEffect, useState } from "react";
import { ActivityIndicator, Image, Text, TouchableOpacity, useColorScheme, View } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import { db, storage } from "../lib/firebase";

export default function Home() {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    const [photos, setPhotos] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchPhotos = async () => {
            try {
                const q = query(collection(db, "photos"), orderBy("created_at", "desc"));
                const snapshot = await getDocs(q);

                const photoData = await Promise.all(
                    snapshot.docs.map(async (docSnap) => {
                        const data = docSnap.data();
                        let previewUrl: string | null = null;
                        try {
                            const previewRef = ref(storage, data.preview_path);
                            previewUrl = await getDownloadURL(previewRef);
                        } catch {
                            console.warn("Missing preview:", data.preview_path);
                        }
                        return { id: docSnap.id, ...data, previewUrl };
                    })
                );

                setPhotos(photoData.filter((p) => p.previewUrl));
            } catch (err) {
                console.error("Error fetching photos:", err);
            } finally {
                setLoading(false);
            }
        };
        fetchPhotos();
    }, []);

    if (loading) {
        return (
            <View style={[tw`flex-1 items-center justify-center`, { backgroundColor: theme.background }]}>
                <ActivityIndicator size="large" color={theme.text} />
                <Text style={[tw`mt-4`, { color: theme.text }]}>Loading photos...</Text>
            </View>
        );
    }

    return (
        <View style={[tw`flex-1`, { backgroundColor: theme.background }]}>
            {/* タイトル */}
            <View style={tw`pt-14 pb-3 px-4`}>
                <Text style={[tw`text-2xl font-bold`, { color: theme.text }]}>Home Feed</Text>
            </View>

            {/* Masonry layout */}
            <MasonryList
                data={photos}
                keyExtractor={(item) => item.id}
                numColumns={2}
                showsVerticalScrollIndicator={false}
                contentContainerStyle={tw`pb-20`}
                renderItem={({ item }) => (
                    <TouchableOpacity
                        onPress={() => console.log("Tapped:", item.id)}
                        activeOpacity={0.8}
                        style={tw`m-1 rounded-2xl overflow-hidden`}
                    >
                        <Image
                            source={{ uri: item.previewUrl }}
                            style={tw`w-full h-64 rounded-2xl`}
                            resizeMode="cover"
                        />
                    </TouchableOpacity>
                )}
            />
        </View>
    );
}