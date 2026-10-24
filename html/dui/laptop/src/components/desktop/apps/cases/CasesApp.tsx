import { useEffect, useState } from "react";
import { Archive, ArchiveRestore, Box, FolderOpen, Link2, NotebookPen, Plus, RefreshCw, Search, Trash2, UserRound, Users } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { useAppContext } from "@/hooks/useAppContext";
import { useDebounce } from "@/hooks/useDebounce";
import useInfiniteScroll from "@/hooks/useInfiniteScroll";
import useLuaCallback from "@/hooks/useLuaCallback";
import type { Kind } from "@/lab/types";
import { formatDateTime } from "@/lab/ui";
import type Citizen from "@/types/citizen.type";
import { cn } from "@/utils/cn";
import { CitizenSearch, KindBadge, PillButton, SectionTitle, panel } from "../evidence/EvidenceCase";

export interface CaseSummary {
    id: number;
    caseNumber: string;
    title: string;
    status: "open" | "closed";
    createdBy: string;
    createdAt: number;
    updatedAt: number;
    suspects: number;
    evidence: number;
}

interface CaseLink {
    id: number;
    kind: "suspect" | Kind;
    ref: string;
    addedBy: string;
    addedAt: number;
    citizen?: Citizen;
    matches?: number;
}

interface CaseNote {
    id: number;
    text: string;
    author: string;
    at: number;
}

interface StoredItem {
    id: number;
    locker: string;
    action: "deposit" | "withdraw";
    label: string;
    item: string;
    amount: number;
    officer: string;
    at: number;
}

interface CaseDetails extends Omit<CaseSummary, "suspects" | "evidence"> {
    suspects: CaseLink[];
    evidence: CaseLink[];
    notes: CaseNote[];
    storage: StoredItem[];
}

// The case board: cases tie together their suspects, the DNA profiles, fingerprints and gun IDs in them, notes, and
// the evidence boxes labelled with their case number in the evidence lockers
export default function CasesApp({ caseId }: { caseId?: number }) {
    const { t } = useTranslation();
    const appContext = useAppContext();
    const [selected, setSelected] = useState<number | undefined>(caseId);
    const [searchText, setSearchText] = useState("");
    const debouncedSearchText = useDebounce<string>(searchText, 600);

    const { data: cases, setData: setCases, fetchData, loading, reloadRef, scrollRef, handleScroll, handleReload, adjustOffset } =
        useInfiniteScroll<CaseSummary, { searchText: string }>("evidences:cases:list", { searchText: debouncedSearchText });

    useEffect(() => fetchData(true), [debouncedSearchText]);
    useEffect(() => { if (caseId) setSelected(caseId); }, [caseId]);

    const openNewCase = () => appContext.openPopUp(t("laptop.desktop_screen.cases_app.new_case"),
        <NewCasePopUp onCreated={created => {
            setCases(prev => [created, ...prev]);
            adjustOffset(1);
            setSelected(created.id);
        }} />);

    return <div className="w-full h-full flex gap-4 p-4 bg-window">
        <div className="w-80 h-full flex flex-col gap-2 shrink-0">
            <div className="w-full flex items-center gap-2">
                <div className={cn("min-w-0 flex flex-1 items-center gap-2 pl-3", panel, "rounded-10")}>
                    <Search size={22} className="shrink-0 text-muted" />
                    <input type="text" className="input text-25 p-2 bg-transparent border-none shadow-none outline-none appearance-none textable"
                        placeholder={t("laptop.desktop_screen.cases_app.search")} value={searchText} maxLength={50}
                        onChange={(e) => setSearchText(e.target.value)} />
                </div>
                <div className="flex flex-col items-center">
                    <div ref={reloadRef} className="flex justify-center items-center p-1 rounded-10 hoverable hover:bg-accent/30" onClick={handleReload}>
                        <RefreshCw size={20} />
                    </div>
                    <div className="flex justify-center items-center p-1 rounded-10 hoverable hover:bg-[rgb(52,199,89)]" onClick={openNewCase}>
                        <Plus size={20} />
                    </div>
                </div>
            </div>

            <div ref={scrollRef} onScroll={handleScroll} className={cn("w-full flex-1 flex flex-col gap-1 px-3 py-4 overflow-y-auto scrollbar", panel)}>
                {cases.length === 0
                    ? <div className="w-full h-full flex justify-center items-center">
                        <p className="text-20 leading-none text-center">{loading ? t("laptop.desktop_screen.common.statuses.loading") : t("laptop.desktop_screen.cases_app.empty")}</p>
                    </div>
                    : cases.map(item => (
                        <button key={item.id} type="button" onClick={() => setSelected(item.id)}
                            className={cn("w-full flex items-center gap-3 px-2 py-2 border-none rounded-10 text-left hoverable transition-all duration-400",
                                selected === item.id ? "bg-button" : "bg-transparent hover:bg-accent/30", item.status === "closed" && selected !== item.id && "opacity-60")}>
                            <div className="flex w-9 h-9 shrink-0 items-center justify-center rounded-10 border-2 border-accent/40 bg-accent/15 text-accent">
                                {item.status === "closed" ? <Archive size={18} /> : <FolderOpen size={18} />}
                            </div>
                            <div className="min-w-0 flex-1">
                                <p className="text-25 leading-none truncate">{item.caseNumber}</p>
                                <p className={cn("text-20 leading-tight truncate", selected === item.id ? "text-white/80" : "text-muted")}>{item.title}</p>
                            </div>
                        </button>
                    ))}
            </div>
        </div>

        <div className="h-full min-w-0 flex flex-col grow gap-4 overflow-y-auto scrollbar">
            {selected
                ? <CaseView key={selected} id={selected} onChanged={updated => setCases(prev => prev.map(c => c.id === updated.id ? { ...c, ...updated } : c))} />
                : <div className="h-full flex justify-center items-center">
                    <p className="text-20 leading-none text-center">{t("laptop.desktop_screen.cases_app.select")}</p>
                </div>}
        </div>
    </div>;
}

