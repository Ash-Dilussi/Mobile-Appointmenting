const assert = require("node:assert/strict");
const test = require("node:test");

const {initializeApp, deleteApp} = require("firebase/app");
const {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  signInWithEmailAndPassword,
} = require("firebase/auth");
const {
  Timestamp,
  collection,
  connectFirestoreEmulator,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  query,
  setDoc,
  where,
} = require("firebase/firestore");
const {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} = require("firebase/functions");
const {
  initializeApp: initializeAdminApp,
  deleteApp: deleteAdminApp,
} = require("firebase-admin/app");
const {getAuth: getAdminAuth} = require("firebase-admin/auth");
const {getFirestore: getAdminFirestore} = require("firebase-admin/firestore");

const projectId = process.env.GCLOUD_PROJECT || "bookly-1f5f7";
const clientApps = [];
const adminApp = initializeAdminApp({projectId}, "solo-hardening-tests");
const adminDb = getAdminFirestore(adminApp);

function client(name) {
  const app = initializeApp(
    {
      apiKey: "demo-key",
      authDomain: `${projectId}.firebaseapp.com`,
      projectId,
      appId: `demo-${name}`,
    },
    name,
  );
  clientApps.push(app);
  const auth = getAuth(app);
  const firestore = getFirestore(app);
  const functions = getFunctions(app);
  connectAuthEmulator(auth, "http://127.0.0.1:9099", {
    disableWarnings: true,
  });
  connectFirestoreEmulator(firestore, "127.0.0.1", 8080);
  connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  return {auth, firestore, functions};
}

async function createOwner(name, email) {
  const sdk = client(name);
  const credential = await createUserWithEmailAndPassword(
    sdk.auth,
    email,
    "OwnerPass!234",
  );
  await setDoc(doc(sdk.firestore, "users", credential.user.uid), {
    uid: credential.user.uid,
    email,
    displayName: "Test Owner",
    photoUrl: null,
    role: "unknown",
    institutionId: "",
    isEmailVerified: false,
    shouldPromptPasswordChange: false,
    createdAt: Timestamp.now(),
  });
  return {...sdk, uid: credential.user.uid};
}

