import { createNativeStackNavigator } from "@react-navigation/native-stack";
import React from "react";
import BottomTabNavigator from "../navigation/BottomTabNavigator";
import Onboarding from "../screens/Onboarding";
import SignIn from "../screens/SignIn";

export type RootStackParamList = {
    Onboarding: undefined;
    SignIn: undefined;
    MainTabs: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootNavigator() {
    return (
        <Stack.Navigator initialRouteName="Onboarding" screenOptions={{ headerShown: false }}>
            <Stack.Screen name="Onboarding" component={Onboarding} />
            <Stack.Screen name="SignIn" component={SignIn} />
            <Stack.Screen name="MainTabs" component={BottomTabNavigator} />
        </Stack.Navigator>
    );
}