function NewCasePopUp({ onCreated }: { onCreated: (created: CaseSummary) => void }) {
    const { t } = useTranslation();
    const appContext = useAppContext();
    const [caseNumber, setCaseNumber] = useState("");
    const [title, setTitle] = useState("");

    const { trigger: create, loading } = useLuaCallback<{ caseNumber: string; title: string }, CaseSummary>({
        name: "evidences:cases:create",
        onSuccess: created => {
            onCreated(created);
            appContext.close();
        },
        onError: () => appContext.displayNotification({ type: "Error", message: t("laptop.desktop_screen.cases_app.errors.create") })
    });

    const submit = () => {
        if (!caseNumber.trim() || !title.trim()) {
            appContext.displayNotification({ type: "Error", message: t("laptop.desktop_screen.common.statuses.fill_all_fields") });
            return;
        }

        create({ caseNumber: caseNumber.trim(), title: title.trim() });
    };

    return <div className="w-full h-full p-4 bg-window flex justify-center">
        <div className="w-[60%] h-full flex flex-col justify-evenly items-center">
            <div className="w-full flex flex-col gap-2">
                <span className="text-20 leading-none uppercase">{t("laptop.desktop_screen.cases_app.case_number")}</span>
                <input className="input textable" maxLength={20} placeholder="1042" value={caseNumber} onChange={(e) => setCaseNumber(e.target.value)} />
            </div>
            <div className="w-full flex flex-col gap-2">
                <span className="text-20 leading-none uppercase">{t("laptop.desktop_screen.cases_app.case_title")}</span>
                <input className="input textable" maxLength={100} placeholder={t("laptop.desktop_screen.cases_app.title_placeholder")} value={title} onChange={(e) => setTitle(e.target.value)} />
            </div>
            <button disabled={loading} onClick={submit}
                className="w-[30%] flex justify-center px-4 py-2 border-none rounded-10 bg-[rgb(52,199,89)] duration-400 transition-all text-30 leading-none hoverable hover:-translate-y-0.5 hover:shadow-button">
                {t("laptop.desktop_screen.cases_app.create")}
            </button>
        </div>
    </div>;
}

