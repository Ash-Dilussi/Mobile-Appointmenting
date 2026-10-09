(() => {
  "use strict";

  const form = document.querySelector("#request-form");
  const emailInput = document.querySelector("#email");
  const submitButton = document.querySelector("#submit-button");
  const status = document.querySelector("#status");
  const storageKey = "booklyDeletionEmail";

  const showStatus = (message, kind = "info") => {
    status.hidden = false;
    status.className = `status ${kind}`;
    status.textContent = message;
  };

  const setBusy = (busy) => {
    submitButton.disabled = busy;
    emailInput.disabled = busy;
  };

  const completeVerifiedDeletion = async () => {
    if (!firebase.auth().isSignInWithEmailLink(window.location.href)) return;
    const email = window.localStorage.getItem(storageKey) || window.prompt(
      "Confirm the email address that received this verification link:",
    );
    if (!email) {
      showStatus("Enter the account email to finish verification.", "error");
      return;
    }

    setBusy(true);
    showStatus("Verifying the link. Your account has not been deleted yet.");
    try {
      await firebase.auth().signInWithEmailLink(email, window.location.href);
      showStatus("Email verified. Deleting the account now.");
      const deleteMyAccount = firebase.functions().httpsCallable("deleteMyAccount");
      await deleteMyAccount({deleteInstitution: false, source: "web"});
      window.localStorage.removeItem(storageKey);
      showStatus("Your Bookly account has been deleted.", "success");
      form.hidden = true;
    } catch (error) {
      const message = error && error.message
        ? error.message
        : "The request could not be completed. Contact bookly.support@gmail.com.";
      showStatus(message, "error");
      setBusy(false);
    }
  };

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const email = emailInput.value.trim();
    if (!email) return;
    setBusy(true);
    try {
      const continueUrl = `${window.location.origin}/delete-account/`;
      await firebase.auth().sendSignInLinkToEmail(email, {
        url: continueUrl,
        handleCodeInApp: true,
      });
      window.localStorage.setItem(storageKey, email);
      showStatus(
        "Verification link sent. Check your email. No data has been deleted yet.",
        "success",
      );
    } catch (error) {
      showStatus(
        error && error.message ? error.message : "Unable to send the link.",
        "error",
      );
    } finally {
      setBusy(false);
    }
  });

  completeVerifiedDeletion();
})();
