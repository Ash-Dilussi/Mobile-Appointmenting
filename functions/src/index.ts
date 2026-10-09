import {createHash, randomBytes} from "node:crypto";

import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {
  DocumentData,
  Firestore,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";

initializeApp();

const SUPPORT_EMAIL = "bookly.support@gmail.com";
const BUSINESS_PROVISIONING_COLLECTION = "businessProvisioning";
const BUSINESS_NAME_MAX = 100;
const ADDRESS_MAX = 500;
const PHONE_MAX = 50;
const EMAIL_MAX = 254;
const DISPLAY_NAME_MAX = 100;
const VALID_THEME_PRESETS = new Set([
  "solarOrange",
  "clinicTeal",
  "midnightCharcoal",
  "forestGreen",
  "royalPurple",
]);

type SubscriptionData = Record<string, unknown> | undefined;

interface BusinessInput {
  idempotencyKey: string;
  name: string;
  themePreset: string;
  address: string | null;
  phone: string | null;
  email: string | null;
}

export function hasLiveSubscription(data: SubscriptionData): boolean {
  if (!data) return false;

  const tier = String(data.tier ?? "free").trim().toLowerCase();
  const status = String(data.status ?? "").trim().toLowerCase();
  const externalIdFields = [
    "stripeSubscriptionId",
    "stripeCustomerId",
    "paddleSubscriptionId",
    "paddleCustomerId",
  ];
  const hasExternalBillingId = externalIdFields.some((field) => {
    const value = data[field];
    return typeof value === "string" && value.trim().length > 0;
  });
  const liveStatuses = new Set([
    "active",
    "trialing",
    "past_due",
    "unpaid",
    "paused",
  ]);

  return tier !== "free" || hasExternalBillingId || liveStatuses.has(status);
}

export function isAlwaysSoloBusiness(
  hasEverHadAdditionalStaff: unknown,
  memberUids: string[],
  ownerUid: string,
): boolean {
  return hasEverHadAdditionalStaff === false &&
    memberUids.every((memberUid) => memberUid === ownerUid);
}

export function provisioningRequestId(
  uid: string,
  idempotencyKey: string,
): string {
  return createHash("sha256")
    .update(`${uid}:${idempotencyKey}`)
    .digest("hex");
}

export function institutionIdForProvisioning(
  uid: string,
  idempotencyKey: string,
): string {
  return `inst_${provisioningRequestId(uid, idempotencyKey).slice(0, 32)}`;
}

function requiredString(
  data: unknown,
  field: string,
  maxLength: number,
): string {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "Request data is required.");
  }
  const value = (data as Record<string, unknown>)[field];
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be text.`);
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must contain between 1 and ${maxLength} characters.`,
    );
  }
  return normalized;
}

function optionalString(
  data: unknown,
  field: string,
  maxLength: number,
): string | null {
  if (!data || typeof data !== "object") return null;
  const value = (data as Record<string, unknown>)[field];
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be text.`);
  }
  const normalized = value.trim();
  if (normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must be no longer than ${maxLength} characters.`,
    );
  }
  return normalized.length === 0 ? null : normalized;
}

function validateEmail(email: string | null): void {
  if (email === null) return;
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailPattern.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }
}

function parseBusinessInput(data: unknown): BusinessInput {
  const idempotencyKey = requiredString(data, "idempotencyKey", 128);
  if (!/^[A-Za-z0-9_-]{20,128}$/.test(idempotencyKey)) {
    throw new HttpsError(
      "invalid-argument",
      "The setup attempt identifier is invalid.",
    );
  }
  const themePreset = requiredString(data, "themePreset", 40);
  if (!VALID_THEME_PRESETS.has(themePreset)) {
    throw new HttpsError("invalid-argument", "The selected theme is invalid.");
  }
  const email = optionalString(data, "email", EMAIL_MAX);
  validateEmail(email);
  return {
    idempotencyKey,
    name: requiredString(data, "name", BUSINESS_NAME_MAX),
    themePreset,
    address: optionalString(data, "address", ADDRESS_MAX),
    phone: optionalString(data, "phone", PHONE_MAX),
    email,
  };
}

function timestampToIso(value: unknown): string {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  return new Date().toISOString();
}