function CaseView({ id, onChanged }: { id: number; onChanged: (updated: Partial<CaseSummary> & { id: number }) => void }) {
    const { t } = useTranslation();
    const appContext = useAppContext();
    const locales = t("laptop.desktop_screen.common.date_locales");
    const { data: details, trigger: load, loading } = useLuaCallback<{ id: number }, CaseDetails>({ name: "evidences:cases:get" });
    const reload = () => load({ id });

    useEffect(reload, [id]);

    const { trigger: update } = useLuaCallback<{ id: number; status?: string }, unknown>({
        name: "evidences:cases:update",
        onSuccess: (_, args) => {
            if (args.status) onChanged({ id, status: args.status as CaseSummary["status"] });
            reload();
        }
    });
    const { trigger: addLink } = useLuaCallback<{ id: number; kind: string; ref: string }, unknown>({ name: "evidences:cases:addLink", onSuccess: reload });
    const { trigger: removeLink } = useLuaCallback<{ id: number; linkId: number }, unknown>({ name: "evidences:cases:removeLink", onSuccess: reload });

    if (!details) {
        return <p className="text-20 leading-none text-muted px-2">{loading && t("laptop.desktop_screen.common.statuses.loading")}</p>;
    }

    const closed = details.status === "closed";

    return <>
        <div className={cn("w-full flex items-center gap-4 p-6", panel)}>
            <div className="flex w-14 h-14 shrink-0 items-center justify-center rounded-10 border-2 border-accent/40 bg-accent/15 text-accent">
                {closed ? <Archive size={28} /> : <FolderOpen size={28} />}
            </div>
            <div className="min-w-0 flex-1">
                <p className="text-20 leading-none uppercase text-muted">{t("laptop.desktop_screen.cases_app.case")} {details.caseNumber}{closed ? ` · ${t("laptop.desktop_screen.cases_app.closed")}` : ""}</p>
                <p className="text-35 leading-tight truncate">{details.title}</p>
                <p className="text-20 leading-tight text-muted">{t("laptop.desktop_screen.cases_app.opened_by", details.createdBy, formatDateTime(details.createdAt, locales))}</p>
            </div>
            <PillButton icon={closed ? ArchiveRestore : Archive} onClick={() => update({ id, status: closed ? "open" : "closed" })}>
                {t(closed ? "laptop.desktop_screen.cases_app.reopen" : "laptop.desktop_screen.cases_app.close")}
            </PillButton>
        </div>

        {/* suspects */}
        <div className={cn("w-full flex flex-col gap-3 p-6", panel)}>
            <SectionTitle icon={Users}>{t("laptop.desktop_screen.cases_app.suspects")}</SectionTitle>
            {details.suspects.length === 0 && <p className="text-22.5 text-muted">{t("laptop.desktop_screen.cases_app.no_suspects")}</p>}
            {details.suspects.map(link => (
                <div key={link.id} className="flex items-center gap-3 py-1">
                    <UserRound size={22} className="shrink-0 text-muted" />
                    <div className="min-w-0 flex-1">
                        <p className="text-25 leading-none truncate">{link.citizen?.fullName ?? link.ref}</p>
                        {link.citizen && <p className="text-20 leading-tight text-muted">{String(link.citizen.birthdate)}</p>}
                    </div>
                    {link.citizen && <PillButton icon={UserRound} onClick={() => appContext.openApp("citizens", { citizen: link.citizen })}>{t("laptop.desktop_screen.evidence_app.open_citizen")}</PillButton>}
                    <RemoveButton onClick={() => removeLink({ id, linkId: link.id })} />
                </div>
            ))}
            <CitizenSearch onPick={citizen => addLink({ id, kind: "suspect", ref: citizen.identifier })} />
        </div>

        {/* DNA profiles, fingerprints and gun IDs */}
        <div className={cn("w-full flex flex-col gap-3 p-6", panel)}>
            <SectionTitle icon={Link2}>{t("laptop.desktop_screen.cases_app.evidence")}</SectionTitle>
            {details.evidence.length === 0 && <p className="text-22.5 text-muted">{t("laptop.desktop_screen.cases_app.no_evidence")}</p>}
            {details.evidence.map(link => (
                <div key={link.id} className="flex items-center gap-3 py-1">
                    <KindBadge kind={link.kind as Kind} />
                    <div className="min-w-0 flex-1">
                        <p className="text-25 leading-none truncate font-mono tracking-wider">{link.ref}</p>
                        <p className="text-20 leading-tight text-muted">{t(`lab.result.key.${link.kind}`)} · {t("lab.links.count", link.matches ?? 0)}</p>
                    </div>
                    <PillButton icon={FolderOpen} onClick={() => appContext.openApp("evidence", { kind: link.kind, matchKey: link.ref })}>{t("laptop.desktop_screen.evidence_app.open_evidence")}</PillButton>
                    <RemoveButton onClick={() => removeLink({ id, linkId: link.id })} />
                </div>
            ))}
            <AddEvidenceId onAdd={(kind, ref) => addLink({ id, kind, ref })} />
        </div>

        {/* evidence boxes in the lockers */}
        <div className={cn("w-full flex flex-col gap-3 p-6", panel)}>
            <SectionTitle icon={Box}>{t("laptop.desktop_screen.cases_app.storage")}</SectionTitle>
            {details.storage.length === 0
                ? <p className="text-22.5 text-muted">{t("laptop.desktop_screen.cases_app.no_storage", details.caseNumber)}</p>
                : details.storage.map(entry => (
                    <div key={entry.id} className="flex items-center gap-4 py-1">
                        <p className="flex-1 min-w-0 text-25 leading-none truncate">{entry.label || entry.item}</p>
                        <p className={cn("text-22.5 leading-none", entry.action === "deposit" ? "text-ok" : "text-warn")}>
                            {t(entry.action === "deposit" ? "laptop.desktop_screen.cases_app.in_locker" : "laptop.desktop_screen.cases_app.taken_out", entry.locker)}
                        </p>
                        <p className="w-[30%] text-20 leading-tight text-muted text-right truncate">{entry.officer} · {formatDateTime(entry.at, locales)}</p>
                    </div>
                ))}
        </div>

        <CaseNotes id={id} notes={details.notes} onAdded={reload} />
    </>;
}

