import { useCallback, useEffect, useState } from "react";
import { Crosshair, ShieldCheck, UserRound, X } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import type Citizen from "@/types/citizen.type";
import { cn } from "@/utils/cn";
import { CitizenFinder } from "./BookingApp";
import { post } from "./bridge";
import { callServer, inGame } from "./server";
import { Button, Card, Label, formatDateTime } from "./ui";

interface CarriedFirearm {
    serial: string;
    label: string;
    imagePath: string;
    registeredTo?: string; // the citizen it's already on the registry under
    status?: string;
}

interface RegisteredFirearm {
    serial: string;
    label: string;
    imagePath: string;
    status: string;
    reason: string;
    registeredBy: string;
    registeredAt: number;
}

const closeTerminal = () => post("firearmTerminal:close", {});

// The firearm registration terminal (config.firearmTerminals): find the citizen, or create their record when
// citizens aren't synced, then register a gun the officer is carrying to them. Nothing else from the laptop.
export default function FirearmTerminalApp() {
    const { t, setLang } = useTranslation();
    const [visible, setVisible] = useState(!inGame && location.search.includes("firearms"));
    const [officer, setOfficer] = useState("");
    const [brand, setBrand] = useState("Thistle Evidence");
    const [synced, setSynced] = useState(true);
    const [citizen, setCitizen] = useState<Citizen | null>(null);

    useEffect(() => {
        const onMessage = (event: MessageEvent) => {
            const data = event.data;

            if (data?.action === "openFirearmTerminal") {
                if (data.language) setLang(data.language);
                setOfficer(data.playerName || "");
                if (data.brand) setBrand(data.brand);
                setSynced(data.citizensSynced !== false);
                setCitizen(null);
                setVisible(true);
            } else if (data?.action === "closeFirearmTerminal") {
                setVisible(false);
            }
        };

        const onKeyDown = (event: KeyboardEvent) => {
            if (event.key === "Escape") closeTerminal();
        };

        window.addEventListener("message", onMessage);
        window.addEventListener("keydown", onKeyDown);
        return () => {
            window.removeEventListener("message", onMessage);
            window.removeEventListener("keydown", onKeyDown);
        };
    }, []);

    if (!visible) return null;

    return (
        <div className={cn("flex h-full w-full items-center justify-center p-8", !inGame && "bg-[#2a2f3a]")}>
            <div className="th-panel th-grain animate-th-rise relative flex h-[min(780px,100%)] w-[min(1240px,100%)] flex-col overflow-hidden rounded-xl border border-line">
                <header className="relative z-10 flex items-center gap-6 border-b border-line px-6 py-4">
                    <div className="flex items-center gap-3">
                        <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-accent/15 text-accent">
                            <Crosshair size={22} />
                        </div>
                        <div>
                            <p className="th-label text-accent">{brand}</p>
                            <h1 className="font-display text-xl font-black leading-tight">{t("firearm_terminal.title")}</h1>
                        </div>
                    </div>

                    <div className="ml-auto flex items-center gap-4">
                        {officer && <p className="text-sm text-muted">{t("lab.officer", officer)}</p>}
                        <button type="button" title={t("lab.close")} onClick={closeTerminal} className="cursor-pointer rounded-md border border-line p-2 text-muted transition-colors hover:border-accent hover:text-accent">
                            <X size={16} />
                        </button>
                    </div>
                </header>

                <main className="relative z-10 flex min-h-0 flex-1">
                    <CitizenFinder synced={synced} selected={citizen} onSelect={setCitizen} />
                    {citizen
                        ? <CitizenFirearms key={citizen.identifier} citizen={citizen} />
                        : <div className="flex flex-1 flex-col items-center justify-center gap-3 px-10 text-center text-muted">
                            <UserRound size={40} strokeWidth={1.25} className="opacity-50" />
                            <p className="text-sm">{t("firearm_terminal.select")}</p>
                            <p className="max-w-md text-xs">{synced ? t("firearm_terminal.hint") : t("firearm_terminal.hint_manual")}</p>
                        </div>}
                </main>
            </div>
        </div>
    );
}

