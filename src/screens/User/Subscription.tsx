import { MaterialIcons } from "@expo/vector-icons";
import { getAuth } from "@react-native-firebase/auth";
import firestore from "@react-native-firebase/firestore";
import React, { useEffect, useState } from "react";
import { Text, useColorScheme, View } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";

export default function Subscription() {
    const [isPremium, setIsPremium] = useState(false);
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    useEffect(() => {
        const fetchUser = async () => {
            const uid = getAuth().currentUser?.uid;
            if (!uid) return;

            const doc = await firestore().collection("users").doc(uid).get();
            if (doc.exists()) {
                setIsPremium(doc.data()?.premium === true);
            }
        };

        fetchUser();
    }, []);

    const plans = [
        {
            name: "Free",
            features: [
                "5GB storage",
                "Filter photo by past 2 years",
                "Create up to 3 groups",
                "Invite up to 5 users",
            ],
            selected: !isPremium,
        },
        {
            name: "Premium",
            features: [
                "50GB storage",
                "Filter photo by every year",
                "Create up to 10 groups",
                "Invite up to 20 users",
            ],
            selected: isPremium,
        },
    ];

    return (
        <View>
            {plans.map((plan) => (
                <View
                    key={plan.name}
                    style={[
                        tw`mb-4 p-4 rounded-xl`,
                        { backgroundColor: theme.card },
                    ]}
                >
                    <View style={tw`flex-row items-center`}>
                        {plan.selected && (
                            <MaterialIcons
                                name="check-circle"
                                size={20}
                                color={theme.primary}
                                style={tw`mr-2`}
                            />
                        )}
                        <Text style={[tw`text-lg font-semibold`, { color: theme.text }]}>
                            {plan.name}
                        </Text>
                    </View>

                    {plan.features.map((feature, idx) => (
                        <Text
                            key={idx}
                            style={[tw`ml-6 text-xs`, { color: theme.text }]}
                        >
                            • {feature}
                        </Text>
                    ))}
                </View>
            ))}
        </View>
    );
}