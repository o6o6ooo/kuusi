import { NativeStackScreenProps } from "@react-navigation/native-stack";
import * as Google from "expo-auth-session/providers/google";
import { GoogleAuthProvider, signInWithCredential } from "firebase/auth";
import { AppleLogo, GoogleLogo } from "phosphor-react-native";
import React, { useEffect } from "react";
import { Alert, Text, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import { auth } from "../lib/firebase";
import { RootStackParamList } from "../navigation/RootNavigator";
type Props = NativeStackScreenProps<RootStackParamList, "SignIn">;

export default function SignIn({ navigation }: Props) {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    // const redirectUri = "https://auth.expo.io/@o6o6ooo/kuusi";
    const redirectUri = "kuusi://redirect";
    console.log("redirectUri:", redirectUri);

    // Google Auth Request
    const [request, response, promptAsync] = Google.useAuthRequest({
        // clientId: "475913927226-e24j37k0q5dtefca49ei2fhhu5u18b23.apps.googleusercontent.com",
        iosClientId: "475913927226-vsnqope3j1pbjq6m6t9qeo4anouu20o5.apps.googleusercontent.com",
        redirectUri: redirectUri,
        scopes: ["profile", "email", "openid"],
    });

    useEffect(() => {
        console.log("Google Auth Request object:", request);
        console.log("Configured redirectUri:", request?.redirectUri);
    }, [request]);

    // sign in to Firebase with Google
    useEffect(() => {
        console.log("Google Auth Response:", JSON.stringify(response, null, 2));
        if (response?.type === "success") {
            const { authentication } = response;
            if (authentication?.idToken) {
                const credential = GoogleAuthProvider.credential(authentication.idToken);
                signInWithCredential(auth, credential)
                    .then(() => {
                        console.log("Firebaseログイン成功");
                        navigation.replace("MainTabs");
                    })
                    .catch((err) => {
                        console.error("Firebaseログイン失敗", err);
                        Alert.alert("Login Error", "Failed to login with Google");
                    });
            }
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
                onPress={() => Alert.alert("Apple Sign-In", "Apple login is not implemented yet")}
            >
                <AppleLogo size={20} color={theme.text} weight="bold" style={tw`mr-2`} />
                <Text style={[tw`text-center text-base`, { color: theme.text }]}>Continue with Apple</Text>
            </TouchableOpacity>

            {/* Google */}
            <TouchableOpacity
                style={[
                    tw`w-60 flex-row items-center justify-center px-5 py-3 rounded-lg`,
                    { backgroundColor: theme.card },
                ]}
                disabled={!request}
                onPress={() => promptAsync()}
            >
                <GoogleLogo size={20} color="#DB4437" weight="bold" style={tw`mr-2`} />
                <Text style={tw`text-[#DB4437] text-center text-base`}>Continue with Google</Text>
            </TouchableOpacity>

            {/* Home */}
            <TouchableOpacity
                style={[tw`mt-8 px-5 py-3 rounded-lg`, { backgroundColor: theme.primary }]}
                onPress={() => navigation.replace("MainTabs")}
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