import { getAuth } from "@react-native-firebase/auth";
import firestore, { Timestamp } from "@react-native-firebase/firestore";
import { format } from "date-fns";
import { Calendar, CalendarDots, Check } from "phosphor-react-native";
import React, { useEffect, useState } from "react";
import { Text, TouchableOpacity, useColorScheme, View } from "react-native";
import tw from "twrnc";
import { DarkTheme, LightTheme } from "../../constants/theme";

export default function Subscription() {
    const [user, setUser] = useState<{ premium: boolean; plan?: string; nextBillingDate?: Timestamp }>({
        premium: false,
    });
    const colorScheme = useColorScheme();
    const theme = colorScheme === "dark" ? DarkTheme : LightTheme;

    useEffect(() => {
        const fetchUser = async () => {
            const uid = getAuth().currentUser?.uid;
            if (!uid) return;

            const doc = await firestore().collection("users").doc(uid).get();
            if (doc.exists()) {
                const data = doc.data();
                setUser({
                    premium: data?.premium === true,
                    plan: data?.plan ?? "",
                    nextBillingDate: data?.nextBillingDate || undefined,
                });
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
            selected: !user.premium,
        },
        {
            name: "Premium",
            features: [
                "50GB storage",
                "Filter photo by every year",
                "Create up to 10 groups",
                "Invite up to 20 users",
            ],
            selected: user.premium,
        },
    ];

    return (
        <View>
            {plans.map((plan) => (
                <View
                    key={plan.name}
                    style={[
                        tw`mb-2 p-2 rounded-xl flex-row`,
                        { backgroundColor: theme.card },
                    ]}
                >
                    <View style={tw`w-1/5 justify-center items-center pt-1`}>
                        {plan.selected && (
                            <Check size={20} color={theme.text} weight="bold" />
                        )}
                    </View>

                    <View style={tw`w-4/5`}>
                        <Text
                            style={[tw`font-semibold mb-1`, { color: theme.text }]}
                        >
                            {plan.name}
                        </Text>
                        {plan.features.map((feature, idx) => (
                            <Text key={idx} style={[tw`text-xs leading-4`, { color: theme.text }]}>
                                • {feature}
                            </Text>
                        ))}

                        {plan.name === "Premium" && (
                            user.premium ? (
                                <View style={tw`mt-3`}>
                                    <Text style={[tw`text-xs`, { color: theme.text }]}>Your plan:{' '}
                                        <Text style={[tw`text-xs font-medium`, { color: theme.primary }]}>{user.plan}</Text>
                                    </Text>
                                    <Text style={[tw`text-xs`, { color: theme.text }]}>Next billing date:{' '}
                                        <Text style={[tw`text-xs font-medium`, { color: theme.primary }]}>{user.nextBillingDate ? format(user.nextBillingDate.toDate(), "dd MMM yyyy") : "--"}</Text>
                                    </Text>
                                    <Text style={[tw`text-xs font-medium underline`, { color: theme.primary }]}>Cancel subscription</Text>
                                </View>
                            ) : (
                                <View style={tw`flex-row mt-3`}>
                                    <TouchableOpacity
                                        style={[
                                            tw`flex-1 flex-row items-center mr-2 py-2 rounded-lg`,
                                            { backgroundColor: theme.background },
                                        ]}
                                    >
                                        <View style={tw`w-8 items-center`}>
                                            <CalendarDots size={18} color={theme.text} />
                                        </View>
                                        <View>
                                            <Text style={[tw`text-xs`, { color: theme.text }]}>Pay monthly</Text>
                                            <Text style={[tw`text-xs`, { color: theme.text }]}>£5.00 / month</Text>
                                        </View>
                                    </TouchableOpacity>

                                    <TouchableOpacity
                                        style={[
                                            tw`flex-1 flex-row items-center py-2 rounded-lg`,
                                            { backgroundColor: theme.background },
                                        ]}
                                    >
                                        <View style={tw`w-8 items-center`}>
                                            <Calendar size={18} color={theme.text} />
                                        </View>
                                        <View>
                                            <Text style={[tw`text-xs`, { color: theme.text }]}>Pay annually</Text>
                                            <Text style={[tw`text-xs`, { color: theme.text }]}>£50.00 / year</Text>
                                        </View>
                                    </TouchableOpacity>
                                </View>
                            )
                        )}
                    </View>
                </View>
            ))}
        </View>
    );
}