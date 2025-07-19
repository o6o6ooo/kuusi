import React, { useRef, useState } from 'react';
import { Dimensions, FlatList, Text, TouchableOpacity, View, useColorScheme } from 'react-native';
import tw from 'twrnc';
import { DarkTheme, LightTheme } from '../constants/theme';

const { width } = Dimensions.get('window');

const slides = [
    { id: '1', title: 'Welcome to Kuusi', description: 'A cozy place to share memories with your beloved ones.' },
    { id: '2', title: 'Create or join groups', description: 'Bring your cherished ones together.' },
    { id: '3', title: 'Organise your photos', description: 'Put hashtags and years to keep everything in order.' },
];

export default function Onboarding({ navigation }: any) {
    const [currentIndex, setCurrentIndex] = useState(0);
    const flatListRef = useRef<FlatList<any>>(null);

    const scheme = useColorScheme();
    const theme = scheme === 'dark' ? DarkTheme : LightTheme;

    const handleNext = () => {
        if (currentIndex < slides.length - 1) {
            flatListRef.current?.scrollToIndex({ index: currentIndex + 1 });
        } else {
            navigation.replace('SignIn');
        }
    };

    const handleScroll = (e: any) => {
        const index = Math.round(e.nativeEvent.contentOffset.x / width);
        setCurrentIndex(index);
    };

    return (
        <View style={[tw`flex-1`, { backgroundColor: theme.background }]}>
            {/* tutorial */}
            <FlatList
                ref={flatListRef}
                data={slides}
                horizontal
                pagingEnabled
                showsHorizontalScrollIndicator={false}
                onScroll={handleScroll}
                renderItem={({ item }) => (
                    <View style={[tw`flex-1 items-center justify-center px-6`, { width }]}>
                        <Text style={[tw`text-2xl font-bold`, { color: theme.text }]}>
                            {item.title}
                        </Text>
                        <Text style={[tw`mt-4 text-base text-center`, { color: theme.secondary }]}>
                            {item.description}
                        </Text>
                    </View>
                )}
                keyExtractor={(item) => item.id}
            />

            {/* dots */}
            <View style={tw`flex-row justify-center mb-6`}>
                {slides.map((_, index) => (
                    <View
                        key={index}
                        style={[
                            tw`w-2 h-2 rounded-full mx-1`,
                            { backgroundColor: currentIndex === index ? theme.primary : theme.gray },
                        ]}
                    />
                ))}
            </View>

            {/* Next/Get Started*/}
            <TouchableOpacity
                style={[tw`mx-8 mb-8 p-4 rounded-xl`, { backgroundColor: theme.primary }]}
                onPress={handleNext}
            >
                <Text style={tw`text-center text-white text-lg font-semibold`}>
                    {currentIndex === slides.length - 1 ? 'Get Started' : 'Next'}
                </Text>
            </TouchableOpacity>
        </View>
    );
}