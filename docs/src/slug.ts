import type { ReactNode } from "react";

export function slug(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[`*_[\]]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

export function headingText(children: ReactNode): string {
  if (typeof children === "string" || typeof children === "number") {
    return String(children);
  }
  if (Array.isArray(children)) {
    return children.map(headingText).join("");
  }
  return "";
}
