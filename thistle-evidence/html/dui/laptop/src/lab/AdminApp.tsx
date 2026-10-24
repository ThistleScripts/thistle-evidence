import { useEffect, useMemo, useState, type ReactNode } from "react";
import { Check, Eraser, Laptop, Microscope, RefreshCw, Search, ShieldCheck, ShieldOff, Trash2, UserPlus, UserRound, Users, Wrench, X } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { cn } from "@/utils/cn";
import { post } from "./bridge";
import { callServer, inGame } from "./server";
import { Button, Label, formatDateTime } from "./ui";

interface Capability {
    key: string;
    group: "laptop" | "lab" | "field" | "equipment";
    needs?: string;
}

type Capabilities = Record<string, boolean>;

interface Officer {
    identifier: string;
    name: string;
    capabilities: Capabilities; // only what's set for them; the rest follows everyone's
    updatedBy?: string;
    updatedAt?: number;
}

interface OnlineOfficer {
    identifier: string;
    name: string;
    serverId: number;
}

interface AdminData {
    enabled: boolean;
    capabilities: Capability[];
    defaults: Capabilities;
    officers: Officer[];
    online: OnlineOfficer[];
}

const EVERYONE = "*";
const GROUND = "#ground"; // the world evidence page, not an officer

const groupIcons = { laptop: Laptop, lab: Microscope, field: Search, equipment: Wrench };

const closeAdmin = () => post("admin:close", {});

// The evidence admin panel (/evidenceadmin): what everyone can do, and which officers can do more or less than that.
// Officers still need the job and grade from config.lua; this decides the parts of the script on top of it.
export default function AdminApp() {
    const { t, setLang } = useTranslation();
    const [visible, setVisible] = useState(!inGame && location.search.includes("admin"));
    const [brand, setBrand] = useState("Thistle Evidence");
    const [data, setData] = useState<AdminData | null>(null);
    const [selected, setSelected] = useState<string>(EVERYONE);
    const [adding, setAdding] = useState<OnlineOfficer | null>(null);

    const load = () => callServer<AdminData>("evidences:admin:get").then(result => {
        if (result.success && result.response) setData(result.response);
    });

    useEffect(() => {
        const onMessage = (event: MessageEvent) => {
            const message = event.data;

            if (message?.action === "openAdmin") {
                if (message.language) setLang(message.language);
                if (message.brand) setBrand(message.brand);
                setSelected(EVERYONE);
                setAdding(null);
                setData(null);
                setVisible(true);
                load();
            } else if (message?.action === "closeAdmin") {
                setVisible(false);
            }
        };

        const onKeyDown = (event: KeyboardEvent) => {
            if (event.key === "Escape") closeAdmin();
        };

        window.addEventListener("message", onMessage);
        window.addEventListener("keydown", onKeyDown);
        if (!inGame && location.search.includes("admin")) load();

        return () => {
            window.removeEventListener("message", onMessage);
            window.removeEventListener("keydown", onKeyDown);
        };
    }, []);

    if (!visible) return null;

    const officer = data?.officers.find(entry => entry.identifier === selected);
    const subject: Officer | null = selected === EVERYONE
        ? { identifier: EVERYONE, name: t("admin.everyone"), capabilities: data?.defaults ?? {} }
        : officer ?? (adding && adding.identifier === selected ? { identifier: adding.identifier, name: adding.name, capabilities: {} } : null);

    return (
        <div className={cn("flex h-full w-full items-center justify-center p-8", !inGame && "bg-[#2a2f3a]")}>
            <div className="th-panel th-grain animate-th-rise relative flex h-[min(820px,100%)] w-[min(1240px,100%)] flex-col overflow-hidden rounded-xl border border-line">
                <header className="relative z-10 flex items-center gap-6 border-b border-line px-6 py-4">
                    <div className="flex items-center gap-3">
                        <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-accent/15 text-accent">
                            <ShieldCheck size={22} />
                        </div>
                        <div>
                            <p className="th-label text-accent">{brand}</p>
                            <h1 className="font-display text-xl font-black leading-tight">{t("admin.title")}</h1>
                        </div>
                    </div>

                    <button type="button" title={t("lab.close")} onClick={closeAdmin} className="ml-auto cursor-pointer rounded-md border border-line p-2 text-muted transition-colors hover:border-accent hover:text-accent">
                        <X size={16} />
                    </button>
                </header>

                {data && !data.enabled && (
                    <div className="relative z-10 flex items-center gap-2 border-b border-warn/30 bg-warn/10 px-6 py-2.5 text-sm text-warn">
                        <ShieldOff size={15} />
                        {t("admin.disabled")}
                    </div>
                )}

                <main className="relative z-10 flex min-h-0 flex-1">
                    {data
                        ? <>
                            <OfficerList data={data} selected={selected} onSelect={identifier => { setSelected(identifier); setAdding(null); }}
                                onAdd={online => { setAdding(online); setSelected(online.identifier); }} adding={adding} />
                            {selected === GROUND
                                ? <GroundEvidence />
                                : subject
                                ? <CapabilityEditor key={subject.identifier} data={data} subject={subject} isNew={!officer && subject.identifier !== EVERYONE}
                                    onSaved={identifier => { setAdding(null); load().then(() => setSelected(identifier)); }}
                                    onRemoved={() => { setSelected(EVERYONE); load(); }} />
                                : <div className="flex flex-1 items-center justify-center text-sm text-muted">{t("admin.select")}</div>}
                        </>
                        : <div className="flex flex-1 items-center justify-center text-sm text-muted">{t("admin.loading")}</div>}
                </main>
            </div>
        </div>
    );
}

