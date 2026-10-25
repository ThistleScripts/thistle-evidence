import { useCallback, useEffect, useState } from "react";
import { AlertTriangle, ClipboardPen, Dna, Fingerprint, Link2, NotebookPen, Plus, Search, Tag, Unlink, UserPlus, UserRound, X } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { useDebounce } from "@/hooks/useDebounce";
import type Citizen from "@/types/citizen.type";
import type { CitizenFlag } from "@/types/citizen.type";
import type Note from "@/types/note.type";
import { cn } from "@/utils/cn";
import { post } from "./bridge";
import { callServer, inGame } from "./server";
import { Button, Card, Label, formatDateTime } from "./ui";

type Biometric = "fingerprint" | "dna";

interface CarriedSample {
    inventory: number | string;
    slot: number;
    label: string;
    imagePath: string;
    identifier: string; // the fingerprint or DNA profile
}

interface ItemsResponse {
    inventory: number | string;
    label: string;
    items: { slot: number; label: string; imagePath: string; details: { identifier: string } }[];
}

const closeBooking = () => post("booking:close", {});

// The booking terminal in the police cells: find or create the suspect's citizen record, put the fingerprint and DNA
// swab taken from them on file, and add notes. Nothing else from the laptop (no analysis, wiretaps or firearms).
export default function BookingApp() {
    const { t, setLang } = useTranslation();
    const [visible, setVisible] = useState(!inGame && location.search.includes("booking"));
    const [officer, setOfficer] = useState("");
    const [brand, setBrand] = useState("Thistle Evidence");
    const [synced, setSynced] = useState(true);
    const [citizen, setCitizen] = useState<Citizen | null>(null);

    useEffect(() => {
        const onMessage = (event: MessageEvent) => {
            const data = event.data;

            if (data?.action === "openBooking") {
                if (data.language) setLang(data.language);
                setOfficer(data.playerName || "");
                if (data.brand) setBrand(data.brand);
                setSynced(data.citizensSynced !== false);
                setCitizen(null);
                setVisible(true);
            } else if (data?.action === "closeBooking") {
                setVisible(false);
            }
        };

        const onKeyDown = (event: KeyboardEvent) => {
            if (event.key === "Escape") closeBooking();
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
                            <ClipboardPen size={22} />
                        </div>
                        <div>
                            <p className="th-label text-accent">{brand}</p>
                            <h1 className="font-display text-xl font-black leading-tight">{t("booking.title")}</h1>
                        </div>
                    </div>

                    <div className="ml-auto flex items-center gap-4">
                        {officer && <p className="text-sm text-muted">{t("lab.officer", officer)}</p>}
                        <button type="button" title={t("lab.close")} onClick={closeBooking} className="cursor-pointer rounded-md border border-line p-2 text-muted transition-colors hover:border-accent hover:text-accent">
                            <X size={16} />
                        </button>
                    </div>
                </header>

                <main className="relative z-10 flex min-h-0 flex-1">
                    <CitizenFinder synced={synced} selected={citizen} onSelect={setCitizen} />
                    {citizen
                        ? <CitizenRecord key={citizen.identifier} citizen={citizen} onOpen={setCitizen} />
                        : <div className="flex flex-1 flex-col items-center justify-center gap-3 px-10 text-center text-muted">
                            <UserRound size={40} strokeWidth={1.25} className="opacity-50" />
                            <p className="text-sm">{t("booking.select")}</p>
                            <p className="max-w-md text-xs">{t("booking.hint")}</p>
                        </div>}
                </main>
            </div>
        </div>
    );
}

// Also used by the firearm registration terminal (FirearmTerminalApp.tsx)
export function CitizenFinder({ synced, selected, onSelect }: { synced: boolean; selected: Citizen | null; onSelect: (citizen: Citizen) => void }) {
    const { t } = useTranslation();
    const [searchText, setSearchText] = useState("");
    const debouncedSearchText = useDebounce(searchText, 400);
    const [citizens, setCitizens] = useState<Citizen[]>([]);
    const [loading, setLoading] = useState(false);
    const [creating, setCreating] = useState(false);

    useEffect(() => {
        setLoading(true);
        callServer<Citizen[]>("evidences:getCitizens", { searchText: debouncedSearchText.trim(), offset: 0 }).then(result => {
            setCitizens(result.success && Array.isArray(result.response) ? result.response : []);
            setLoading(false);
        });
    }, [debouncedSearchText]);

    return (
        <aside className="flex w-[360px] shrink-0 flex-col border-r border-line">
            <div className="space-y-3 px-5 pb-3 pt-5">
                <div className="flex items-center justify-between">
                    <Label>{t("booking.citizens")}</Label>
                    {!synced && (
                        <button type="button" onClick={() => setCreating(value => !value)} className="flex cursor-pointer items-center gap-1 text-xs text-muted transition-colors hover:text-accent">
                            <UserPlus size={13} />
                            {t("booking.new_citizen")}
                        </button>
                    )}
                </div>
                <div className="relative">
                    <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
                    <input className="th-input py-2 pl-9 pr-3 text-sm" placeholder={t("booking.search")} maxLength={25}
                        value={searchText} onChange={event => setSearchText(event.target.value)} />
                </div>
                {creating && <NewCitizen onCreated={citizen => { setCreating(false); setCitizens(list => [citizen, ...list.filter(other => other.identifier !== citizen.identifier)]); onSelect(citizen); }} />}
            </div>

            <ul className="th-scroll min-h-0 flex-1 space-y-1 overflow-y-auto px-3 pb-5">
                {!loading && citizens.length === 0 && (
                    <li className="mx-2 rounded-lg border border-dashed border-line p-4 text-center text-sm text-muted">
                        {synced ? t("booking.no_citizens") : t("booking.no_citizens_manual")}
                    </li>
                )}
                {citizens.map(citizen => (
                    <li key={citizen.identifier}>
                        <button type="button" onClick={() => onSelect(citizen)}
                            className={cn("flex w-full cursor-pointer items-center gap-3 rounded-lg border px-3 py-2 text-left transition-colors",
                                selected?.identifier === citizen.identifier ? "border-accent/60 bg-accent/10" : "border-transparent hover:bg-raised")}>
                            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-md bg-raised text-muted"><UserRound size={16} /></div>
                            <div className="min-w-0">
                                <p className="truncate text-sm font-medium">{citizen.fullName}</p>
                                <p className="truncate text-xs text-muted">{String(citizen.birthdate)}</p>
                            </div>
                        </button>
                    </li>
                ))}
            </ul>
        </aside>
    );
}

// Only when citizens aren't synced from the framework: officers create the records themselves
function NewCitizen({ onCreated }: { onCreated: (citizen: Citizen) => void }) {
    const { t } = useTranslation();
    const [fullName, setFullName] = useState("");
    const [birthdate, setBirthdate] = useState("");
    const [gender, setGender] = useState("male");
    const [saving, setSaving] = useState(false);

    const [nearby, setNearby] = useState<{ serverId: number; fullName: string }[]>([]);

    // the players standing near the officer: picking one makes the record from their character's real details
    useEffect(() => {
        callServer<{ serverId: number; fullName: string }[]>("evidences:getNearbyCharacters").then(result => {
            setNearby(result.success && Array.isArray(result.response) ? result.response : []);
        });
    }, []);

    const createFromPlayer = async (serverId: number) => {
        setSaving(true);
        const result = await callServer<Citizen>("evidences:storeCitizenFromPlayer", { serverId });
        setSaving(false);

        if (result.success && result.response) onCreated(result.response);
    };

    const create = async () => {
        if (!fullName.trim() || !birthdate.trim()) return;

        setSaving(true);
        const result = await callServer<Citizen>("evidences:storeCitizen", { fullName: fullName.trim(), birthdate: birthdate.trim(), gender });
        setSaving(false);

        if (result.success && result.response) onCreated(result.response);
    };

    return (
        <Card className="space-y-2 p-3">
            {nearby.length > 0 && (
                <div className="space-y-1.5 pb-1">
                    <p className="text-xs text-muted">{t("booking.nearby")}</p>
                    <div className="flex flex-wrap gap-1.5">
                        {nearby.map(player => (
                            <button key={player.serverId} type="button" disabled={saving} onClick={() => createFromPlayer(player.serverId)}
                                className="flex cursor-pointer items-center gap-1.5 rounded-md border border-line px-2 py-1 text-xs transition-colors hover:border-accent hover:text-accent disabled:cursor-not-allowed disabled:opacity-50">
                                <UserRound size={12} />
                                {player.fullName}
                            </button>
                        ))}
                    </div>
                    <p className="pt-1 text-[11px] text-muted">{t("booking.or_by_hand")}</p>
                </div>
            )}
            <input className="th-input px-3 py-2 text-sm" placeholder={t("booking.full_name")} maxLength={25} value={fullName} onChange={event => setFullName(event.target.value)} />
            <input className="th-input px-3 py-2 text-sm" placeholder={t("booking.birthdate")} maxLength={25} value={birthdate} onChange={event => setBirthdate(event.target.value)} />
            <div className="flex gap-1 rounded-lg border border-line bg-surface p-1">
                {["male", "female", "non_binary"].map(option => (
                    <button key={option} type="button" onClick={() => setGender(option)}
                        className={cn("flex-1 cursor-pointer rounded-md px-2 py-1 text-xs transition-colors", gender === option ? "bg-raised text-ink" : "text-muted hover:text-ink")}>
                        {t(`laptop.desktop_screen.citizens_app.gender.${option}`)}
                    </button>
                ))}
            </div>
            <Button className="w-full" disabled={saving || !fullName.trim() || !birthdate.trim()} onClick={create}>
                <UserPlus size={14} />
                {t("booking.create")}
            </Button>
        </Card>
    );
}

function CitizenRecord({ citizen, onOpen }: { citizen: Citizen; onOpen: (citizen: Citizen) => void }) {
    const { t } = useTranslation();

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

            <RecordDetails citizen={citizen} />
            <BiometricsOnFile citizen={citizen} onOpen={onOpen} />
            <Notes citizen={citizen} />
        </section>
    );
}

// The fingerprint and DNA profile on the citizen's record, put on file from samples the officer is carrying
function BiometricsOnFile({ citizen, onOpen }: { citizen: Citizen; onOpen: (citizen: Citizen) => void }) {
    const { t } = useTranslation();
    // a sample that's already on someone else's record, waiting for the officer to decide
    const [conflict, setConflict] = useState<{ type: Biometric; biometricData: string; owner: Citizen } | null>(null);
    const [onFile, setOnFile] = useState<{ fingerprint?: string; dna?: string }>({});
    const [samples, setSamples] = useState<Record<Biometric, CarriedSample[]>>({ fingerprint: [], dna: [] });
    const [busy, setBusy] = useState(false);
    const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

    const load = useCallback(async () => {
        const linked = await callServer<{ fingerprint?: string; dna?: string }>("evidences:getBiometricDataLinkedToIdentifier", { identifier: citizen.identifier });
        setOnFile(linked.success && linked.response ? linked.response : {});

        const carried: Record<Biometric, CarriedSample[]> = { fingerprint: [], dna: [] };
        for (const type of ["fingerprint", "dna"] as Biometric[]) {
            const result = await callServer<ItemsResponse[]>("evidences:getPlayersItemsWithEvidence", { type });
            const inventories = result.success && Array.isArray(result.response) ? result.response : [];
            carried[type] = inventories.flatMap(inventory => inventory.items.map(item => ({
                inventory: inventory.inventory,
                slot: item.slot,
                label: item.label,
                imagePath: item.imagePath,
                identifier: item.details.identifier
            })));
        }
        setSamples(carried);
    }, [citizen.identifier]);

    useEffect(() => { load(); }, [load]);

    const link = async (type: Biometric, biometricData?: string, move = false) => {
        setBusy(true);
        setConflict(null);
        const result = await callServer("evidences:linkBiometricDataToIdentifier", { type, identifier: citizen.identifier, biometricData, move }) as { success: boolean; conflict?: Citizen };
        setBusy(false);

        if (!result.success && result.conflict && biometricData) {
            setMessage(null);
            setConflict({ type, biometricData, owner: result.conflict });
            return;
        }

        setMessage(result.success
            ? { ok: true, text: t(biometricData ? "booking.linked" : "booking.unlinked", t(`laptop.desktop_screen.common.${type}`)) }
            : { ok: false, text: t("booking.link_error", t(`laptop.desktop_screen.common.${type}`)) });
        load();
    };

    return (
        <div className="space-y-2">
            <div className="flex items-center gap-2">
                <Label>{t("booking.biometrics")}</Label>
                {message && <span className={cn("text-xs", message.ok ? "text-ok" : "text-bad")}>{message.text}</span>}
            </div>

            {conflict && (
                <Card className="space-y-3 border-warn/50 bg-warn/5 p-4">
                    <div className="flex items-start gap-3">
                        <AlertTriangle size={18} className="mt-0.5 shrink-0 text-warn" />
                        <div className="text-sm">
                            <p className="font-semibold">{t("records.conflict.title", t(`laptop.desktop_screen.common.${conflict.type}`), conflict.owner.fullName)}</p>
                            <p className="text-xs text-muted">{t("records.conflict.hint", citizen.fullName)}</p>
                        </div>
                    </div>
                    <div className="flex flex-wrap justify-end gap-2">
                        <Button variant="ghost" disabled={busy} onClick={() => setConflict(null)}>{t("records.conflict.cancel")}</Button>
                        <Button variant="outline" disabled={busy} onClick={() => link(conflict.type, conflict.biometricData, true)}>{t("records.conflict.move")}</Button>
                        <Button variant="outline" disabled={busy} onClick={() => onOpen(conflict.owner)}>{t("records.conflict.open", conflict.owner.fullName)}</Button>
                        <Button disabled={busy} onClick={async () => {
                            setBusy(true);
                            await callServer("evidences:records:addAlias", { identifier: conflict.owner.identifier, alias: citizen.fullName });
                            setBusy(false);
                            onOpen(conflict.owner);
                        }}>
                            <Tag size={14} />
                            {t("records.conflict.alias", citizen.fullName, conflict.owner.fullName)}
                        </Button>
                    </div>
                </Card>
            )}

            <div className="grid grid-cols-2 gap-4">
                {(["fingerprint", "dna"] as Biometric[]).map(type => {
                    const Icon = type === "dna" ? Dna : Fingerprint;
                    const current = onFile[type];
                    const style = type === "dna" ? "text-ok bg-ok/10" : "text-info bg-info/10";

                    return (
                        <Card key={type} className="space-y-3 p-4">
                            <div className="flex items-center gap-3">
                                <div className={cn("flex h-9 w-9 items-center justify-center rounded-md", style)}><Icon size={18} /></div>
                                <div className="min-w-0 flex-1">
                                    <Label>{t(`laptop.desktop_screen.common.${type}`)}</Label>
                                    <p className={cn("truncate font-mono text-sm tracking-wider", !current && "text-muted")}>{current || t("booking.not_on_file")}</p>
                                </div>
                                {current && (
                                    <button type="button" title={t("booking.remove")} disabled={busy} onClick={() => link(type, undefined)}
                                        className="cursor-pointer rounded-md p-1.5 text-muted transition-colors hover:bg-raised hover:text-bad">
                                        <Unlink size={14} />
                                    </button>
                                )}
                            </div>

                            <div className="space-y-1">
                                <p className="text-xs text-muted">{t("booking.from_sample")}</p>
                                {samples[type].length === 0
                                    ? <p className="rounded-md border border-dashed border-line px-3 py-2 text-xs text-muted">{t(`booking.no_samples.${type}`)}</p>
                                    : samples[type].map(sample => (
                                        <div key={`${sample.inventory}-${sample.slot}`} className="flex items-center gap-2 rounded-md border border-line px-2 py-1.5">
                                            {sample.imagePath && <img src={sample.imagePath} className="h-7 w-7 shrink-0 object-contain" />}
                                            <div className="min-w-0 flex-1">
                                                <p className="truncate text-xs">{sample.label}</p>
                                                <p className="truncate font-mono text-xs text-muted">{sample.identifier}</p>
                                            </div>
                                            <Button variant="outline" className="px-2 py-1 text-xs" disabled={busy || sample.identifier === current} onClick={() => link(type, sample.identifier)}>
                                                <Link2 size={12} />
                                                {sample.identifier === current ? t("booking.on_file") : t("booking.put_on_file")}
                                            </Button>
                                        </div>
                                    ))}
                            </div>
                        </Card>
                    );
                })}
            </div>
        </div>
    );
}

interface Alias {
    id: number;
    alias: string;
    addedBy: string;
}

const flagStyles: Record<CitizenFlag["flag"], string> = {
    wanted: "border-bad/50 bg-bad/10 text-bad",
    armed: "border-bad/50 bg-bad/10 text-bad",
    bail: "border-warn/50 bg-warn/10 text-warn",
    warning: "border-warn/50 bg-warn/10 text-warn"
};

// Warnings on the record (shown with any fingerprint or lab match) and other names the person has given
function RecordDetails({ citizen }: { citizen: Citizen }) {
    const { t } = useTranslation();
    const [flags, setFlags] = useState<CitizenFlag[]>([]);
    const [aliases, setAliases] = useState<Alias[]>([]);
    const [flag, setFlag] = useState<CitizenFlag["flag"]>("wanted");
    const [note, setNote] = useState("");
    const [alias, setAlias] = useState("");
    const [busy, setBusy] = useState(false);

    const load = useCallback(async () => {
        const result = await callServer<{ flags: CitizenFlag[]; aliases: Alias[] }>("evidences:records:get", { identifier: citizen.identifier });
        setFlags(result.success && result.response ? result.response.flags : []);
        setAliases(result.success && result.response ? result.response.aliases : []);
    }, [citizen.identifier]);

    useEffect(() => { load(); }, [load]);

    const run = async (name: string, args: object) => {
        setBusy(true);
        await callServer(name, args);
        setBusy(false);
        load();
    };

    return (
        <div className="grid grid-cols-2 gap-4">
            <Card className="space-y-3 p-4">
                <Label>{t("records.flags_title")}</Label>
                {flags.length === 0
                    ? <p className="text-xs text-muted">{t("records.no_flags")}</p>
                    : <div className="flex flex-wrap gap-1.5">
                        {flags.map(entry => (
                            <span key={entry.id} title={t("records.added_by", entry.addedBy)}
                                className={cn("inline-flex items-center gap-1.5 rounded-md border px-2 py-1 text-xs font-semibold", flagStyles[entry.flag])}>
                                <AlertTriangle size={12} />
                                {t(`records.flags.${entry.flag}`)}{entry.note ? `: ${entry.note}` : ""}
                                <button type="button" disabled={busy} title={t("booking.remove")} onClick={() => run("evidences:records:removeFlag", { id: entry.id })}
                                    className="cursor-pointer opacity-60 hover:opacity-100"><X size={12} /></button>
                            </span>
                        ))}
                    </div>}
                <div className="flex gap-1.5">
                    <select className="th-input w-auto px-2 py-1.5 text-xs" value={flag} onChange={event => setFlag(event.target.value as CitizenFlag["flag"])}>
                        {(["wanted", "armed", "bail", "warning"] as const).map(option => <option key={option} value={option}>{t(`records.flags.${option}`)}</option>)}
                    </select>
                    <input className="th-input min-w-0 flex-1 px-2 py-1.5 text-xs" maxLength={250} placeholder={t("records.flag_note")} value={note} onChange={event => setNote(event.target.value)} />
                    <Button className="px-2.5 py-1.5 text-xs" disabled={busy || (flag === "warning" && !note.trim())}
                        onClick={() => { run("evidences:records:addFlag", { identifier: citizen.identifier, flag, note: note.trim() }); setNote(""); }}>
                        <Plus size={12} />
                    </Button>
                </div>
            </Card>

            <Card className="space-y-3 p-4">
                <Label>{t("records.aliases_title")}</Label>
                {aliases.length === 0
                    ? <p className="text-xs text-muted">{t("records.no_aliases")}</p>
                    : <div className="flex flex-wrap gap-1.5">
                        {aliases.map(entry => (
                            <span key={entry.id} title={t("records.added_by", entry.addedBy)}
                                className="inline-flex items-center gap-1.5 rounded-md border border-line px-2 py-1 text-xs">
                                <Tag size={12} className="text-muted" />
                                {entry.alias}
                                <button type="button" disabled={busy} title={t("booking.remove")} onClick={() => run("evidences:records:removeAlias", { id: entry.id })}
                                    className="cursor-pointer text-muted hover:text-bad"><X size={12} /></button>
                            </span>
                        ))}
                    </div>}
                <div className="flex gap-1.5">
                    <input className="th-input min-w-0 flex-1 px-2 py-1.5 text-xs" maxLength={100} placeholder={t("records.alias_placeholder")} value={alias} onChange={event => setAlias(event.target.value)} />
                    <Button className="px-2.5 py-1.5 text-xs" disabled={busy || !alias.trim()}
                        onClick={() => { run("evidences:records:addAlias", { identifier: citizen.identifier, alias: alias.trim() }); setAlias(""); }}>
                        <Plus size={12} />
                    </Button>
                </div>
            </Card>
        </div>
    );
}

function Notes({ citizen }: { citizen: Citizen }) {
    const { t } = useTranslation();
    const [notes, setNotes] = useState<Note[]>([]);
    const [title, setTitle] = useState("");
    const [text, setText] = useState("");
    const [saving, setSaving] = useState(false);
    const locales = t("laptop.desktop_screen.common.date_locales");

    const load = useCallback(async () => {
        const result = await callServer<Note[]>("evidences:getNotes", { identifier: citizen.identifier, offset: 0 });
        setNotes(result.success && Array.isArray(result.response) ? result.response : []);
    }, [citizen.identifier]);

    useEffect(() => { load(); }, [load]);

    const add = async () => {
        if (!title.trim()) return;

        setSaving(true);
        const result = await callServer("evidences:storeNote", { identifier: citizen.identifier, title: title.trim(), text: text.trim() });
        setSaving(false);

        if (result.success) {
            setTitle("");
            setText("");
            load();
        }
    };

    return (
        <div className="space-y-2">
            <Label>{t("booking.notes")}</Label>
            <Card className="space-y-2 p-4">
                <div className="flex items-center gap-2">
                    <NotebookPen size={14} className="shrink-0 text-accent" />
                    <input className="th-input px-3 py-2 text-sm" placeholder={t("booking.note_title")} maxLength={50} value={title} onChange={event => setTitle(event.target.value)} />
                </div>
                <textarea className="th-input th-scroll h-20 resize-none px-3 py-2 text-sm" placeholder={t("booking.note_text")} maxLength={1000} value={text} onChange={event => setText(event.target.value)} />
                <div className="flex justify-end">
                    <Button disabled={saving || !title.trim()} onClick={add}>
                        <Plus size={14} />
                        {t("booking.add_note")}
                    </Button>
                </div>
            </Card>

            {notes.map(note => (
                <Card key={note.id} className="px-4 py-3">
                    <div className="flex items-baseline justify-between gap-3">
                        <p className="truncate font-medium">{note.title}</p>
                        <p className="shrink-0 text-xs text-muted">{formatDateTime(note.modifiedAt, locales)} · {note.modifiedBy}</p>
                    </div>
                    {note.text && <p className="mt-1 whitespace-pre-wrap text-sm text-muted">{note.text}</p>}
                </Card>
            ))}
        </div>
    );
}
