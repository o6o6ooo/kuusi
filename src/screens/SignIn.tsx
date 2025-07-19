import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { makeRedirectUri } from "expo-auth-session";
import * as Google from "expo-auth-session/providers/google";
import * as WebBrowser from "expo-web-browser";
import { GoogleAuthProvider, signInWithCredential } from "firebase/auth";
import { AppleLogo, GoogleLogo } from "phosphor-react-native";
import React, { useEffect } from "react";
import { Text, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { GOOGLE_WEB_CLIENT_ID } from "../config/authConfig";
import { DarkTheme, LightTheme } from "../constants/theme";
import { auth } from "../firebase";
import { RootStackParamList } from "../navigation/RootNavigator";

type Props = NativeStackScreenProps<RootStackParamList, "SignIn">;
WebBrowser.maybeCompleteAuthSession();

export default function SignInScreen({ navigation }: Props) {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;
    const [request, response, promptAsync] = Google.useIdTokenAuthRequest({
        clientId: GOOGLE_WEB_CLIENT_ID,
        redirectUri: makeRedirectUri({
            // @ts-ignore
            useProxy: true, // Use proxy for development
        }),
    });

    useEffect(() => {
        if (response?.type === "success") {
            const { id_token } = response.params;
            const credential = GoogleAuthProvider.credential(id_token);
            signInWithCredential(auth, credential)
                .then(userCredential => {
                    console.log("Firebaseログイン成功:", userCredential.user);
                })
                .catch(err => {
                    console.error("Firebaseログイン失敗:", err);
                });
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
                onPress={() => promptAsync()}
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