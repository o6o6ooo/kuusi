import {randomUUID} from "node:crypto";
import {strict as assert} from "node:assert";
import {
  FirebaseApp,
  deleteApp,
  initializeApp
} from "firebase/app";
import {
  Auth,
  connectAuthEmulator,
  getAuth,
  signInAnonymously
} from "firebase/auth";
import {
  Firestore,
  connectFirestoreEmulator,
  getFirestore as getClientFirestore
} from "firebase/firestore";
import {
  Functions,
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable
} from "firebase/functions";
import {
  FirebaseStorage,
  connectStorageEmulator,
  getStorage as getClientStorage
} from "firebase/storage";
import {
  App as AdminApp,
  deleteApp as deleteAdminApp,
  getApps as getAdminApps,
  initializeApp as initializeAdminApp
} from "firebase-admin/app";
import {
  Firestore as AdminFirestore,
  getFirestore as getAdminFirestore
} from "firebase-admin/firestore";
import {
  Storage as AdminStorage,
  getStorage as getAdminStorage
} from "firebase-admin/storage";

export const PROJECT_ID = "demo-kuusi";
export const AUTH_HOST = "127.0.0.1";
export const AUTH_PORT = 9099;
export const FIRESTORE_HOST = "127.0.0.1";
export const FIRESTORE_PORT = 8080;
export const FUNCTIONS_HOST = "127.0.0.1";
export const FUNCTIONS_PORT = 5001;
export const STORAGE_HOST = "127.0.0.1";
export const STORAGE_PORT = 9199;
export const FUNCTIONS_REGION = "europe-west2";
export const STORAGE_BUCKET = `${PROJECT_ID}.appspot.com`;

const ADMIN_APP_NAME = "kuusi-integration-tests";
const APP_ID = "1:1234567890:web:kuusi-integration";
const clientApps = new Set<FirebaseApp>();

export type EmulatorClient = {
  app: FirebaseApp;
  auth: Auth;
  firestore: Firestore;
  functions: Functions;
  storage: FirebaseStorage;
  uid?: string;
};

function integrationAdminApp(): AdminApp {
  const existing = getAdminApps().find((app) => app.name === ADMIN_APP_NAME);
  if (existing) {
    return existing;
  }

  return initializeAdminApp(
    {
      projectId: PROJECT_ID,
      storageBucket: STORAGE_BUCKET
    },
    ADMIN_APP_NAME
  );
}

export function adminFirestore(): AdminFirestore {
  return getAdminFirestore(integrationAdminApp());
}

export function adminStorage(): AdminStorage {
  return getAdminStorage(integrationAdminApp());
}

async function clearEmulator(url: string, label: string): Promise<void> {
  const response = await fetch(url, {method: "DELETE"});
  if (!response.ok) {
    throw new Error(
      `Could not clear ${label}: ${response.status} ${await response.text()}`
    );
  }
}

export async function resetFirebaseEmulators(): Promise<void> {
  await Promise.all([
    clearEmulator(
      `http://${FIRESTORE_HOST}:${FIRESTORE_PORT}/emulator/v1/projects/` +
        `${PROJECT_ID}/databases/(default)/documents`,
      "Firestore emulator"
    ),
    clearEmulator(
      `http://${AUTH_HOST}:${AUTH_PORT}/emulator/v1/projects/` +
        `${PROJECT_ID}/accounts`,
      "Auth emulator"
    )
  ]);

  const [files] = await adminStorage().bucket().getFiles();
  await Promise.all(files.map((file) => file.delete({ignoreNotFound: true})));
}

export async function createEmulatorClient(
  authenticated = true
): Promise<EmulatorClient> {
  const app = initializeApp(
    {
      apiKey: "demo-api-key",
      appId: APP_ID,
      authDomain: `${PROJECT_ID}.firebaseapp.com`,
      projectId: PROJECT_ID,
      storageBucket: STORAGE_BUCKET
    },
    `integration-client-${randomUUID()}`
  );
  clientApps.add(app);

  const auth = getAuth(app);
  const firestore = getClientFirestore(app);
  const functions = getFunctions(app, FUNCTIONS_REGION);
  const storage = getClientStorage(app);

  connectAuthEmulator(
    auth,
    `http://${AUTH_HOST}:${AUTH_PORT}`,
    {disableWarnings: true}
  );
  connectFirestoreEmulator(firestore, FIRESTORE_HOST, FIRESTORE_PORT);
  connectFunctionsEmulator(functions, FUNCTIONS_HOST, FUNCTIONS_PORT);
  connectStorageEmulator(storage, STORAGE_HOST, STORAGE_PORT);

  if (!authenticated) {
    return {app, auth, firestore, functions, storage};
  }

  const credential = await signInAnonymously(auth);
  return {
    app,
    auth,
    firestore,
    functions,
    storage,
    uid: credential.user.uid
  };
}

export async function callFunction<Result>(
  client: EmulatorClient,
  name: string,
  data: unknown
): Promise<Result> {
  const callable = httpsCallable<unknown, Result>(client.functions, name);
  return (await callable(data)).data;
}

export async function waitForDocument(
  collection: string,
  documentID: string,
  timeoutMilliseconds = 5_000
): Promise<void> {
  const deadline = Date.now() + timeoutMilliseconds;

  while (Date.now() < deadline) {
    const snapshot = await adminFirestore()
      .collection(collection)
      .doc(documentID)
      .get();
    if (snapshot.exists) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }

  throw new Error(
    `Timed out waiting for ${collection}/${documentID} in Firestore`
  );
}

export async function disposeEmulatorClients(): Promise<void> {
  const apps = [...clientApps];
  clientApps.clear();
  const adminApp = getAdminApps().find((app) => app.name === ADMIN_APP_NAME);

  await Promise.all([
    ...apps.map((app) => deleteApp(app)),
    ...(adminApp ? [deleteAdminApp(adminApp)] : [])
  ]);
}

export function firebaseErrorCode(error: unknown): string {
  return typeof error === "object" && error !== null && "code" in error ?
    String(error.code) :
    "";
}

export async function assertFirebaseError(
  operation: () => Promise<unknown>,
  expectedCode: string
): Promise<void> {
  await assert.rejects(operation, (error: unknown) => {
    assert.equal(firebaseErrorCode(error), expectedCode);
    return true;
  });
}

export async function assertPermissionDenied(
  operation: () => Promise<unknown>
): Promise<void> {
  await assert.rejects(operation, (error: unknown) => {
    const code = firebaseErrorCode(error);
    const message = error instanceof Error ? error.message : String(error);
    assert.ok(
      /permission[_ /-]denied/i.test(`${code} ${message}`) ||
        code === "storage/unauthorized",
      `Expected a permission-denied error, received: ${code} ${message}`
    );
    return true;
  });
}
