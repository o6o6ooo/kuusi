import { faApple, faGoogle } from '@fortawesome/free-brands-svg-icons';
import { FontAwesomeIcon } from '@fortawesome/react-native-fontawesome';
import { GoogleSignin } from '@react-native-google-signin/google-signin';
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { GoogleAuthProvider, signInWithCredential } from 'firebase/auth';
import { doc, getDoc, serverTimestamp, setDoc } from 'firebase/firestore';
import React from "react";
import { Text, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import { auth, db } from '../lib/firebase';
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
            if (!idToken) throw new Error('No ID token found');

            const googleCredential = GoogleAuthProvider.credential(idToken);
            await signInWithCredential(auth, googleCredential);

            const user = auth.currentUser;
            if (!user) return;

            const userRef = doc(db, 'users', user.uid);
            const docSnap = await getDoc(userRef);

            if (!docSnap.exists()) {
                await setDoc(userRef, {
                    name: user.displayName,
                    email: user.email,
                    icon: '🌸',
                    bgColour: '#A5C3DE',
                    premium: false,
                    upload_count: 0,
                    upload_total_mb: 0,
                    createdAt: serverTimestamp(),
                });
                console.log('✅ User saved to Firestore');
            } else {
                console.log('ℹ️ User already exists in Firestore');
            }

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
                <FontAwesomeIcon icon={faApple} size={20} color={theme.text} style={tw`mr-2`} />
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
                <FontAwesomeIcon icon={faGoogle} size={16} color="#DB4437" style={tw`mr-2`} />
                <Text style={tw`text-[#DB4437] text-center text-base`}>Continue with Google</Text>
            </TouchableOpacity>

            <Text style={[tw`text-xs mt-4 mb-8`, { color: theme.grayText }]}>Having trouble to sign in?{' '}
                <Text style={[tw`text-xs`, { color: theme.primary }]}>Contact to get help</Text>
            </Text>

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