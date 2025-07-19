import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import Home from '../screens/HomeScreen';
import Post from '../screens/PostScreen';
import User from '../screens/UserScreen';

const Tab = createBottomTabNavigator();

export default function TabNavigator() {
    return (
        <Tab.Navigator screenOptions={{ headerShown: false }}>
            <Tab.Screen name="Home" component={Home} />
            <Tab.Screen name="Post" component={Post} />
            <Tab.Screen name="User" component={User} />
        </Tab.Navigator>
    );
}