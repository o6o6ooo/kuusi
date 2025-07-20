import { Text, View, useColorScheme } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../constants/theme";

export default function Browse() {
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    return (
        <View style={[tw`flex-1 items-center justify-center`, { backgroundColor: theme.background }]}>
            <Text style={[tw`text-2xl font-bold`, { color: theme.text }]}>Browse Screen</Text>
        </View>
    );
}