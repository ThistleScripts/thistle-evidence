import { useEffect, useState } from "react";
import { CircleDashed, CheckCircle2, ClipboardList, Package, RefreshCw, Search } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { useDebounce } from "@/hooks/useDebounce";
import useInfiniteScroll from "@/hooks/useInfiniteScroll";
import useLuaCallback from "@/hooks/useLuaCallback";
import type { ForensicMatch, Kind, LabEvidence, LabInventory, LabItem } from "@/lab/types";
import { formatDateTime, useTypeLabel, vehiclePlace } from "@/lab/ui";
import { cn } from "@/utils/cn";
import EvidenceCase, { Detail, KindBadge, panel } from "./EvidenceCase";
import CarriedEvidence from "./CarriedEvidence";

type Tab = "log" | "carried";

export type EvidenceSelection =
    | { source: "log"; match: ForensicMatch }
    | { source: "carried"; inventory: number | string; item: LabItem; evidence: LabEvidence }
    | { source: "case"; kind: Kind; key: string };

interface EvidenceAppProps {
    kind?: Kind; // opened from another app with a DNA profile, fingerprint or gun ID
    matchKey?: string;
}

// Reviewing evidence and linking it to citizens. Analysis is done at a forensic microscope; what it found is logged here.
export default function EvidenceApp({ kind, matchKey }: EvidenceAppProps) {
    const { t } = useTranslation();
    const [tab, setTab] = useState<Tab>("log");
    const [selection, setSelection] = useState<EvidenceSelection | null>(kind && matchKey ? { source: "case", kind, key: matchKey } : null);

    useEffect(() => {
        if (kind && matchKey) setSelection({ source: "case", kind, key: matchKey });
    }, [kind, matchKey]);

    return <div className="w-full h-full flex gap-4 p-4 bg-window">
        <div className="w-80 h-full flex flex-col gap-2 shrink-0">
            <div className={cn("flex gap-1 p-1", panel)}>
                {(["log", "carried"] as Tab[]).map(option => (
                    <button key={option} type="button" onClick={() => setTab(option)}
                        className={cn("flex flex-1 items-center justify-center gap-2 py-2 rounded-10 text-20 leading-none uppercase hoverable transition-colors", tab === option ? "bg-button" : "hover:bg-accent/30")}>
                        {option === "log" ? <ClipboardList size={18} /> : <Package size={18} />}
                        {t(`laptop.desktop_screen.evidence_app.tabs.${option}`)}
                    </button>
                ))}
            </div>

            {tab === "log"
                ? <EvidenceLog selection={selection} onSelect={setSelection} />
                : <CarriedList selection={selection} onSelect={setSelection} />}
        </div>

        <div className="h-full min-w-0 flex flex-col grow gap-4 overflow-y-auto scrollbar">
            {selection === null && <div className="h-full flex justify-center items-center">
                <p className="text-20 leading-none text-center">{t("laptop.desktop_screen.evidence_app.select")}</p>
            </div>}

            {selection?.source === "log" && <>
                <LoggedDetails match={selection.match} />
                <EvidenceCase key={`${selection.match.kind}-${selection.match.matchKey}`} kind={selection.match.kind} matchKey={selection.match.matchKey} />
            </>}

            {selection?.source === "carried" && <CarriedEvidence key={`${selection.inventory}-${selection.item.slot}-${selection.evidence.kind}`} selection={selection} />}

            {selection?.source === "case" && <EvidenceCase key={`${selection.kind}-${selection.key}`} kind={selection.kind} matchKey={selection.key} />}
        </div>
    </div>;
}

function EvidenceLog({ selection, onSelect }: { selection: EvidenceSelection | null; onSelect: (selection: EvidenceSelection) => void }) {
    const { t } = useTranslation();
    const typeLabel = useTypeLabel();
    const [searchText, setSearchText] = useState("");
    const debouncedSearchText = useDebounce<string>(searchText, 750);

    const { data: matches, fetchData, loading, reloadRef, scrollRef, handleScroll, handleReload } =
        useInfiniteScroll<ForensicMatch, { searchText: string }>("evidences:getEvidenceLog", { searchText: debouncedSearchText });

    useEffect(() => fetchData(true), [debouncedSearchText]);

    return <>
        <div className="w-full flex items-center gap-2">
            <div className={cn("min-w-0 flex flex-1 items-center gap-2 pl-3", panel, "rounded-10")}>
                <Search size={22} className="shrink-0 text-muted" />
                <input
                    type="text"
                    className="input text-25 p-2 bg-transparent border-none shadow-none outline-none appearance-none textable"
                    placeholder={t("laptop.desktop_screen.evidence_app.search")}
                    onChange={(e) => setSearchText(e.target.value)}
                    value={searchText}
                    maxLength={50}
                />
            </div>
            <div ref={reloadRef} className="flex justify-center items-center p-1 rounded-10 hoverable hover:bg-accent/30" onClick={handleReload}>
                <RefreshCw size={20} />
            </div>
        </div>

        <div ref={scrollRef} onScroll={handleScroll} className={cn("w-full flex-1 flex flex-col gap-1 px-3 py-4 overflow-y-auto scrollbar", panel)}>
            {matches.length === 0
                ? <div className="w-full h-full flex justify-center items-center">
                    <p className="text-20 leading-none text-center">{loading ? t("laptop.desktop_screen.common.statuses.loading") : t("laptop.desktop_screen.evidence_app.empty_log")}</p>
                </div>
                : matches.map(match => (
                    <ListRow key={match.id}
                        active={selection?.source === "log" && selection.match.id === match.id}
                        onClick={() => onSelect({ source: "log", match })}
                        kind={match.kind}
                        title={typeLabel(match.evidenceType)}
                        description={match.vehicleLocation ? vehiclePlace(match) : (match.crimeScene || match.matchKey)}
                        trailing={<span className="text-15 leading-none opacity-60 font-mono">{match.matchKey.slice(0, 8)}</span>}
                    />
                ))}
        </div>
    </>;
}

