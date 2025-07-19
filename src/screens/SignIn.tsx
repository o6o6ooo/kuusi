import { NativeStackScreenProps } from "@react-navigation/native-stack";
import React from "react";
import { Text, TouchableOpacity, View } from "react-native";
import tw from "twrnc";
import { RootStackParamList } from "../navigation/RootNavigator";

type Props = NativeStackScreenProps<RootStackParamList, "SignIn">;

export default function SignInScreen({ navigation }: Props) {
    return (
        <View style={tw`flex-1 items-center justify-center bg-white`}>
            <Text style={tw`text-2xl font-bold mb-5`}>Sign In</Text>
            <TouchableOpacity style={tw`w-60 px-5 py-3 bg-black rounded-lg mb-3`}>
                <Text style={tw`text-white text-center`}>Sign in with Apple</Text>
            </TouchableOpacity>
            <TouchableOpacity style={tw`w-60 px-5 py-3 bg-red-500 rounded-lg`}>
                <Text style={tw`text-white text-center`}>Sign in with Google</Text>
            </TouchableOpacity>
            <TouchableOpacity
                style={tw`mt-8 px-5 py-3 bg-blue-500 rounded-lg`}
                onPress={() => navigation.replace("Home")}
            >
                <Text style={tw`text-white text-center`}>Go to Home</Text>
            </TouchableOpacity>
        </View>
    );
}