import type { ButtonHTMLAttributes, ReactNode } from "react";
import { Crosshair, Dna, Fingerprint } from "lucide-react";
import { cn } from "@/utils/cn";
import { useTranslation } from "@/components/TranslationContext";
import type { Kind } from "./types";

type Variant = "primary" | "outline" | "ghost";

const variants: Record<Variant, string> = {
    primary: "bg-accent text-white hover:bg-accent-hover shadow-[0_6px_20px_-8px_var(--color-accent)]",
    outline: "border border-line text-ink hover:border-accent hover:text-accent",
    ghost: "text-muted hover:text-ink hover:bg-raised"
};

export function Button({ variant = "primary", className, children, ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
    return (
        <button
            type="button"
            className={cn("inline-flex items-center justify-center gap-2 rounded-md px-3.5 py-2 text-sm font-semibold transition-[background-color,color,border-color,transform] duration-150 active:scale-[.97] disabled:cursor-not-allowed disabled:opacity-50 cursor-pointer", variants[variant], className)}
            {...rest}
        >
            {children}
        </button>
    );
}

export const kindStyles: Record<Kind, { icon: typeof Dna; text: string; bg: string; border: string }> = {
    dna: { icon: Dna, text: "text-ok", bg: "bg-ok/10", border: "border-ok/40" },
    fingerprint: { icon: Fingerprint, text: "text-info", bg: "bg-info/10", border: "border-info/40" },
    ballistics: { icon: Crosshair, text: "text-warn", bg: "bg-warn/10", border: "border-warn/40" }
};

export function KindChip({ kind, className }: { kind: Kind; className?: string }) {
    const { t } = useTranslation();
    const style = kindStyles[kind];
    const Icon = style.icon;

    return (
        <span className={cn("inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wider", style.text, style.bg, style.border, className)}>
            <Icon size={12} strokeWidth={2.5} />
            {t(`lab.kinds.${kind}`)}
        </span>
    );
}

export function Label({ children, className }: { children: ReactNode; className?: string }) {
    return <span className={cn("th-label", className)}>{children}</span>;
}

export function Card({ children, className }: { children: ReactNode; className?: string }) {
    return <div className={cn("rounded-lg border border-line bg-surface", className)}>{children}</div>;
}

export function copyText(value: string) {
    const input = document.createElement("input");
    input.value = value;
    document.body.appendChild(input);
    input.select();
    document.execCommand("copy");
    document.body.removeChild(input);
}

export const formatDateTime = (millis: number | undefined, locales: string) => millis
    ? new Date(millis).toLocaleString(locales, { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit", hour12: false })
    : "-";

// "Blood", "Bullet"... or the item name for traces on other items, such as a weapon
export function useTypeLabel() {
    const { t } = useTranslation();

    return (evidenceType: string) => {
        const label = t(`lab.types.${evidenceType}`);
        return label.startsWith("lab.types.") ? evidenceType : label;
    };
}
