import { cert, getApps, initializeApp } from "npm:firebase-admin@^11.11.0/app";
import { getAuth } from "npm:firebase-admin@^11.11.0/auth";

function getFirebaseApp() {
  const existingApp = getApps()[0];
  if (existingApp) return existingApp;

  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Firebase Admin environment is not configured.");
  }

  return initializeApp({
    credential: cert({ projectId, clientEmail, privateKey }),
  });
}

export function firebaseAdminAuth() {
  return getAuth(getFirebaseApp());
}

export async function requireFirebaseUser(request: Request) {
  const firebaseHeader = request.headers.get("x-firebase-token");
  const authHeader = request.headers.get("authorization");
  const token = firebaseHeader || authHeader?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) throw new Error("A Firebase sign-in is required.");

  const apiKey = request.headers.get("x-firebase-api-key") ?? Deno.env.get("FIREBASE_API_KEY");
  if (!apiKey) throw new Error("Firebase API Key is missing.");

  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ idToken: token })
  });
  
  const data = await res.json();
  if (!res.ok || !data.users || data.users.length === 0) {
    throw new Error("A Firebase sign-in is required.");
  }

  return { uid: data.users[0].localId };
}
