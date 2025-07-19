import React from "react";
import { Text, TouchableOpacity, View } from "react-native";
import tw from "twrnc";

export default function Onboarding({ navigation }: any) {
    return (
        <View style={tw`flex-1 items-center justify-center bg-white`}>
            <Text style={tw`text-2xl font-bold`}>Welcome to Family App</Text>
            <TouchableOpacity
                style={tw`mt-5 px-5 py-3 bg-blue-500 rounded-lg`}
                onPress={() => navigation.replace("SignIn")}
            >
                <Text style={tw`text-white text-base`}>Get Started</Text>
            </TouchableOpacity>
        </View>
    );
}