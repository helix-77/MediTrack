import { createHmac, timingSafeEqual } from "node:crypto";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";
import type { Request } from "firebase-functions/v2/https";

initializeApp();

const appsProSecret = defineSecret("APPSPRO_SECRET_KEY");
const appsProApiBaseUrl = "https://api.appspro.dev/api/v1";
const profileCollectionName = "profile";

type JsonObject = Record<string, unknown>;

interface HttpResponse {
  set(field: string, value: string): HttpResponse;
  status(code: number): HttpResponse;
  json(body: unknown): HttpResponse;
  send(body?: unknown): HttpResponse;
}

class ClientError extends Error {
  constructor(
    message: string,
    readonly status: number = 400,
  ) {
    super(message);
  }
}

function asObject(value: unknown): JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonObject)
    : {};
}

function readString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function normalizedPhone(value: unknown): string {
  let digits = String(value ?? "").replace(/\D/g, "");
  if (digits.length === 13 && digits.startsWith("880")) {
    digits = `0${digits.slice(3)}`;
  } else if (digits.length === 12 && digits.startsWith("88")) {
    digits = `0${digits.slice(2)}`;
  }

  if (!/^01[68]\d{8}$/.test(digits)) {
    throw new ClientError("Only valid Robi (018) and Airtel (016) numbers are supported.");
  }
  return digits;
}

function carrierStatus(response: JsonObject): string | undefined {
  const raw = asObject(response.raw);
  return readString(
    response.subscription_status ??
      response.subscriptionStatus ??
      raw.subscriptionStatus ??
      raw.subscription_status,
  )?.toUpperCase();
}

function carrierCode(response: JsonObject): string | undefined {
  const raw = asObject(response.raw);
  return readString(
    response.status_code ?? response.statusCode ?? raw.statusCode ?? raw.status_code,
  );
}

function isConfirmedUnregistered(response: JsonObject): boolean {
  return carrierStatus(response) === "UNREGISTERED";
}

function isUnsubscribeSuccess(response: JsonObject): boolean {
  return carrierCode(response) === "S1000" || isConfirmedUnregistered(response);
}

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return JSON.stringify(value.map(canonicalize));
  return JSON.stringify(canonicalize(value));
}

function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value !== null && typeof value === "object") {
    return Object.keys(value as JsonObject)
      .sort()
      .reduce<JsonObject>((result, key) => {
        result[key] = canonicalize((value as JsonObject)[key]);
        return result;
      }, {});
  }
  return value;
}

function setCorsHeaders(response: HttpResponse): void {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
}

