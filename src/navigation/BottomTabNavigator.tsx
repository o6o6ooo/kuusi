import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { Calendar, Camera, HouseLine, SlidersHorizontal } from "phosphor-react-native";
import React, { useEffect, useRef } from "react";
import { Animated, useColorScheme } from "react-native";
import { DarkTheme, LightTheme } from "../constants/theme";
import Browse from "../screens/Browse";
import Home from "../screens/Home";
import Post from "../screens/Post";
import User from "../screens/User";

const Tab = createBottomTabNavigator();

function AnimatedIcon({ focused, color, size, Icon }: { focused: boolean; color: string; size: number; Icon: any }) {
    const scale = useRef(new Animated.Value(1)).current;

    useEffect(() => {
        Animated.spring(scale, {
            toValue: focused ? 1.2 : 1,
            friction: 4,
            useNativeDriver: true,
        }).start();
    }, [focused]);

    return (
        <Animated.View style={{ transform: [{ scale }] }}>
            <Icon size={size} color={color} weight="bold" />
        </Animated.View>
    );
}

export default function BottomTabNavigator() {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    return (
        <Tab.Navigator
            screenOptions={({ route }) => ({
                headerShown: false,
                tabBarActiveTintColor: theme.primary,
                tabBarInactiveTintColor: theme.text,
                tabBarShowLabel: false,
                tabBarStyle: {
                    backgroundColor: theme.background,
                    borderTopWidth: 0,
                },
                tabBarIconStyle: {
                    marginTop: -4,
                },
                tabBarIcon: ({ color, size, focused }) => {
                    const icons: Record<string, any> = {
                        Home: HouseLine,
                        Browse: Calendar,
                        Post: Camera,
                        User: SlidersHorizontal,
                    };
                    const Icon = icons[route.name];
                    return <AnimatedIcon focused={focused} color={color} size={size} Icon={Icon} />;
                },
            })}
        >
            <Tab.Screen name="Home" component={Home} />
            <Tab.Screen name="Browse" component={Browse} />
            <Tab.Screen name="Post" component={Post} />
            <Tab.Screen name="User" component={User} />
        </Tab.Navigator>
    );
}