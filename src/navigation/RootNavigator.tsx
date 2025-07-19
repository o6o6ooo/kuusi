import { createNativeStackNavigator } from '@react-navigation/native-stack';
import Onboarding from '../screens/Onboarding';
import SignIn from '../screens/SignIn';
import TabNavigator from './TabNavigator';

const Stack = createNativeStackNavigator();

export default function RootNavigator() {
    return (
        <Stack.Navigator screenOptions={{ headerShown: false }}>
            <Stack.Screen name="Onboarding" component={Onboarding} />
            <Stack.Screen name="SignIn" component={SignIn} />
            <Stack.Screen name="Main" component={TabNavigator} />
        </Stack.Navigator>
    );
}