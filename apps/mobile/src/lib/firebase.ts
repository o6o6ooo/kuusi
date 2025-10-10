import ReactNativeAsyncStorage from '@react-native-async-storage/async-storage';
import { getApps, initializeApp } from 'firebase/app';
// @ts-ignore
import { getReactNativePersistence, initializeAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
    apiKey: "AIzaSyAcTyKsmLxrcc-YkWdLf_ChElevPlhJ0l0",
    authDomain: "kuusi-8e573.firebaseapp.com",
    projectId: "kuusi-8e573",
    storageBucket: "kuusi-8e573.firebasestorage.app",
    messagingSenderId: "898290307420",
    appId: "1:898290307420:android:e2f7519aadda9bf530f199",
};

const app = !getApps().length ? initializeApp(firebaseConfig) : getApps()[0];
const auth = initializeAuth(app, {
    persistence: getReactNativePersistence(ReactNativeAsyncStorage),
});
const db = getFirestore(app);
const storage = getStorage(app, "gs://kuusi-8e573.firebasestorage.app");

export { app, auth, db, storage };