function CitizenFirearms({ citizen }: { citizen: Citizen }) {
    const { t } = useTranslation();
    const locales = t("laptop.desktop_screen.common.date_locales");
    const [registered, setRegistered] = useState<RegisteredFirearm[]>([]);
    const [carried, setCarried] = useState<CarriedFirearm[]>([]);
    const [selected, setSelected] = useState<string | null>(null);
    const [reason, setReason] = useState("");
    const [busy, setBusy] = useState(false);
    const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

    const load = useCallback(async () => {
        const [onRecord, onOfficer] = await Promise.all([
            callServer<RegisteredFirearm[]>("evidences:firearmTerminal:getRegistered", { identifier: citizen.identifier }),
            callServer<CarriedFirearm[]>("evidences:firearmTerminal:getCarried")
        ]);
        setRegistered(onRecord.success && Array.isArray(onRecord.response) ? onRecord.response : []);
        setCarried(onOfficer.success && Array.isArray(onOfficer.response) ? onOfficer.response : []);
    }, [citizen.identifier]);

    useEffect(() => { load(); }, [load]);

    const register = async () => {
        if (!selected) return;

        setBusy(true);
        setMessage(null);
        const result = await callServer("evidences:firearmTerminal:register", { serial: selected, identifier: citizen.identifier, reason: reason.trim() });
        setBusy(false);

        if (result.success) {
            setMessage({ ok: true, text: t("firearm_terminal.registered", citizen.fullName) });
            setSelected(null);
            setReason("");
            load();
        } else {
            const key = typeof result.response === "string" ? result.response : "firearm_terminal.errors.failed";
            setMessage({ ok: false, text: t(key.startsWith("firearm_terminal.") ? key : "firearm_terminal.errors.failed") });
        }
    };

    const statusLabel = (status: string) => t(`laptop.desktop_screen.firearms_registry_app.status.${status}`);

    return (
        <section className="th-scroll flex min-w-0 flex-1 flex-col gap-5 overflow-y-auto p-6">
            <Card className="flex items-center gap-4 px-5 py-4">
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-accent/10 text-accent"><UserRound size={24} /></div>
                <div className="min-w-0 flex-1">
                    <p className="truncate font-display text-xl font-bold">{citizen.fullName}</p>
                    <p className="text-sm text-muted">
                        {String(citizen.birthdate)} · {t(`laptop.desktop_screen.citizens_app.gender.${citizen.gender}`)}
                    </p>
                </div>
            </Card>

            <div className="space-y-2">
                <Label>{t("firearm_terminal.on_record")}</Label>
                {registered.length === 0
                    ? <p className="rounded-lg border border-dashed border-line p-4 text-center text-sm text-muted">{t("firearm_terminal.none_on_record")}</p>
                    : <Card className="divide-y divide-line">
                        {registered.map(firearm => (
                            <div key={firearm.serial} className="flex items-center gap-4 px-4 py-3">
                                <img src={firearm.imagePath} alt="" className="h-10 w-10 shrink-0 object-contain" />
                                <div className="min-w-0 flex-1">
                                    <p className="truncate text-sm font-semibold">{firearm.label}</p>
                                    <p className="truncate font-mono text-xs text-muted">{firearm.serial}</p>
                                </div>
                                <div className="shrink-0 text-right text-xs text-muted">
                                    <p className="font-semibold text-ink">{statusLabel(firearm.status)}</p>
                                    <p>{firearm.registeredBy} · {formatDateTime(firearm.registeredAt, locales)}</p>
                                </div>
                            </div>
                        ))}
                    </Card>}
            </div>

            <div className="space-y-2">
                <Label>{t("firearm_terminal.register")}</Label>
                {carried.length === 0
                    ? <p className="rounded-lg border border-dashed border-line p-4 text-center text-sm text-muted">{t("firearm_terminal.none_carried")}</p>
                    : <div className="grid grid-cols-2 gap-2">
                        {carried.map(firearm => {
                            const takenByOther = !!firearm.registeredTo && firearm.registeredTo !== citizen.identifier;
                            const alreadyTheirs = firearm.registeredTo === citizen.identifier;
                            const disabled = takenByOther || alreadyTheirs;

                            return (
                                <button key={firearm.serial} type="button" disabled={disabled} onClick={() => setSelected(firearm.serial)}
                                    className={cn("flex items-center gap-3 rounded-lg border px-3 py-2 text-left transition-colors",
                                        disabled ? "cursor-not-allowed border-line opacity-50"
                                            : selected === firearm.serial ? "cursor-pointer border-accent/60 bg-accent/10" : "cursor-pointer border-line hover:bg-raised")}>
                                    <img src={firearm.imagePath} alt="" className="h-10 w-10 shrink-0 object-contain" />
                                    <div className="min-w-0">
                                        <p className="truncate text-sm font-semibold">{firearm.label}</p>
                                        <p className="truncate font-mono text-xs text-muted">{firearm.serial}</p>
                                        {alreadyTheirs && <p className="text-xs text-ok">{t("firearm_terminal.already_theirs")}</p>}
                                        {takenByOther && <p className="text-xs text-warn">{t("firearm_terminal.registered_elsewhere")}</p>}
                                    </div>
                                </button>
                            );
                        })}
                    </div>}

                {carried.length > 0 && (
                    <div className="space-y-2 pt-1">
                        <textarea className="th-input min-h-[70px] resize-none px-3 py-2 text-sm" maxLength={500}
                            placeholder={t("firearm_terminal.reason")} value={reason} onChange={event => setReason(event.target.value)} />
                        <div className="flex items-center gap-3">
                            {message && <p className={cn("text-sm", message.ok ? "text-ok" : "text-bad")}>{message.text}</p>}
                            <Button className="ml-auto" disabled={busy || !selected} onClick={register}>
                                <ShieldCheck size={14} />
                                {t("firearm_terminal.register_button")}
                            </Button>
                        </div>
                    </div>
                )}
                {carried.length === 0 && message && <p className={cn("text-sm", message.ok ? "text-ok" : "text-bad")}>{message.text}</p>}
            </div>
        </section>
    );
}
