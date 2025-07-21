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

    // useAuthRequestを使用（codeを取得）
    const [request, response, promptAsync] = Google.useAuthRequest({
        expoClientId: GOOGLE_WEB_CLIENT_ID,
        webClientId: GOOGLE_WEB_CLIENT_ID,
        redirectUri,
        scopes: ["openid", "profile", "email"],
    });

    useEffect(() => {
        if (response) {
            console.log("=== RESPONSE RECEIVED ===");
            console.log("Response type:", response.type);
            console.log("Full response:", JSON.stringify(response, null, 2));

            if (response.type === "success") {
                console.log("✅ SUCCESS");
                console.log("Authorization code:", response.params.code);

                // Authorization codeを使ってGoogle APIからトークンを取得
                (async () => { await exchangeCodeForTokens(response.params.code); })();

            } else if (response.type === "error") {
                console.error("❌ ERROR:", response.error);
                console.error("❌ Error description:", response.params?.error_description);
                console.error("❌ Full error params:", response.params);
            } else if (response.type === "dismiss") {
                console.log("⚠️ USER DISMISSED");
            }
        }
    }, [response]);

    const exchangeCodeForTokens = async (code: string) => {
        try {
            console.log("Exchanging authorization code for tokens...");

            const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: new URLSearchParams({
                    client_id: GOOGLE_WEB_CLIENT_ID,
                    code: code,
                    grant_type: 'authorization_code',
                    redirect_uri: redirectUri,
                }).toString(),
            });

            if (!tokenResponse.ok) {
                throw new Error(`Token exchange failed: ${tokenResponse.status}`);
            }

            const tokens = await tokenResponse.json();
            console.log("Tokens received:", tokens);

            if (tokens.id_token) {
                // Firebase Authで使用
                await signInWithGoogle(tokens.id_token);
            }

        } catch (error) {
            console.error("Token exchange error:", error);
        }
    };

    const signInWithGoogle = async (idToken: string) => {
        try {
            console.log("Signing in with Firebase...");
            // Firebase認証の実装
            // const credential = GoogleAuthProvider.credential(idToken);
            // const result = await signInWithCredential(auth, credential);
            console.log("Firebase auth would happen here with ID token");
        } catch (error) {
            console.error("Firebase sign in error:", error);
        }
    };

    const handleGoogleSignIn = async () => {
        console.log("Starting Google Sign In...");
        console.log("Request object:", request);

        if (!request) {
            console.error("Request is not ready yet");
            return;
        }

        try {
            console.log("Executing promptAsync...");
            const result = await promptAsync();
            console.log("Prompt result:", result);
        } catch (error) {
            console.error("Error during promptAsync:", error);
        }
    };

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
                onPress={handleGoogleSignIn}
                disabled={!request}
                style={[
                    tw`w-60 flex-row items-center justify-center px-5 py-3 rounded-lg`,
                    { backgroundColor: theme.card, opacity: !request ? 0.5 : 1 }
                ]}
            >
                <GoogleLogo size={20} color="#DB4437" weight="bold" style={tw`mr-2`} />
                <Text style={tw`text-[#DB4437] text-center text-base`}>
                    {!request ? 'Loading...' : 'Continue with Google'}
                </Text>
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