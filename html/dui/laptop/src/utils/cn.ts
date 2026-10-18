import { twMerge } from "tailwind-merge";

/**
 * Merges Tailwind classes without style conflicts.
 * Accepts strings, undefined, or null values.
 */
export function cn(...inputs: (string | undefined | null | boolean)[]) {
  return twMerge(
    inputs
      .filter(Boolean) // Removes undefined, null, and false values
      .join(" ")       // Joins remaining strings with a space
  );
}