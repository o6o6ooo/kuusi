import { initializeApp } from "firebase/app";
import { getAuth, GoogleAuthProvider, signInWithCredential } from "firebase/auth";
import { firebaseConfig } from "./config/firebaseConfig";

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);

export const signInWithGoogleFirebase = async (idToken: string, accessToken: string) => {
    const credential = GoogleAuthProvider.credential(idToken, accessToken);
    return await signInWithCredential(auth, credential);
};