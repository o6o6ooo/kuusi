import { GoogleSignin } from '@react-native-google-signin/google-signin';
import { DefaultTheme, NavigationContainer, DarkTheme as NavigationDarkTheme } from '@react-navigation/native';
import { useColorScheme } from 'react-native';
import { DarkTheme, LightTheme } from './src/constants/theme'; // テーマ定義をインポート
import RootNavigator from './src/navigation/RootNavigator'; // StackNavigatorをまとめたコンポーネント

export default function App() {
    const scheme = useColorScheme();
    const theme = scheme === 'dark'
        ? { ...NavigationDarkTheme, colors: { ...NavigationDarkTheme.colors, ...DarkTheme } }
        : { ...DefaultTheme, colors: { ...DefaultTheme.colors, ...LightTheme } };

    GoogleSignin.configure({
        webClientId: '898290307420-93fv03fvvvh5kd5lfmqk4a0at34dek89.apps.googleusercontent.com',
    })

    return (
        <NavigationContainer theme={theme}>
            <RootNavigator />
        </NavigationContainer>
    );
}