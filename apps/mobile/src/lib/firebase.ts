import { getApps, initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, initializeAuth, type Auth } from 'firebase/auth';
import { initializeFirestore, persistentLocalCache, persistentMultipleTabManager, type Firestore } from 'firebase/firestore';
import { getStorage, type FirebaseStorage } from 'firebase/storage';

const firebaseConfig = {
    apiKey: 'AIzaSyAcTyKsmLxrcc-YkWdLf_ChElevPlhJ0l0',
    authDomain: 'kuusi-8e573.firebaseapp.com',
    projectId: 'kuusi-8e573',
    storageBucket: 'kuusi-8e573.firebasestorage.app',
    messagingSenderId: '898290307420',
    appId: '1:898290307420:android:e2f7519aadda9bf530f199',
};

export const app: FirebaseApp =
    getApps().length > 0 ? getApps()[0] : initializeApp(firebaseConfig);

export const auth: Auth = (() => {
    try {
        return initializeAuth(app);
    } catch {
        // すでに初期化済みなら getAuth を再利用
        return getAuth(app);
    }
})();

export const db: Firestore = initializeFirestore(app, {
    localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }),
});

export const storage: FirebaseStorage = getStorage(
    app,
    'gs://kuusi-8e573.firebasestorage.app'
);