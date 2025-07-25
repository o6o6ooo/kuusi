import { getAuth, signOut } from '@react-native-firebase/auth';
import { useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { Text, TouchableOpacity, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";
import type { RootStackParamList } from "../navigation/RootNavigator";

export default function User() {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;
    const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();

    async function handleSignOut() {
        try {
            await signOut(getAuth());
            console.log('✅ Signed out');
            navigation.replace("SignIn"); // サインイン画面に戻る
        } catch (error) {
            console.error('❌ Sign-out error:', error);
        }
    }

    return (
        <View style={[tw`flex-1 items-center justify-center`, { backgroundColor: theme.background }]}>
            <Text style={[tw`text-2xl font-bold mb-6`, { color: theme.text }]}>User</Text>

            <TouchableOpacity
                onPress={handleSignOut}
                style={[tw`px-5 py-3 rounded-lg`, { backgroundColor: theme.primary }]}
            >
                <Text style={tw`text-white text-center`}>Sign Out</Text>
            </TouchableOpacity>
        </View>
    );
}