function OfficerList({ data, selected, adding, onSelect, onAdd }: {
    data: AdminData;
    selected: string;
    adding: OnlineOfficer | null;
    onSelect: (identifier: string) => void;
    onAdd: (officer: OnlineOfficer) => void;
}) {
    const { t } = useTranslation();
    const [searchText, setSearchText] = useState("");
    const search = searchText.trim().toLowerCase();

    const officers = data.officers.filter(officer => !search || officer.name.toLowerCase().includes(search) || officer.identifier.toLowerCase().includes(search));
    const configured = new Set(data.officers.map(officer => officer.identifier));
    const online = data.online.filter(officer => !configured.has(officer.identifier) && officer.identifier !== adding?.identifier && (!search || officer.name.toLowerCase().includes(search)));

    return (
        <aside className="flex w-[340px] shrink-0 flex-col border-r border-line">
            <div className="px-5 pb-3 pt-5">
                <div className="relative">
                    <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
                    <input className="th-input py-2 pl-9 pr-3 text-sm" placeholder={t("admin.search")} maxLength={40}
                        value={searchText} onChange={event => setSearchText(event.target.value)} />
                </div>
            </div>

            <div className="th-scroll min-h-0 flex-1 space-y-5 overflow-y-auto px-3 pb-5">
                <div className="space-y-1">
                    <ListRow active={selected === EVERYONE} onClick={() => onSelect(EVERYONE)} icon={<Users size={16} />}
                        title={t("admin.everyone")} subtitle={t("admin.everyone_hint")} />
                    <ListRow active={selected === GROUND} onClick={() => onSelect(GROUND)} icon={<Eraser size={16} />}
                        title={t("admin.ground.title")} subtitle={t("admin.ground.hint")} />
                </div>

                <div className="space-y-1">
                    <Label className="px-2">{t("admin.officers")}</Label>
                    {adding && !configured.has(adding.identifier) && (
                        <ListRow active={selected === adding.identifier} onClick={() => onSelect(adding.identifier)} icon={<UserRound size={16} />}
                            title={adding.name} subtitle={t("admin.not_saved")} />
                    )}
                    {officers.length === 0 && !adding && <p className="px-2 py-1 text-xs text-muted">{t("admin.no_officers")}</p>}
                    {officers.map(officer => {
                        const overrides = Object.keys(officer.capabilities).length;
                        return <ListRow key={officer.identifier} active={selected === officer.identifier} onClick={() => onSelect(officer.identifier)}
                            icon={<UserRound size={16} />} title={officer.name}
                            subtitle={overrides ? t("admin.overrides", String(overrides)) : t("admin.follows_everyone")} />;
                    })}
                </div>

                <div className="space-y-1">
                    <Label className="px-2">{t("admin.online")}</Label>
                    {online.length === 0 && <p className="px-2 py-1 text-xs text-muted">{t("admin.no_online")}</p>}
                    {online.map(officer => (
                        <button key={officer.identifier} type="button" onClick={() => onAdd(officer)}
                            className="group flex w-full cursor-pointer items-center gap-3 rounded-md px-2 py-2 text-left transition-colors hover:bg-raised">
                            <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md border border-line text-muted group-hover:border-accent group-hover:text-accent">
                                <UserPlus size={14} />
                            </span>
                            <span className="min-w-0">
                                <span className="block truncate text-sm">{officer.name}</span>
                                <span className="block truncate text-xs text-muted">{t("admin.server_id", String(officer.serverId))}</span>
                            </span>
                        </button>
                    ))}
                </div>
            </div>
        </aside>
    );
}