function institutionResponse(data: DocumentData): Record<string, unknown> {
  return {
    id: String(data.id ?? ""),
    ownerId: String(data.ownerId ?? ""),
    name: String(data.name ?? ""),
    themePreset: String(data.themePreset ?? ""),
    address: typeof data.address === "string" ? data.address : null,
    phone: typeof data.phone === "string" ? data.phone : null,
    email: typeof data.email === "string" ? data.email : null,
    hasEverHadAdditionalStaff: data.hasEverHadAdditionalStaff === true,
    createdAt: timestampToIso(data.createdAt),
    updatedAt: timestampToIso(data.updatedAt),
  };
}

async function deleteAuthUsers(uids: string[]): Promise<void> {
  for (let offset = 0; offset < uids.length; offset += 1000) {
    const result = await getAuth().deleteUsers(uids.slice(offset, offset + 1000));
    if (result.failureCount > 0) {
      const failedIndexes = result.errors.map((entry) => entry.index);
      logger.error("Some Auth identities could not be deleted", {
        failureCount: result.failureCount,
        failedIndexes,
      });
      throw new HttpsError(
        "internal",
        "The business could not be fully deleted. Contact support.",
      );
    }
  }
}

async function deleteProfileDocuments(uids: string[]): Promise<void> {
  const db = getFirestore();
  for (let offset = 0; offset < uids.length; offset += 400) {
    const batch = db.batch();
    for (const uid of uids.slice(offset, offset + 400)) {
      batch.delete(db.collection("users").doc(uid));
    }
    await batch.commit();
  }
}

async function deleteProvisioningReceipts(
  db: Firestore,
  institutionId: string,
): Promise<void> {
  const receipts = await db
    .collection(BUSINESS_PROVISIONING_COLLECTION)
    .where("institutionId", "==", institutionId)
    .get();
  if (receipts.empty) return;
  const batch = db.batch();
  receipts.docs.forEach((receipt) => batch.delete(receipt.ref));
  await batch.commit();
}

export const provisionBusiness = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in before setting up a business.",
    );
  }
  const input = parseBusinessInput(request.data);
  const db = getFirestore();
  const requestId = provisioningRequestId(uid, input.idempotencyKey);
  const institutionId = institutionIdForProvisioning(uid, input.idempotencyKey);
  const requestRef = db
    .collection(BUSINESS_PROVISIONING_COLLECTION)
    .doc(requestId);
  const institutionRef = db.collection("institutions").doc(institutionId);
  const profileRef = db.collection("users").doc(uid);

  const institution = await db.runTransaction(async (transaction) => {
    const [attemptSnapshot, profileSnapshot, institutionSnapshot] =
      await Promise.all([
        transaction.get(requestRef),
        transaction.get(profileRef),
        transaction.get(institutionRef),
      ]);
    if (!profileSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Finish account setup before creating a business.",
        {reason: "PROFILE_NOT_READY"},
      );
    }
    const profile = profileSnapshot.data() ?? {};

    if (attemptSnapshot.exists) {
      const attempt = attemptSnapshot.data() ?? {};
      if (attempt.ownerId !== uid || attempt.institutionId !== institutionId) {
        throw new HttpsError(
          "permission-denied",
          "This setup attempt does not belong to the signed-in account.",
        );
      }
      if (!institutionSnapshot.exists) {
        throw new HttpsError(
          "internal",
          "The existing setup attempt could not be recovered.",
          {reason: "MISSING_INSTITUTION"},
        );
      }
      if (profile.institutionId === "" && profile.role === "unknown") {
        transaction.update(profileRef, {
          institutionId,
          role: "owner",
          updatedAt: Timestamp.now(),
        });
      } else if (
        profile.institutionId !== institutionId ||
        profile.role !== "owner"
      ) {
        throw new HttpsError(
          "failed-precondition",
          "This account already belongs to a Bookly business.",
          {reason: "ALREADY_LINKED"},
        );
      }
      return institutionSnapshot.data() ?? {};
    }

    if (profile.role !== "unknown" || profile.institutionId !== "") {
      throw new HttpsError(
        "failed-precondition",
        "This account already belongs to a Bookly business.",
        {reason: "ALREADY_LINKED"},
      );
    }
    if (institutionSnapshot.exists) {
      throw new HttpsError(
        "already-exists",
        "The deterministic business identifier is already in use.",
      );
    }

    const now = Timestamp.now();
    const institutionData = {
      id: institutionId,
      ownerId: uid,
      name: input.name,
      themePreset: input.themePreset,
      address: input.address,
      phone: input.phone,
      email: input.email,
      hasEverHadAdditionalStaff: false,
      createdAt: now,
      updatedAt: now,
      provisioningMode: "atomic-v1",
      provisioningRequestId: requestId,
    };
    transaction.create(institutionRef, institutionData);
    transaction.update(profileRef, {
      institutionId,
      role: "owner",
      updatedAt: now,
    });
    transaction.create(requestRef, {
      ownerId: uid,
      institutionId,
      status: "completed",
      createdAt: now,
      updatedAt: now,
    });
    return institutionData;
  });

  logger.info("Atomic business provisioning completed", {
    uid,
    institutionId,
    requestId,
  });
  return {
    institution: institutionResponse(institution),
    idempotent: true,
  };
});

