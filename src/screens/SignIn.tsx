import React from "react";
import { Text, TouchableOpacity, View } from "react-native";
import tw from "twrnc";

export default function SignIn({ navigation }: any) {
    return (
        <View style={tw`flex-1 items-center justify-center bg-white`}>
            <Text style={tw`text-2xl font-bold`}>Sign In</Text>
            <TouchableOpacity
                style={tw`mt-5 px-5 py-3 bg-blue-500 rounded-lg`}
                onPress={() => navigation.replace("Home")}
            >
                <Text style={tw`text-white text-base`}>Go to Home</Text>
            </TouchableOpacity>
        </View>
    );
}