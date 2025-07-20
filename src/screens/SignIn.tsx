import { NativeStackScreenProps } from "@react-navigation/native-stack";
import * as AuthSession from "expo-auth-session";
import * as Google from "expo-auth-session/providers/google";
import { AppleLogo, GoogleLogo } from "phosphor-react-native";
import React, { useEffect } from "react";
import { Text, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { GOOGLE_WEB_CLIENT_ID } from "../config/authConfig";
import { DarkTheme, LightTheme } from "../constants/theme";
import { RootStackParamList } from "../navigation/RootNavigator";

type Props = NativeStackScreenProps<RootStackParamList, "SignIn">;

export default function SignInScreen({ navigation }: Props) {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;
    const redirectUri = __DEV__
        ? "https://auth.expo.io/@o6o6ooo/kuusi"
        : AuthSession.makeRedirectUri({ scheme: "kuusi" });
    console.log("Redirect URI used in request:", redirectUri);

    const [request, response, promptAsync] = Google.useIdTokenAuthRequest({
        clientId: GOOGLE_WEB_CLIENT_ID,
        redirectUri,
        scopes: ["openid", "profile", "email"]
    });

    useEffect(() => {
        if (response?.type === "success") {
            console.log("Google Auth response:", response);
            const { id_token } = response.params;
            console.log("ID Token:", id_token);
        }
    }, [response]);

    return (
        <View style={[tw`flex-1 items-center justify-center`, { backgroundColor: theme.background }]}>
            <Text style={[tw`text-2xl font-bold mb-5`, { color: theme.text }]}>Sign In / Sign Up</Text>

            {/* Apple */}
            <TouchableOpacity
                style={[
                    tw`w-60 flex-row items-center justify-center px-5 py-3 rounded-lg mb-3`,
                    { backgroundColor: theme.card },
                ]}
            >
                <AppleLogo size={20} color={theme.text} weight="bold" style={tw`mr-2`} />
                <Text style={[tw`text-center text-base`, { color: theme.text }]}>Continue with Apple</Text>
            </TouchableOpacity>

            {/* Google */}
            <TouchableOpacity
                onPress={() => {
                    console.log("Executing promptAsync...");
                    promptAsync().then(r => console.log("Prompt result:", r));
                    console.log("AuthRequest:", request);
                }}
                style={[tw`w-60 flex-row items-center justify-center px-5 py-3 rounded-lg`, { backgroundColor: theme.card }]}
            >
                <GoogleLogo size={20} color="#DB4437" weight="bold" style={tw`mr-2`} />
                <Text style={tw`text-[#DB4437] text-center text-base`}>Continue with Google</Text>
            </TouchableOpacity>

            {/* Home */}
            <TouchableOpacity
                style={[tw`mt-8 px-5 py-3 rounded-lg`, { backgroundColor: theme.primary }]}
                onPress={() => navigation.replace("Home")}
            >
                <Text style={tw`text-white text-center`}>Go to Home</Text>
            </TouchableOpacity>

            {/* Terms */}
            <View style={tw`px-10`}>
                <Text style={[tw`mt-4 text-xs text-center`, { color: theme.grayText }]}>
                    By continuing you acknowledge that you have read and agree to our{' '}
                    <Text style={[tw`mt-4 text-xs text-center`, { color: theme.primary }]}>
                        Terms of Service
                    </Text>
                    {' '}and{' '}
                    <Text style={[tw`mt-4 text-xs text-center`, { color: theme.primary }]}>
                        Privacy Policy
                    </Text>
                </Text>
            </View>
        </View>
    );
}