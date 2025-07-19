import React from "react";
import { Text, View } from "react-native";
import tw from "twrnc";

export default function Home() {
    return (
        <View style={tw`flex-1 items-center justify-center bg-white`}>
            <Text style={tw`text-2xl font-bold`}>Home Screen</Text>
        </View>
    );
}