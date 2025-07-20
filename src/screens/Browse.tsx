import React from "react";
import { Text, View } from "react-native";
import tw from "twrnc";

export default function Browse() {
    return (
        <View style={tw`flex-1 items-center justify-center bg-white`}>
            <Text style={tw`text-2xl font-bold`}>Browse Screen</Text>
        </View>
    );
}