import MasonryList from "@react-native-seoul/masonry-list";
import { collection, getDocs, orderBy, query } from "firebase/firestore";
import React, { useEffect, useState } from "react";
import { ActivityIndicator, Image, Text, TouchableOpacity, useColorScheme, useWindowDimensions, View } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import { db } from "../lib/firebase";

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
    const [loading, setLoading] = useState(true);

    const numColumns =
        screenWidth < 600
            ? 2 // iPhoneサイズ
            : screenWidth < 1000
                ? 3 // iPad（縦）
                : 4; // iPad Proや横向き

    useEffect(() => {
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
                numColumns={numColumns}
                showsVerticalScrollIndicator={false}
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
                            style={tw`m-1 rounded-2xl overflow-hidden`}
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
        </View>
    );
}