function generateTemporaryPassword(): string {
  const upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  const lower = "abcdefghijkmnopqrstuvwxyz";
  const digits = "23456789";
  const symbols = "!@#%*+-_";
  const all = `${upper}${lower}${digits}${symbols}`;
  const pick = (source: string): string =>
    source[randomBytes(1)[0] % source.length];
  const characters = [
    pick(upper),
    pick(lower),
    pick(digits),
    pick(symbols),
    ...Array.from({length: 12}, () => pick(all)),
  ];
  for (let index = characters.length - 1; index > 0; index -= 1) {
    const swapIndex = randomBytes(1)[0] % (index + 1);
    [characters[index], characters[swapIndex]] = [
      characters[swapIndex],
      characters[index],
    ];
  }
  return characters.join("");
}

function isAuthUserNotFound(error: unknown): boolean {
  const code = (error as {code?: string})?.code;
  return code === "auth/user-not-found";
}

export const createOfficer = onCall(async (request) => {
  const ownerUid = request.auth?.uid;
  if (!ownerUid) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in before creating a staff account.",
    );
  }
  const displayName = requiredString(
    request.data,
    "displayName",
    DISPLAY_NAME_MAX,
  );
  const email = requiredString(request.data, "email", EMAIL_MAX).toLowerCase();
  validateEmail(email);

  const db = getFirestore();
  const ownerSnapshot = await db.collection("users").doc(ownerUid).get();
  const owner = ownerSnapshot.data() ?? {};
  const institutionId = String(owner.institutionId ?? "").trim();
  if (owner.role !== "owner" || institutionId.length === 0) {
    throw new HttpsError(
      "permission-denied",
      "Only a linked business owner can create staff accounts.",
    );
  }

  try {
    await getAuth().getUserByEmail(email);
    throw new HttpsError(
      "failed-precondition",
      "This person already has a Bookly business set up. Multi-business membership is not supported yet.",
      {
        reason: "ALREADY_HAS_BOOKLY_ACCOUNT",
        supportEmail: SUPPORT_EMAIL,
      },
    );
  } catch (error) {
    if (!isAuthUserNotFound(error)) throw error;
  }

  const temporaryPassword = generateTemporaryPassword();
  const officer = await getAuth().createUser({
    email,
    password: temporaryPassword,
    displayName,
    emailVerified: false,
  });

  try {
    await db.runTransaction(async (transaction) => {
      const ownerRef = db.collection("users").doc(ownerUid);
      const officerRef = db.collection("users").doc(officer.uid);
      const institutionRef = db.collection("institutions").doc(institutionId);
      const [freshOwnerSnapshot, officerSnapshot, institutionSnapshot] =
        await Promise.all([
          transaction.get(ownerRef),
          transaction.get(officerRef),
          transaction.get(institutionRef),
        ]);
      const freshOwner = freshOwnerSnapshot.data() ?? {};
      if (
        freshOwner.role !== "owner" ||
        freshOwner.institutionId !== institutionId ||
        !institutionSnapshot.exists ||
        institutionSnapshot.data()?.ownerId !== ownerUid
      ) {
        throw new HttpsError(
          "permission-denied",
          "Your owner membership changed before staff setup completed.",
        );
      }
      if (officerSnapshot.exists) {
        throw new HttpsError(
          "already-exists",
          "A profile already exists for this staff account.",
        );
      }
      const now = Timestamp.now();
      transaction.create(officerRef, {
        uid: officer.uid,
        email,
        displayName,
        photoUrl: null,
        role: "officer",
        institutionId,
        isEmailVerified: false,
        shouldPromptPasswordChange: true,
        createdAt: now,
        updatedAt: now,
      });
      transaction.update(institutionRef, {
        hasEverHadAdditionalStaff: true,
        updatedAt: now,
      });
    });
  } catch (error) {
    try {
      await getAuth().deleteUser(officer.uid);
    } catch (cleanupError) {
      logger.error("Failed to compensate officer Auth creation", {
        officerUid: officer.uid,
        cleanupError,
      });
    }
    throw error;
  }

  logger.info("Officer identity and membership created", {
    ownerUid,
    officerUid: officer.uid,
    institutionId,
  });
  return {uid: officer.uid, email, temporaryPassword};
});

