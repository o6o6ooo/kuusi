import { getApps, initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
    apiKey: "AIzaSyAcTyKsmLxrcc-YkWdLf_ChElevPlhJ0l0",
    authDomain: "kuusi-8e573.firebaseapp.com",
    projectId: "kuusi-8e573",
    storageBucket: "kuusi-8e573.appspot.com",
    messagingSenderId: "898290307420",
    appId: "1:898290307420:android:e2f7519aadda9bf530f199",
};

// すでに初期化済みなら再初期化しないように
const app = !getApps().length ? initializeApp(firebaseConfig) : getApps()[0];

// Firebaseサービスをエクスポート
const auth = getAuth(app);
const db = getFirestore(app);

export { app, auth, db };