async function authenticatedUid(request: Request): Promise<string> {
  const header = request.header("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.substring(7).trim() : "";
  if (!token) throw new ClientError("Sign in is required to manage a subscription.", 401);
  try {
    return (await getAuth().verifyIdToken(token)).uid;
  } catch (_) {
    throw new ClientError("Your sign-in session has expired. Please sign in again.", 401);
  }
}

async function appsProRequest(
  path: string,
  options: { method?: "GET" | "POST"; body?: JsonObject } = {},
): Promise<JsonObject> {
  const secret = appsProSecret.value();
  if (!secret) throw new Error("AppsPro secret is not configured.");

  const response = await fetch(`${appsProApiBaseUrl}${path}`, {
    method: options.method ?? "POST",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${secret}`,
      ...(options.body ? { "Content-Type": "application/json" } : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const text = await response.text();
  let data: JsonObject;
  try {
    data = asObject(JSON.parse(text));
  } catch (_) {
    throw new Error(`AppsPro returned an unreadable response (HTTP ${response.status}).`);
  }

  if (!response.ok) {
    throw new ClientError(
      readString(data.status_detail) ?? readString(data.message) ?? "AppsPro rejected the request.",
      response.status >= 500 ? 502 : response.status,
    );
  }
  return data;
}

function profileRef(uid: string) {
  return getFirestore().collection("users").doc(uid).collection(profileCollectionName).doc("main");
}

async function linkedPhone(uid: string): Promise<string> {
  const profile = await profileRef(uid).get();
  if (!profile.exists) throw new ClientError("Add and verify a Robi or Airtel mobile number first.", 409);
  return normalizedPhone(profile.data()?.bdMobile);
}

async function persistStatus(
  uid: string,
  status: "REGISTERED" | "UNREGISTERED",
  subscriberId?: string,
): Promise<void> {
  await profileRef(uid).set(
    {
      subscriptionStatus: status,
      subscriptionVerifiedAt: FieldValue.serverTimestamp(),
      ...(subscriberId ? { bdAppsSubscriberId: subscriberId } : {}),
    },
    { merge: true },
  );
}

async function processUnsubscribe(uid: string): Promise<JsonObject> {
  const phone = await linkedPhone(uid);
  const before = await appsProRequest("/sdk/status", { body: { phone } });
  if (isConfirmedUnregistered(before)) {
    await persistStatus(uid, "UNREGISTERED");
    return {
      ...before,
      status_code: "S1000",
      status_detail: "Subscription is already unregistered.",
      subscription_status: "UNREGISTERED",
    };
  }

  const unsubscribe = await appsProRequest("/sdk/unsubscribe", { body: { phone } });
  if (isUnsubscribeSuccess(unsubscribe)) {
    await persistStatus(uid, "UNREGISTERED");
    return unsubscribe;
  }

  // E1951 means either an invalid carrier address or an already-unregistered
  // user. Ask AppsPro for live status once more before changing entitlement.
  const after = await appsProRequest("/sdk/status", { body: { phone } });
  if (isConfirmedUnregistered(after)) {
    await persistStatus(uid, "UNREGISTERED");
    return {
      ...after,
      status_code: "S1000",
      status_detail: "Subscription cancellation confirmed by the carrier.",
      subscription_status: "UNREGISTERED",
    };
  }

  return unsubscribe;
}

async function proxyAction(uid: string, payload: JsonObject): Promise<JsonObject> {
  const action = readString(payload.action);
  switch (action) {
    case "status": {
      const phone = normalizedPhone(payload.phone);
      const result = await appsProRequest("/sdk/status", { body: { phone } });
      const status = carrierStatus(result);
      if (status === "REGISTERED" || isConfirmedUnregistered(result)) {
        await persistStatus(uid, status === "REGISTERED" ? "REGISTERED" : "UNREGISTERED");
      }
      return result;
    }
    case "otp_request":
      return appsProRequest("/sdk/otp/request", { body: { phone: normalizedPhone(payload.phone) } });
    case "otp_verify": {
      const referenceNo = readString(payload.reference_no);
      const otp = readString(payload.otp);
      if (!referenceNo || !otp) throw new ClientError("OTP reference and code are required.");
      const result = await appsProRequest("/sdk/otp/verify", {
        body: { reference_no: referenceNo, otp },
      });
      if (carrierStatus(result) === "REGISTERED") {
        await persistStatus(uid, "REGISTERED", readString(result.subscriber_id));
      }
      return result;
    }
    case "subscribe": {
      const phone = normalizedPhone(payload.phone);
      const result = await appsProRequest("/sdk/subscribe", { body: { phone } });
      if (carrierStatus(result) === "REGISTERED") await persistStatus(uid, "REGISTERED");
      return result;
    }
    case "unsubscribe":
      return processUnsubscribe(uid);
    case "verify": {
      const subscriberId = readString(payload.subscriber_id);
      if (!subscriberId) throw new ClientError("Subscriber ID is required.");
      return appsProRequest(`/sdk/verify/${encodeURIComponent(subscriberId)}`, { method: "GET" });
    }
    case "app_info": {
      const key = readString(payload.publishable_key);
      if (!key) throw new ClientError("AppsPro publishable key is not configured.");
      return appsProRequest(`/sdk/app-info?publishable_key=${encodeURIComponent(key)}`, { method: "GET" });
    }
    default:
      throw new ClientError("Unsupported AppsPro action.");
  }
}

export const appsProProxy = onRequest(
  { region: "asia-south1", secrets: [appsProSecret] },
  async (request, response) => {
    setCorsHeaders(response);
    if (request.method === "OPTIONS") {
      response.status(204).send();
      return;
    }
    if (request.method !== "POST") {
      response.status(405).json({ error: "Method not allowed." });
      return;
    }

    try {
      const uid = await authenticatedUid(request);
      const result = await proxyAction(uid, asObject(request.body));
      response.status(200).json(result);
    } catch (error) {
      const clientError = error instanceof ClientError ? error : undefined;
      logger.error("AppsPro proxy request failed", {
        status: clientError?.status ?? 500,
        code: error instanceof Error ? error.name : "unknown",
      });
      response.status(clientError?.status ?? 500).json({
        error: clientError?.message ?? "Subscription service is temporarily unavailable.",
      });
    }
  },
);

function signatureIsValid(request: Request): boolean {
  const signature = request.header("X-Signature");
  if (!signature) return false;
  const expected = createHmac("sha256", appsProSecret.value())
    .update(canonicalJson(request.body))
    .digest("hex");
  const actualBuffer = Buffer.from(signature, "utf8");
  const expectedBuffer = Buffer.from(expected, "utf8");
  return actualBuffer.length === expectedBuffer.length && timingSafeEqual(actualBuffer, expectedBuffer);
}

async function applyWebhookStatus(payload: JsonObject): Promise<number> {
  const event = readString(payload.event)?.toLowerCase();
  const data = asObject(payload.data);
  const subscriberId = readString(data.subscriberId);
  if (!event || !subscriberId) return 0;

  const status = event === "subscriber.cancelled"
    ? "UNREGISTERED"
    : event === "subscriber.created" || event === "subscriber.reactivated"
      ? "REGISTERED"
      : undefined;
  if (!status) return 0;

  const phone = normalizedPhone(subscriberId);
  const profiles = await getFirestore()
    .collectionGroup(profileCollectionName)
    .where("bdMobile", "==", phone)
    .get();
  await Promise.all(
    profiles.docs.map((profile) => profile.ref.set({
      subscriptionStatus: status,
      subscriptionVerifiedAt: FieldValue.serverTimestamp(),
      bdAppsSubscriberId: subscriberId,
    }, { merge: true })),
  );
  return profiles.size;
}

export const appsProWebhook = onRequest(
  { region: "asia-south1", secrets: [appsProSecret] },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).json({ error: "Method not allowed." });
      return;
    }
    if (!signatureIsValid(request)) {
      logger.warn("AppsPro webhook rejected: invalid signature");
      response.status(401).json({ error: "Invalid signature." });
      return;
    }

    try {
      const updated = await applyWebhookStatus(asObject(request.body));
      response.status(200).json({ received: true, updated });
    } catch (error) {
      logger.error("AppsPro webhook processing failed", {
        code: error instanceof Error ? error.name : "unknown",
      });
      response.status(500).json({ error: "Webhook processing failed." });
    }
  },
);