export const removeOfficer = onCall(async (request) => {
  const ownerUid = request.auth?.uid;
  if (!ownerUid) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in before removing a staff account.",
    );
  }
  const officerUid = requiredString(request.data, "officerUid", 128);
  if (officerUid === ownerUid) {
    throw new HttpsError(
      "invalid-argument",
      "An owner cannot remove their own membership through the staff flow.",
    );
  }
  const db = getFirestore();
  let institutionId = "";
  await db.runTransaction(async (transaction) => {
    const ownerRef = db.collection("users").doc(ownerUid);
    const officerRef = db.collection("users").doc(officerUid);
    const [ownerSnapshot, officerSnapshot] = await Promise.all([
      transaction.get(ownerRef),
      transaction.get(officerRef),
    ]);
    const owner = ownerSnapshot.data() ?? {};
    const officer = officerSnapshot.data() ?? {};
    institutionId = String(owner.institutionId ?? "").trim();
    if (owner.role !== "owner" || institutionId.length === 0) {
      throw new HttpsError(
        "permission-denied",
        "Only a linked business owner can remove staff.",
      );
    }
    if (
      !officerSnapshot.exists ||
      officer.role !== "officer" ||
      officer.institutionId !== institutionId
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This person is no longer an Officer in your business.",
        {reason: "NOT_CURRENT_OFFICER"},
      );
    }
    const institutionRef = db.collection("institutions").doc(institutionId);
    const institutionSnapshot = await transaction.get(institutionRef);
    if (
      !institutionSnapshot.exists ||
      institutionSnapshot.data()?.ownerId !== ownerUid
    ) {
      throw new HttpsError(
        "permission-denied",
        "The business ownership record is not valid.",
      );
    }
    const now = Timestamp.now();
    transaction.update(officerRef, {
      institutionId: "",
      role: "unknown",
      status: "left",
      shouldPromptPasswordChange: false,
      updatedAt: now,
    });
    transaction.update(institutionRef, {
      hasEverHadAdditionalStaff: true,
      updatedAt: now,
    });
    transaction.delete(institutionRef.collection("members").doc(officerUid));
  });

  // Access rules read the Firestore profile on every request, so authorization
  // is already revoked. Revoking refresh tokens additionally bounds stale
  // authenticated sessions without relying on custom claims (none are used).
  await getAuth().revokeRefreshTokens(officerUid);
  logger.info("Officer membership removed", {
    ownerUid,
    officerUid,
    institutionId,
  });
  return {removed: true, officerUid, institutionId};
});

export const reconcileOrphanedBusinesses = onSchedule(
  {schedule: "every day 03:00", timeZone: "Etc/UTC"},
  async () => {
    const db = getFirestore();
    const cutoff = Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
    const candidates = await db
      .collection("institutions")
      .where("createdAt", "<=", cutoff)
      .limit(100)
      .get();

    for (const institutionSnapshot of candidates.docs) {
      const institution = institutionSnapshot.data();
      if (institution.provisioningMode !== "atomic-v1") continue;
      const institutionId = institutionSnapshot.id;
      const ownerId = String(institution.ownerId ?? "").trim();
      const requestId = String(institution.provisioningRequestId ?? "").trim();
      if (!ownerId || !requestId) {
        logger.error("Atomic business lacks reconciliation metadata", {
          institutionId,
        });
        continue;
      }

      const ownerRef = db.collection("users").doc(ownerId);
      const receiptRef = db
        .collection(BUSINESS_PROVISIONING_COLLECTION)
        .doc(requestId);
      const [ownerSnapshot, receiptSnapshot, membersSnapshot] =
        await Promise.all([
          ownerRef.get(),
          receiptRef.get(),
          db.collection("users")
            .where("institutionId", "==", institutionId)
            .limit(2)
            .get(),
        ]);
      const owner = ownerSnapshot.data() ?? {};
      if (owner.role === "owner" && owner.institutionId === institutionId) {
        continue;
      }
      if (!membersSnapshot.empty) {
        logger.error("Ownerless business still has linked members", {
          institutionId,
          memberCount: membersSnapshot.size,
        });
        continue;
      }
      const receipt = receiptSnapshot.data() ?? {};
      if (
        ownerSnapshot.exists &&
        owner.role === "unknown" &&
        owner.institutionId === "" &&
        receipt.ownerId === ownerId &&
        receipt.institutionId === institutionId
      ) {
        await db.runTransaction(async (transaction) => {
          const [freshOwner, freshInstitution] = await Promise.all([
            transaction.get(ownerRef),
            transaction.get(institutionSnapshot.ref),
          ]);
          if (
            freshOwner.data()?.role === "unknown" &&
            freshOwner.data()?.institutionId === "" &&
            freshInstitution.exists
          ) {
            transaction.update(ownerRef, {
              role: "owner",
              institutionId,
              updatedAt: Timestamp.now(),
            });
          }
        });
        logger.warn("Recovered an unacknowledged business owner link", {
          institutionId,
          ownerId,
        });
        continue;
      }

      await db.recursiveDelete(institutionSnapshot.ref);
      if (receiptSnapshot.exists) await receiptRef.delete();
      logger.warn("Deleted an abandoned atomic business", {
        institutionId,
        ownerId,
      });
    }
  },
);

