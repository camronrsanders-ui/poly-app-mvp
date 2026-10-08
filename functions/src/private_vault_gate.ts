import {HttpsError} from 'firebase-functions/v2/https';

// Keep this false until the entire Private Vault release checklist has passed.
// This is deliberately server-side: a Flutter feature flag alone cannot stop a
// modified client from calling exported Cloud Functions directly.
export const privateVaultServerEnabled = false;

export function assertPrivateVaultEnabled(): void {
  if (!privateVaultServerEnabled) {
    throw new HttpsError('failed-precondition', 'Private Vault is not available yet.');
  }
}
