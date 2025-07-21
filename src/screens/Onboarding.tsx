import React, { useRef, useState } from 'react';
import { Dimensions, FlatList, Image, ScrollView, Text, TouchableOpacity, View, useColorScheme } from 'react-native';
import tw from 'twrnc';
import { DarkTheme, LightTheme } from '../constants/theme';
const { width } = Dimensions.get('window');

const logoIcon = require('../../assets/logo.png');
const Logo = () => (
    <View style={tw`justify-center items-center`}>
        <Image source={logoIcon} style={{ width: 120, height: 120, resizeMode: 'contain' }} />
    </View>
);

// Cards
const OnboardingCard = ({ theme }: { theme: any }) => {
    const cards = [0, 1, 2];

    return (
        <View style={tw`mb-8 justify-center items-center`}>
            <View style={[tw`relative`, { width: width * 0.2, height: width * 0.2 }]}>
                {cards.map((_, idx) => (
                    <View
                        key={idx}
                        style={[
                            tw`absolute w-full h-full rounded-xl`,
                            {
                                backgroundColor: theme.gray,
                                borderWidth: 1,
                                borderColor: theme.grayText,
                                top: idx * 4,   // 少し下にずらす
                                left: idx * 4,  // 少し右にずらす
                                shadowColor: '#000',
                                shadowOffset: { width: 0, height: 1 },
                                shadowOpacity: 0.2,
                                shadowRadius: 2,
                                elevation: 2, // Android用
                            },
                        ]}
                    >
                        {idx === 2 && (
                            <View
                                style={[
                                    tw`absolute w-8 h-8 rounded-full justify-center items-center`,
                                    { top: -12, left: -12, backgroundColor: theme.primary },
                                ]}
                            >
                                <Text style={tw`text-white text-xl font-semibold`}>3</Text>
                            </View>
                        )}
                    </View>
                ))}
            </View>
        </View>
    );
};

// Icon Row
const members = [
    { icon: '🥑', colour: '#C7E9F1' },
    { icon: '❄️', colour: '#FBE7A1' },
    { icon: '🌝', colour: '#D9E5FF' },
    { icon: '👩🏻‍💻', colour: '#FADADD' },
    { icon: '🌲', colour: '#A5C3DE' },
];
const IconRow = () => (
    <View style={tw`flex-row justify-center mb-8`}>
        {members.map((member, idx) => (
            <View
                key={idx}
                style={[
                    tw`w-10 h-10 rounded-full items-center justify-center border-2`,
                    {
                        backgroundColor: member.colour,
                        borderColor: '#fff',
                        marginLeft: idx === 0 ? 0 : -10, // 重なり部分
                        shadowColor: '#000',
                        shadowOffset: { width: 0, height: 1 },
                        shadowOpacity: 0.2,
                        shadowRadius: 2,
                        elevation: 2, // Android用
                    },
                ]}
            >
                <Text style={tw`text-xl text-white`}>{member.icon}</Text>
            </View>
        ))}
    </View>
);

// Tab Buttons
const TabButtons = ({ theme }: { theme: any }) => {
    const tabs = ['#family', '#holiday', '#2023', '#london'];
    return (
        <View style={tw`h-10 mb-8 px-12`}>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={tw`flex-row items-center`}>
                {tabs.map((tab, idx) => (
                    <View
                        key={idx}
                        style={[
                            tw`px-2 py-1 rounded-full`,
                            { backgroundColor: theme.primary, marginLeft: idx === 0 ? 0 : 8 },
                        ]}
                    >
                        <Text style={tw`text-white text-sm`}>{tab}</Text>
                    </View>
                ))}
            </ScrollView>
        </View>
    );
};

export default function Onboarding({ navigation }: any) {
    const [currentIndex, setCurrentIndex] = useState(0);
    const flatListRef = useRef<FlatList<any>>(null);

    const scheme = useColorScheme();
    const theme = scheme === 'dark' ? DarkTheme : LightTheme;

    const slides = [
        {
            id: '1',
            title: 'Welcome to Kuusi',
            description: 'Your photo sharing app.',
            component: <Logo />,
        },
        {
            id: '2',
            title: 'Create or join groups',
            description: 'Bring your beloved ones together.',
            component: <IconRow />,
        },
        {
            id: '3',
            title: 'Pick your favourites',
            description: 'Share them.',
            component: <OnboardingCard theme={theme} />,
        },
        {
            id: '4',
            title: 'Organise your photos',
            description: 'Put hashtags or years to keep everything in order.',
            component: <TabButtons theme={theme} />,
        },
    ];


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
                    <View style={[tw`flex-1 items-center justify-center px-10`, { width }]}>
                        {item.component}
                        <Text style={[tw`text-2xl font-bold`, { color: theme.text }]}>
                            {item.title}
                        </Text>
                        <Text style={[tw`mt-4 px-10 text-base text-center`, { color: theme.secondary }]}>
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
                    {currentIndex === slides.length - 1 ? 'Get Started' : 'Continue'}
                </Text>
            </TouchableOpacity>
        </View>
    );
}