function RemoveButton({ onClick }: { onClick: () => void }) {
    return <div className="flex justify-center items-center p-1 rounded-10 hoverable hover:bg-[rgb(233,21,45)]" onClick={onClick}>
        <Trash2 size={18} />
    </div>;
}

const evidenceKinds: Kind[] = ["dna", "fingerprint", "ballistics"];

function AddEvidenceId({ onAdd }: { onAdd: (kind: Kind, ref: string) => void }) {
    const { t } = useTranslation();
    const [kind, setKind] = useState<Kind>("dna");
    const [ref, setRef] = useState("");

    return <div className="flex items-center gap-2">
        <div className="flex gap-1 p-1 border-2 border-line rounded-10">
            {evidenceKinds.map(option => (
                <button key={option} type="button" onClick={() => setKind(option)}
                    className={cn("px-2 py-1 rounded-10 text-20 leading-none hoverable", kind === option ? "bg-button" : "hover:bg-accent/30")}>
                    {t(`lab.kinds.${option}`)}
                </button>
            ))}
        </div>
        <input className="input text-25 p-2 flex-1 min-w-0 textable font-mono uppercase" maxLength={50}
            placeholder={t("laptop.desktop_screen.cases_app.paste_id")} value={ref} onChange={(e) => setRef(e.target.value)} />
        <PillButton icon={Plus} onClick={() => { if (ref.trim()) { onAdd(kind, ref.trim()); setRef(""); } }}>{t("laptop.desktop_screen.cases_app.add")}</PillButton>
    </div>;
}

function CaseNotes({ id, notes, onAdded }: { id: number; notes: CaseNote[]; onAdded: () => void }) {
    const { t } = useTranslation();
    const [text, setText] = useState("");
    const locales = t("laptop.desktop_screen.common.date_locales");
    const { trigger: addNote, loading } = useLuaCallback<{ id: number; text: string }, unknown>({
        name: "evidences:cases:addNote",
        onSuccess: () => { setText(""); onAdded(); }
    });

    return <div className={cn("w-full flex flex-col gap-3 p-6", panel)}>
        <SectionTitle icon={NotebookPen}>{t("laptop.desktop_screen.cases_app.notes")}</SectionTitle>
        <textarea className="w-full h-24 input resize-none scrollbar textable" maxLength={2000}
            placeholder={t("laptop.desktop_screen.cases_app.note_placeholder")} value={text} onChange={(e) => setText(e.target.value)} />
        <div className="flex justify-end">
            <PillButton icon={Plus} onClick={() => { if (text.trim() && !loading) addNote({ id, text: text.trim() }); }}>{t("laptop.desktop_screen.cases_app.add_note")}</PillButton>
        </div>
        {notes.map(note => (
            <div key={note.id} className="flex flex-col gap-1 py-2 border-t-2 border-line/60">
                <p className="text-20 leading-none uppercase text-muted">{note.author} · {formatDateTime(note.at, locales)}</p>
                <p className="text-25 leading-tight whitespace-pre-wrap">{note.text}</p>
            </div>
        ))}
    </div>;
}

// From the Evidence app: put a DNA profile, fingerprint or gun ID on an open case
export function AddToCasePopUp({ kind, matchKey }: { kind: Kind; matchKey: string }) {
    const { t } = useTranslation();
    const appContext = useAppContext();
    const { data: cases, trigger: list } = useLuaCallback<{ searchText: string; offset: number }, CaseSummary[]>({ name: "evidences:cases:list" });
    const { trigger: addLink } = useLuaCallback<{ id: number; kind: string; ref: string }, unknown>({
        name: "evidences:cases:addLink",
        onSuccess: () => {
            appContext.displayNotification({ type: "Success", message: t("laptop.desktop_screen.cases_app.added") });
            appContext.close();
        }
    });

    useEffect(() => list({ searchText: "", offset: 0 }), []);

    const open = (cases ?? []).filter(item => item.status === "open");

    return <div className="w-full h-full p-4 bg-window flex flex-col gap-2 overflow-y-auto scrollbar">
        {open.length === 0 && <p className="text-25 text-muted text-center pt-10">{t("laptop.desktop_screen.cases_app.no_open_cases")}</p>}
        {open.map(item => (
            <button key={item.id} type="button" onClick={() => addLink({ id: item.id, kind, ref: matchKey })}
                className="w-full flex items-center gap-3 px-3 py-2 rounded-10 text-left hoverable hover:bg-accent/30 border-2 border-line">
                <FolderOpen size={20} className="shrink-0 text-accent" />
                <p className="text-25 leading-none">{item.caseNumber}</p>
                <p className="text-25 leading-none text-muted truncate">{item.title}</p>
            </button>
        ))}
    </div>;
}
