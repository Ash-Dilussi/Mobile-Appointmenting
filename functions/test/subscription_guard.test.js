const assert = require("node:assert/strict");
const test = require("node:test");

const {
  hasLiveSubscription,
  institutionIdForProvisioning,
  isAlwaysSoloBusiness,
  provisioningRequestId,
} = require("../lib/index.js");

test("allows the absent/free scaffold state", () => {
  assert.equal(hasLiveSubscription(undefined), false);
  assert.equal(hasLiveSubscription({tier: "free"}), false);
  assert.equal(
    hasLiveSubscription({tier: "free", status: "cancelled", stripeSubscriptionId: null}),
    false,
  );
});

test("simplifies deletion only for a known always-solo business", () => {
  assert.equal(isAlwaysSoloBusiness(false, ["owner"], "owner"), true);
  assert.equal(isAlwaysSoloBusiness(true, ["owner"], "owner"), false);
  assert.equal(isAlwaysSoloBusiness(undefined, ["owner"], "owner"), false);
  assert.equal(
    isAlwaysSoloBusiness(false, ["owner", "officer"], "owner"),
    false,
  );
});

test("blocks paid tiers, live states, and external billing ids", () => {
  assert.equal(hasLiveSubscription({tier: "pro"}), true);
  assert.equal(hasLiveSubscription({tier: "free", status: "active"}), true);
  assert.equal(
    hasLiveSubscription({tier: "free", stripeSubscriptionId: "sub_live"}),
    true,
  );
});

test("derives stable, user-scoped provisioning identities", () => {
  const first = provisioningRequestId("owner-a", "attempt_12345678901234567890");
  assert.equal(first.length, 64);
  assert.equal(
    first,
    provisioningRequestId("owner-a", "attempt_12345678901234567890"),
  );
  assert.notEqual(
    first,
    provisioningRequestId("owner-b", "attempt_12345678901234567890"),
  );
  assert.equal(
    institutionIdForProvisioning("owner-a", "attempt_12345678901234567890"),
    `inst_${first.slice(0, 32)}`,
  );
});
