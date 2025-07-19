import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import Home from '../screens/Home';
import Post from '../screens/Post';
import User from '../screens/User';

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