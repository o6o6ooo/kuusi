import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
    apiKey: "AIzaSyAcTyKsmLxrcc-YkWdLf_ChElevPlhJ0l0",
    authDomain: "kuusi-8e573.firebaseapp.com",
    projectId: "kuusi-8e573",
    storageBucket: "kuusi-8e573.appspot.com",
    messagingSenderId: "898290307420",
    appId: "1:898290307420:android:e2f7519aadda9bf530f199",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

export { auth };