function ListRow({ active, onClick, icon, title, subtitle }: { active: boolean; onClick: () => void; icon: ReactNode; title: string; subtitle: string }) {
    return (
        <button type="button" onClick={onClick}
            className={cn("flex w-full cursor-pointer items-center gap-3 rounded-md px-2 py-2 text-left transition-colors",
                active ? "bg-accent/15 text-ink" : "hover:bg-raised")}>
            <span className={cn("flex h-8 w-8 shrink-0 items-center justify-center rounded-md border", active ? "border-accent/60 text-accent" : "border-line text-muted")}>
                {icon}
            </span>
            <span className="min-w-0">
                <span className="block truncate text-sm font-semibold">{title}</span>
                <span className="block truncate text-xs text-muted">{subtitle}</span>
            </span>
        </button>
    );
}

type Choice = "default" | "allow" | "deny";

function CapabilityEditor({ data, subject, isNew, onSaved, onRemoved }: {
    data: AdminData;
    subject: Officer;
    isNew: boolean;
    onSaved: (identifier: string) => void;
    onRemoved: () => void;
}) {
    const { t } = useTranslation();
    const locales = t("laptop.desktop_screen.common.date_locales");
    const isEveryone = subject.identifier === EVERYONE;
    const [values, setValues] = useState<Capabilities>(subject.capabilities);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState(false);

    const dirty = isNew || JSON.stringify(values) !== JSON.stringify(subject.capabilities);

    // what the officer ends up with, as the server works it out
    const resolved = useMemo(() => {
        const result: Capabilities = {};
        for (const capability of data.capabilities) {
            result[capability.key] = values[capability.key] ?? data.defaults[capability.key] ?? false;
        }
        for (const capability of data.capabilities) {
            if (capability.needs && !result[capability.needs]) result[capability.key] = false;
        }
        return result;
    }, [values, data]);

    const groups = (["laptop", "lab", "field", "equipment"] as const).map(group => ({
        group,
        capabilities: data.capabilities.filter(capability => capability.group === group)
    }));

    const choose = (key: string, choice: Choice) => setValues(previous => {
        const next = { ...previous };
        if (choice === "default") delete next[key];
        else next[key] = choice === "allow";
        return next;
    });

    const save = () => {
        setSaving(true);
        setError(false);
        callServer("evidences:admin:save", { identifier: subject.identifier, name: subject.name, capabilities: values }).then(result => {
            setSaving(false);
            if (result.success) onSaved(subject.identifier);
            else setError(true);
        });
    };

    const remove = () => {
        callServer("evidences:admin:remove", { identifier: subject.identifier }).then(result => {
            if (result.success) onRemoved();
            else setError(true);
        });
    };

    return (
        <section className="flex min-w-0 flex-1 flex-col">
            <div className="flex items-start gap-4 border-b border-line px-7 py-5">
                <div className="min-w-0">
                    <h2 className="font-display truncate text-2xl font-black">{subject.name}</h2>
                    <p className="mt-1 text-xs text-muted">
                        {isEveryone ? t("admin.everyone_description") : subject.identifier}
                        {!isEveryone && subject.updatedBy && ` · ${t("admin.updated_by", subject.updatedBy, formatDateTime(subject.updatedAt, locales))}`}
                    </p>
                </div>

                <div className="ml-auto flex shrink-0 items-center gap-2">
                    {!isEveryone && !isNew && (
                        <Button variant="ghost" onClick={remove} title={t("admin.remove_hint")}>
                            <Trash2 size={14} />
                            {t("admin.remove")}
                        </Button>
                    )}
                    <Button onClick={save} disabled={!dirty || saving}>
                        <Check size={14} />
                        {isNew ? t("admin.add") : t("admin.save")}
                    </Button>
                </div>
            </div>

            {error && <p className="border-b border-bad/30 bg-bad/10 px-7 py-2 text-sm text-bad">{t("admin.error")}</p>}

            <div className="th-scroll min-h-0 flex-1 space-y-6 overflow-y-auto px-7 py-6">
                {groups.map(({ group, capabilities }) => {
                    const Icon = groupIcons[group];
                    return (
                        <div key={group}>
                            <div className="mb-2 flex items-center gap-2 text-accent">
                                <Icon size={15} />
                                <Label className="text-accent">{t(`admin.groups.${group}`)}</Label>
                            </div>

                            <div className="divide-y divide-line rounded-lg border border-line bg-surface">
                                {capabilities.map(capability => {
                                    const value = values[capability.key];
                                    const choice: Choice = value === undefined ? "default" : value ? "allow" : "deny";
                                    const blocked = !!capability.needs && !resolved[capability.needs];

                                    return (
                                        <div key={capability.key} className={cn("flex items-center gap-4 px-4 py-3", capability.needs && "pl-9")}>
                                            <div className="min-w-0 flex-1">
                                                <p className="text-sm font-semibold">{t(`admin.capabilities.${capability.key}.label`)}</p>
                                                <p className="text-xs text-muted">
                                                    {blocked ? t("admin.needs_laptop") : t(`admin.capabilities.${capability.key}.description`)}
                                                </p>
                                            </div>

                                            {isEveryone
                                                ? <Segmented value={value ? "allow" : "deny"} options={["allow", "deny"]} onChange={choice => choose(capability.key, choice)} />
                                                : <Segmented value={choice} options={["default", "allow", "deny"]} onChange={choice => choose(capability.key, choice)}
                                                    defaultLabel={t(data.defaults[capability.key] ? "admin.default_allowed" : "admin.default_denied")} />}
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    );
                })}
            </div>
        </section>
    );
}

function Segmented({ value, options, onChange, defaultLabel }: { value: Choice; options: Choice[]; onChange: (choice: Choice) => void; defaultLabel?: string }) {
    const { t } = useTranslation();

    const styles: Record<Choice, string> = {
        default: "bg-raised text-ink",
        allow: "bg-ok/20 text-ok",
        deny: "bg-bad/20 text-bad"
    };

    return (
        <div className="flex shrink-0 rounded-md border border-line p-0.5">
            {options.map(option => (
                <button key={option} type="button" onClick={() => onChange(option)}
                    className={cn("cursor-pointer rounded px-3 py-1 text-xs font-semibold transition-colors",
                        value === option ? styles[option] : "text-muted hover:text-ink")}>
                    {option === "default" ? defaultLabel : t(`admin.${option}`)}
                </button>
            ))}
        </div>
    );
}

interface GroundData {
    types: string[];
    counts: Record<string, number>;
}

// Ground evidence on the whole map, by type, and clearing it: one type, or everything. Each clear asks to confirm.
// Evidence on vehicles, props and players, and evidence already collected into items, isn't touched.
function GroundEvidence() {
    const { t } = useTranslation();
    const [data, setData] = useState<GroundData | null>(null);
    const [confirming, setConfirming] = useState<string | null>(null); // a type, or "*" for everything
    const [busy, setBusy] = useState(false);
    const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

    const load = () => callServer<GroundData>("evidences:admin:getGroundEvidence").then(result => {
        if (result.success && result.response) setData(result.response);
    });

    useEffect(() => { load(); }, []);

    const label = (type: string) => {
        const text = t(`lab.types.${type}`);
        return text.startsWith("lab.types.") ? type : text;
    };

    const clear = (type: string) => {
        setBusy(true);
        setMessage(null);
        callServer<number>("evidences:admin:clearGroundEvidence", type === EVERYONE ? {} : { evidenceType: type }).then(result => {
            setBusy(false);
            setConfirming(null);
            setMessage(result.success
                ? { ok: true, text: t("admin.ground.cleared", String(result.response ?? 0), type === EVERYONE ? t("admin.ground.all_types") : label(type)) }
                : { ok: false, text: t("admin.ground.error") });
            load();
        });
    };

    const total = data ? Object.values(data.counts).reduce((sum, count) => sum + count, 0) : 0;

    const ClearButton = ({ type, count }: { type: string; count: number }) => confirming === type
        ? <div className="flex shrink-0 items-center gap-2">
            <Button variant="ghost" onClick={() => setConfirming(null)} disabled={busy}>{t("admin.ground.cancel")}</Button>
            <Button className="bg-bad hover:bg-bad/80" onClick={() => clear(type)} disabled={busy}>
                <Trash2 size={14} />
                {t("admin.ground.confirm", String(count))}
            </Button>
        </div>
        : <Button variant="outline" onClick={() => setConfirming(type)} disabled={busy || count === 0}>
            <Trash2 size={14} />
            {t(type === EVERYONE ? "admin.ground.clear_all" : "admin.ground.clear")}
        </Button>;

    return (
        <section className="flex min-w-0 flex-1 flex-col">
            <div className="flex items-start gap-4 border-b border-line px-7 py-5">
                <div className="min-w-0">
                    <h2 className="font-display truncate text-2xl font-black">{t("admin.ground.title")}</h2>
                    <p className="mt-1 text-xs text-muted">{t("admin.ground.description")}</p>
                </div>
                <div className="ml-auto flex shrink-0 items-center gap-2">
                    <Button variant="ghost" onClick={() => { setMessage(null); load(); }} title={t("admin.ground.refresh")}>
                        <RefreshCw size={14} />
                    </Button>
                    {data && <ClearButton type={EVERYONE} count={total} />}
                </div>
            </div>

            {message && <p className={cn("border-b px-7 py-2 text-sm", message.ok ? "border-ok/30 bg-ok/10 text-ok" : "border-bad/30 bg-bad/10 text-bad")}>{message.text}</p>}

            <div className="th-scroll min-h-0 flex-1 overflow-y-auto px-7 py-6">
                {!data
                    ? <p className="text-sm text-muted">{t("admin.loading")}</p>
                    : <div className="divide-y divide-line rounded-lg border border-line bg-surface">
                        {data.types.map(type => {
                            const count = data.counts[type] ?? 0;
                            return (
                                <div key={type} className="flex items-center gap-4 px-4 py-3">
                                    <div className="min-w-0 flex-1">
                                        <p className="text-sm font-semibold">{label(type)}</p>
                                        <p className="text-xs text-muted">{t("admin.ground.on_map", String(count))}</p>
                                    </div>
                                    <ClearButton type={type} count={count} />
                                </div>
                            );
                        })}
                    </div>}
            </div>
        </section>
    );
}
