import { GoogleAuthProvider, getAuth, signInWithCredential } from '@react-native-firebase/auth';
import { doc, getDoc, getFirestore, serverTimestamp, setDoc } from '@react-native-firebase/firestore';
import { GoogleSignin } from '@react-native-google-signin/google-signin';
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { AppleLogo, GoogleLogo } from "phosphor-react-native";
import React from "react";
import { Text, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import { RootStackParamList } from "../navigation/RootNavigator";

type Props = NativeStackScreenProps<RootStackParamList, "SignIn">;

export default function SignIn({ navigation }: Props) {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    async function signInWithGoogle() {
        try {
            await GoogleSignin.hasPlayServices({ showPlayServicesUpdateDialog: true });
            const signInResult = await GoogleSignin.signIn();
            const idToken = signInResult.data?.idToken;
            if (!idToken) {
                throw new Error('No ID token found');
            }
            const googleCredential = GoogleAuthProvider.credential(idToken);
            await signInWithCredential(getAuth(), googleCredential);

            // save user info to Firestore
            async function saveUserToFirestore() {
                const user = getAuth().currentUser;
                if (!user) return;
                const db = getFirestore();
                const userRef = doc(db, 'users', user.uid);
                const docSnap = await getDoc(userRef);

                if (!docSnap.exists()) {
                    try {
                        await setDoc(userRef, {
                            name: user.displayName,
                            email: user.email,
                            icon: '🌸',
                            bgColour: '#A5C3DE',
                            createdAt: serverTimestamp(),
                        });
                        console.log('✅ User saved to Firestore');
                    } catch (error) {
                        console.error('❌ Firestore save error:', error);
                    }
                } else {
                    console.log('ℹ️ User already exists in Firestore');
                }
            }
            await saveUserToFirestore();
            navigation.replace("MainTabs");

        } catch (error) {
            console.error('Google Sign-In error:', error);
        }
    }

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
                onPress={signInWithGoogle}
                style={[
                    tw`w-60 flex-row items-center justify-center px-5 py-3 rounded-lg`,
                    { backgroundColor: theme.card },
                ]}
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