function CarriedList({ selection, onSelect }: { selection: EvidenceSelection | null; onSelect: (selection: EvidenceSelection) => void }) {
    const { t } = useTranslation();
    const typeLabel = useTypeLabel();
    const { data: inventories, trigger: fetchCarried, loading } = useLuaCallback<object, LabInventory[]>({ name: "evidences:lab:getEvidence" });

    useEffect(() => fetchCarried({}), []);

    const isEmpty = !inventories || inventories.every(inventory => inventory.items.length === 0);

    return <>
        <div className="w-full flex justify-end">
            <div className="flex justify-center items-center p-1 rounded-10 hoverable hover:bg-accent/30" onClick={() => fetchCarried({})}>
                <RefreshCw size={20} className={cn(loading && "animate-spin")} />
            </div>
        </div>

        <div className={cn("w-full flex-1 flex flex-col gap-3 px-3 py-4 overflow-y-auto scrollbar", panel)}>
            {isEmpty
                ? <div className="w-full h-full flex justify-center items-center">
                    <p className="text-20 leading-none text-center">{loading ? t("laptop.desktop_screen.common.statuses.loading") : t("laptop.desktop_screen.evidence_app.empty_carried")}</p>
                </div>
                : inventories!.filter(inventory => inventory.items.length > 0).map(inventory => (
                    <div key={String(inventory.inventory)} className="flex flex-col gap-1">
                        <p className="px-1 text-20 leading-none uppercase text-muted">{inventory.label}</p>
                        {inventory.items.flatMap(item => item.details.evidence.map(evidence => (
                            <ListRow key={`${item.slot}-${evidence.kind}`}
                                active={selection?.source === "carried" && selection.inventory === inventory.inventory && selection.item.slot === item.slot && selection.evidence.kind === evidence.kind}
                                onClick={() => onSelect({ source: "carried", inventory: inventory.inventory, item, evidence })}
                                kind={evidence.kind}
                                imagePath={item.imagePath}
                                title={item.label}
                                description={evidence.vehicleLocation || evidence.crimeScene || typeLabel(evidence.evidenceType)}
                                trailing={evidence.analysed
                                    ? <CheckCircle2 size={18} className="text-ok" />
                                    : <CircleDashed size={18} className="text-muted" />}
                            />
                        )))}
                    </div>
                ))}
        </div>
    </>;
}

interface ListRowProps {
    active: boolean;
    onClick: () => void;
    kind: Kind;
    imagePath?: string;
    title: string;
    description: string;
    trailing?: React.ReactNode;
}

function ListRow({ active, onClick, kind, imagePath, title, description, trailing }: ListRowProps) {
    return <button type="button" onClick={onClick}
        className={cn("w-full flex items-center gap-3 px-2 py-2 border-none rounded-10 text-left hoverable transition-all duration-400", active ? "bg-button" : "bg-transparent hover:bg-accent/30")}>
        {imagePath ? <img src={imagePath} className="w-9 h-9 shrink-0 object-contain" /> : <KindBadge kind={kind} />}
        <div className="min-w-0 flex-1">
            <p className="text-25 leading-none truncate">{title}</p>
            <p className={cn("text-20 leading-tight truncate", active ? "text-white/80" : "text-muted")}>{description}</p>
        </div>
        {trailing}
    </button>;
}

// What was found when a logged piece of evidence was analysed
function LoggedDetails({ match }: { match: ForensicMatch }) {
    const { t } = useTranslation();
    const typeLabel = useTypeLabel();
    const locales = t("laptop.desktop_screen.common.date_locales");

    return <div className={cn("w-full grid grid-cols-2 gap-x-6 gap-y-4 p-6", panel)}>
        <Detail label={t("laptop.desktop_screen.evidence_app.details")}>{typeLabel(match.evidenceType)}{match.weaponType ? ` · ${match.weaponType}` : ""}</Detail>
        <Detail label={t("laptop.desktop_screen.evidence_app.crime_scene")}>{match.crimeScene}</Detail>
        {match.vehicleLocation && <Detail label={t("lab.vehicle.found_on")}>{vehiclePlace(match)}</Detail>}
        <Detail label={t("laptop.desktop_screen.evidence_app.collected")}>{match.collectionTime}</Detail>
        <Detail label={t("laptop.desktop_screen.evidence_app.analysed")}>{`${formatDateTime(match.analysedAt, locales)} · ${match.analysedBy}`}</Detail>
    </div>;
}
