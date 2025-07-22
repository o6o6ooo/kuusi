import { DefaultTheme, NavigationContainer, DarkTheme as NavigationDarkTheme } from '@react-navigation/native';
import { useColorScheme } from 'react-native';
import { DarkTheme, LightTheme } from './src/constants/theme';
import RootNavigator from './src/navigation/RootNavigator';

export default function App() {
    const scheme = useColorScheme();
    const theme = scheme === 'dark'
        ? { ...NavigationDarkTheme, colors: { ...NavigationDarkTheme.colors, ...DarkTheme } }
        : { ...DefaultTheme, colors: { ...DefaultTheme.colors, ...LightTheme } };

    return (
        <NavigationContainer theme={theme}>
            <RootNavigator />
        </NavigationContainer>
    );
}