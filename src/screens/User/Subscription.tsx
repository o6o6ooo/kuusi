import { getAuth } from "@react-native-firebase/auth";
import firestore from "@react-native-firebase/firestore";
import { Check } from "phosphor-react-native";
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
                <View key={plan.name} style={[tw`mb-2 p-2 rounded-xl flex-row`, { backgroundColor: theme.card }]}>
                    <View style={tw`w-1/5 justify-center items-center pt-1`}>
                        {plan.selected && (
                            <Check size={20} color={theme.text} weight="bold" />
                        )}
                    </View>

                    <View style={tw`w-4/5`}>
                        <Text style={[tw`font-semibold mb-1`, { color: theme.text }]}>
                            {plan.name}
                        </Text>
                        {plan.features.map((feature, idx) => (
                            <Text key={idx} style={[tw`text-xs`, { color: theme.text }]}>
                                • {feature}
                            </Text>
                        ))}
                    </View>
                </View>
            ))}
        </View>
    );
}