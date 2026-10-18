/**
 * Computes the SHA-256 hash of a given string and returns it as a hexadecimal string.
 *
 * @param message - The input string to hash.
 * @returns A Promise that resolves to the SHA-256 hash as a hex string.
 *
 * @example
 * const hash = await sha256("Hello World");
 * console.log(hash); // e.g. "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
 */
export async function sha256(message: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(message);
  const hashBuffer = await window.crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return hashHex;
}