test.after(async () => {
  await Promise.all(clientApps.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

test("team provisioning and the solo-to-officer-to-removal-to-deletion journey", async () => {
  const owner = await createOwner(
    "owner-team-flow",
    "owner-team-flow@example.com",
  );
  const provision = httpsCallable(owner.functions, "provisionBusiness");
  const provisionResult = await provision({
    idempotencyKey: "attempt_team_12345678901234567890",
    name: "North Studio",
    themePreset: "clinicTeal",
    address: "10 Main Street",
    phone: "+94 77 123 4567",
    email: "hello@north.example",
  });
  const institutionId = provisionResult.data.institution.id;
  const institutionSnapshot = await adminDb
    .collection("institutions")
    .doc(institutionId)
    .get();
  const institution = institutionSnapshot.data();

  // The original form fields remain field-for-field equivalent. The two
  // provisioning fields are intentional server-only metadata for recovery.
  assert.deepEqual(
    {
      id: institution.id,
      ownerId: institution.ownerId,
      name: institution.name,
      themePreset: institution.themePreset,
      address: institution.address,
      phone: institution.phone,
      email: institution.email,
      hasEverHadAdditionalStaff: institution.hasEverHadAdditionalStaff,
    },
    {
      id: institutionId,
      ownerId: owner.uid,
      name: "North Studio",
      themePreset: "clinicTeal",
      address: "10 Main Street",
      phone: "+94 77 123 4567",
      email: "hello@north.example",
      hasEverHadAdditionalStaff: false,
    },
  );
  assert.ok(institution.createdAt);
  assert.ok(institution.updatedAt);
  assert.equal(institution.provisioningMode, "atomic-v1");
  assert.equal(institution.provisioningRequestId.length, 64);

  await assert.rejects(
    setDoc(doc(owner.firestore, "users", "forged-officer"), {
      uid: "forged-officer",
      email: "forged@example.com",
      displayName: "Forged",
      photoUrl: null,
      role: "officer",
      institutionId,
      isEmailVerified: false,
      shouldPromptPasswordChange: true,
      createdAt: Timestamp.now(),
    }),
  );

  const createOfficer = httpsCallable(owner.functions, "createOfficer");
  const officerResult = await createOfficer({
    displayName: "Jamie Officer",
    email: "jamie-officer@example.com",
  });
  const officerUid = officerResult.data.uid;
  assert.ok(officerResult.data.temporaryPassword.length >= 12);
  const staffedInstitution = await adminDb
    .collection("institutions")
    .doc(institutionId)
    .get();
  assert.equal(
    staffedInstitution.data().hasEverHadAdditionalStaff,
    true,
  );

  await assert.rejects(
    createOfficer({
      displayName: "Jamie Again",
      email: "jamie-officer@example.com",
    }),
    (error) =>
      error.code === "functions/failed-precondition" &&
      error.details.reason === "ALREADY_HAS_BOOKLY_ACCOUNT",
  );

  const officer = client("officer-team-flow");
  await signInWithEmailAndPassword(
    officer.auth,
    "jamie-officer@example.com",
    officerResult.data.temporaryPassword,
  );
  assert.equal(
    (await getDoc(doc(officer.firestore, "users", officerUid))).data().role,
    "officer",
  );

  await httpsCallable(owner.functions, "removeOfficer")({officerUid});
  const removedProfile = await adminDb.collection("users").doc(officerUid).get();
  assert.equal(removedProfile.data().institutionId, "");
  assert.equal(removedProfile.data().role, "unknown");
  assert.equal(removedProfile.data().status, "left");
  assert.equal(
    (await adminDb.collection("institutions").doc(institutionId).get()).data()
      .hasEverHadAdditionalStaff,
    true,
  );
  await assert.rejects(
    getDoc(doc(officer.firestore, "institutions", institutionId)),
  );

  await httpsCallable(owner.functions, "deleteMyAccount")({
    deleteInstitution: true,
    source: "emulator-test",
  });
  assert.equal(
    (await adminDb.collection("institutions").doc(institutionId).get()).exists,
    false,
  );
  assert.equal(
    (await adminDb.collection("users").doc(owner.uid).get()).exists,
    false,
  );
  assert.equal(
    (await getAdminAuth(adminApp).getUser(officerUid)).uid,
    officerUid,
  );
});

test("an unacknowledged response retries idempotently without an orphan", async () => {
  const owner = await createOwner(
    "owner-idempotency",
    "owner-idempotency@example.com",
  );
  const provision = httpsCallable(owner.functions, "provisionBusiness");
  const payload = {
    idempotencyKey: "attempt_solo_12345678901234567890",
    name: "Solo Studio",
    themePreset: "solarOrange",
    address: null,
    phone: null,
    email: null,
  };

  // Treat the first response as lost, then repeat the exact attempt.
  await provision(payload);
  const retry = await provision(payload);
  const institutionId = retry.data.institution.id;
  const ownedBusinesses = await getDocs(
    query(
      collection(owner.firestore, "institutions"),
      where("ownerId", "==", owner.uid),
    ),
  );
  assert.equal(ownedBusinesses.size, 1);
  assert.equal(ownedBusinesses.docs[0].id, institutionId);

  await assert.rejects(
    setDoc(doc(owner.firestore, "institutions", "manual-orphan"), {
      id: "manual-orphan",
      ownerId: owner.uid,
      name: "Manual orphan",
      themePreset: "solarOrange",
      address: null,
      phone: null,
      email: null,
      hasEverHadAdditionalStaff: false,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    }),
  );

  await httpsCallable(owner.functions, "deleteMyAccount")({
    deleteInstitution: false,
    source: "emulator-test",
  });
  assert.equal(
    (await adminDb.collection("institutions").doc(institutionId).get()).exists,
    false,
  );
});