export const deleteMyAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in before deleting an account.");
  }

  const db = getFirestore();
  const profileRef = db.collection("users").doc(uid);
  const profileSnapshot = await profileRef.get();
  const profile = profileSnapshot.data();
  const institutionId = String(profile?.institutionId ?? "").trim();
  const role = String(profile?.role ?? "unknown").trim().toLowerCase();
  const deleteInstitution = request.data?.deleteInstitution === true;

  if (role === "owner" && institutionId) {
    const institutionRef = db.collection("institutions").doc(institutionId);
    const institutionSnapshot = await institutionRef.get();
    const isSoleOwner =
      institutionSnapshot.exists && institutionSnapshot.data()?.ownerId === uid;
    const memberSnapshots = await db
      .collection("users")
      .where("institutionId", "==", institutionId)
      .get();
    const memberUids = new Set(memberSnapshots.docs.map((doc) => doc.id));
    memberUids.add(uid);
    const alwaysSolo = isAlwaysSoloBusiness(
      institutionSnapshot.data()?.hasEverHadAdditionalStaff,
      [...memberUids],
      uid,
    );

    if (isSoleOwner && !deleteInstitution && !alwaysSolo) {
      throw new HttpsError(
        "failed-precondition",
        `A sole owner must delete the business or keep the account. For a manual ownership transfer, contact ${SUPPORT_EMAIL}.`,
        {reason: "SOLE_OWNER", supportEmail: SUPPORT_EMAIL},
      );
    }

    if (isSoleOwner && (deleteInstitution || alwaysSolo)) {
      const subscriptionSnapshot = await institutionRef
        .collection("subscription")
        .doc("plan")
        .get();
      if (hasLiveSubscription(subscriptionSnapshot.data())) {
        throw new HttpsError(
          "failed-precondition",
          `A live subscription requires manual review. Contact ${SUPPORT_EMAIL}.`,
          {reason: "LIVE_SUBSCRIPTION", supportEmail: SUPPORT_EMAIL},
        );
      }

      // Firestore first, then Auth. If Firestore fails, identities remain so
      // support can retry safely; no institution is silently orphaned.
      await db.recursiveDelete(institutionRef);
      await deleteProvisioningReceipts(db, institutionId);
      await deleteProfileDocuments([...memberUids]);
      await deleteAuthUsers([...memberUids]);

      logger.info("Business deletion completed", {
        institutionId,
        deletedIdentityCount: memberUids.size,
        source: String(request.data?.source ?? "unknown"),
      });
      return {
        deleted: true,
        scope: "business",
        completedAt: new Date().toISOString(),
      };
    }
  }

  if (deleteInstitution) {
    throw new HttpsError(
      "permission-denied",
      "Only the business owner can delete a business.",
    );
  }

  // Remove any denormalized member row if an older deployment created one.
  if (institutionId) {
    await db
      .collection("institutions")
      .doc(institutionId)
      .collection("members")
      .doc(uid)
      .delete();
  }
  await profileRef.delete();
  await getAuth().revokeRefreshTokens(uid);
  await getAuth().deleteUser(uid);

  logger.info("Personal account deletion completed", {
    uid,
    source: String(request.data?.source ?? "unknown"),
  });
  return {
    deleted: true,
    scope: "account",
    completedAt: new Date().toISOString(),
  };
});
