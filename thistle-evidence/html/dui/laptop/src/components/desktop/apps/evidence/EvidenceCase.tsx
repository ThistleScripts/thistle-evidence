import { useEffect, useState } from "react";
import { Crosshair, Dna, Fingerprint, FolderPlus, Link2, ScrollText, Search, ShieldAlert, ShieldCheck, Unlink, UserCheck, UserRound, UserSearch } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { useAppContext } from "@/hooks/useAppContext";
import { useDebounce } from "@/hooks/useDebounce";
import useLuaCallback from "@/hooks/useLuaCallback";
import type { CaseFile, Kind } from "@/lab/types";
import { formatDateTime, useTypeLabel, vehiclePlace } from "@/lab/ui";
import type Citizen from "@/types/citizen.type";
import type { BiometricDataLinkedEvent } from "@/types/events.type";
import { cn } from "@/utils/cn";
import { AddToCasePopUp } from "../cases/CasesApp";

export const panel = "bg-raised/70 shadow-glass border-2 border-line rounded-16";

const kindStyles: Record<Kind, { icon: typeof Dna; className: string }> = {
    dna: { icon: Dna, className: "bg-ok/15 border-ok/40 text-ok" },
    fingerprint: { icon: Fingerprint, className: "bg-info/15 border-info/40 text-info" },
    ballistics: { icon: Crosshair, className: "bg-warn/15 border-warn/40 text-warn" }
};

export function KindBadge({ kind, large }: { kind: Kind; large?: boolean }) {
    const style = kindStyles[kind];
    const Icon = style.icon;

    return <div className={cn("flex shrink-0 items-center justify-center rounded-10 border-2", large ? "w-14 h-14" : "w-9 h-9", style.className)}>
        <Icon size={large ? 28 : 18} strokeWidth={2} />
    </div>;
}

export function SectionTitle({ icon: Icon, children, className }: { icon: typeof Dna; children: React.ReactNode; className?: string }) {
    return <div className="flex items-center gap-2">
        <Icon size={20} className={className ?? "text-accent"} />
        <p className="text-20 leading-none m-0 uppercase">{children}</p>
    </div>;
}

export function Detail({ label, children }: { label: string; children: React.ReactNode }) {
    return <div className="min-w-0">
        <p className="text-20 leading-none uppercase text-muted">{label}</p>
        <p className="text-25 leading-tight truncate">{children || "-"}</p>
    </div>;
}

export function PillButton({ onClick, icon: Icon, children, className }: { onClick: () => void; icon: typeof Dna; children: React.ReactNode; className?: string }) {
    return <button type="button" onClick={onClick}
        className={cn("flex items-center gap-2 px-3 py-1.5 rounded-10 border-2 border-line text-20 leading-none hoverable transition-colors hover:border-accent hover:text-accent", className)}>
        <Icon size={18} />
        {children}
    </button>;
}

interface EvidenceCaseProps {
    kind: Kind;
    matchKey: string;
}

// Everything known about a DNA profile, fingerprint or gun ID: who it belongs to and every analysed piece of evidence with it
export default function EvidenceCase({ kind, matchKey }: EvidenceCaseProps) {
    const { t } = useTranslation();
    const appContext = useAppContext();
    const { data: caseFile, trigger: fetchCaseFile, loading } = useLuaCallback<{ kind: Kind; key: string }, CaseFile>({ name: "evidences:lab:getCaseFile" });

    const reload = () => fetchCaseFile({ kind, key: matchKey });
    useEffect(reload, [kind, matchKey]);

    return <>
        <div className={cn("w-full flex items-center gap-4 p-6", panel)}>
            <KindBadge kind={kind} large />
            <div className="min-w-0 flex-1">
                <p className="text-20 leading-none uppercase text-muted">{t(`lab.result.key.${kind}`)}</p>
                <p className="text-35 leading-tight font-mono tracking-wider truncate">{matchKey}</p>
            </div>
            <PillButton icon={FolderPlus} onClick={() => appContext.openPopUp(t("laptop.desktop_screen.cases_app.add_to_case"), <AddToCasePopUp kind={kind} matchKey={matchKey} />)}>
                {t("laptop.desktop_screen.cases_app.add_to_case")}
            </PillButton>
        </div>

        {!caseFile
            ? <p className="text-20 leading-none text-muted px-2">{loading && t("laptop.desktop_screen.common.statuses.loading")}</p>
            : <>
                {kind === "ballistics" ? <FirearmCard caseFile={caseFile} /> : <CitizenCard caseFile={caseFile} onChanged={reload} />}
                <LinkedEvidenceList caseFile={caseFile} />
            </>}
    </>;
}

function FirearmCard({ caseFile }: { caseFile: CaseFile }) {
    const { t } = useTranslation();
    const appContext = useAppContext();
    const firearm = caseFile.firearm;

    if (!firearm) {
        return <div className={cn("w-full flex gap-4 p-6", panel, "border-warn/40")}>
            <ShieldAlert size={28} className="shrink-0 text-warn" />
            <div className="flex flex-col gap-2">
                <p className="text-30 leading-none text-warn">{t("lab.result.unregistered")}</p>
                <p className="text-22.5 leading-tight text-muted">{t("lab.result.unregistered_hint")}</p>
            </div>
        </div>;
    }

    return <div className={cn("w-full flex flex-col gap-4 p-6", panel)}>
        <SectionTitle icon={ShieldCheck} className="text-ok">{t("lab.result.registered")}</SectionTitle>
        <div className="flex items-center gap-5">
            {firearm.imagePath && <img src={firearm.imagePath} className="w-36 h-24 shrink-0 object-contain" />}
            <div className="min-w-0 flex-1 grid grid-cols-2 gap-x-6 gap-y-3">
                <Detail label={t("laptop.desktop_screen.firearms_registry_app.firearm_type")}>{firearm.label}</Detail>
                <Detail label={t("lab.result.registered_to")}>{caseFile.citizen?.fullName ?? t("laptop.desktop_screen.common.statuses.unknown")}</Detail>
            </div>
        </div>
        <div className="flex flex-wrap gap-2">
            <PillButton icon={ScrollText} onClick={() => appContext.openApp("firearms_registry", { firearm })}>{t("laptop.desktop_screen.evidence_app.open_firearm")}</PillButton>
            {caseFile.citizen && <PillButton icon={UserRound} onClick={() => appContext.openApp("citizens", { citizen: caseFile.citizen })}>{t("laptop.desktop_screen.evidence_app.open_citizen")}</PillButton>}
        </div>
    </div>;
}

function CitizenCard({ caseFile, onChanged }: { caseFile: CaseFile; onChanged: () => void }) {
    const { t } = useTranslation();
    const appContext = useAppContext();
    const citizen = caseFile.citizen;
    const kind = caseFile.kind as "dna" | "fingerprint";

    const announce = (biometricData: string | undefined, linkedCitizen: Citizen) => {
        window.dispatchEvent(new CustomEvent<BiometricDataLinkedEvent>("evidences:biometricDataLinked", {
            detail: { type: kind, identifier: biometricData, citizen: linkedCitizen }
        }));
    };

    const { trigger: link } = useLuaCallback<{ type: Kind; biometricData?: string; identifier: string; citizen: Citizen }, unknown>({
        name: "evidences:linkBiometricDataToIdentifier",
        onSuccess: (_, args) => {
            appContext.displayNotification({
                type: "Success",
                message: args.biometricData
                    ? t("laptop.desktop_screen.evidence_app.linked_success", args.citizen.fullName)
                    : t("laptop.desktop_screen.evidence_app.unlinked_success")
            });
            announce(args.biometricData, args.citizen);
            onChanged();
        },
        onError: () => appContext.displayNotification({ type: "Error", message: t("laptop.desktop_screen.evidence_app.link_error") })
    });

    if (citizen) {
        return <div className={cn("w-full flex flex-col gap-4 p-6", panel, "border-ok/40")}>
            <SectionTitle icon={UserCheck} className="text-ok">{t("laptop.desktop_screen.evidence_app.suspect")}</SectionTitle>
            <div className="grid grid-cols-3 gap-x-6">
                <Detail label={t("laptop.desktop_screen.common.name_placeholder")}>{citizen.fullName}</Detail>
                <Detail label={t("laptop.desktop_screen.common.birthdate_placeholder")}>{String(citizen.birthdate)}</Detail>
                <Detail label={t("laptop.desktop_screen.common.gender_placeholder")}>{t(`laptop.desktop_screen.citizens_app.gender.${citizen.gender}`)}</Detail>
            </div>
            <div className="flex flex-wrap gap-2">
                <PillButton icon={UserRound} onClick={() => appContext.openApp("citizens", { citizen })}>{t("laptop.desktop_screen.evidence_app.open_citizen")}</PillButton>
                <PillButton icon={Unlink} className="hover:border-bad hover:text-bad" onClick={() => link({ type: kind, identifier: citizen.identifier, citizen })}>
                    {t("laptop.desktop_screen.evidence_app.unlink")}
                </PillButton>
            </div>
        </div>;
    }

    return <div className={cn("w-full flex flex-col gap-4 p-6", panel)}>
        <div className="flex gap-4">
            <UserSearch size={28} className="shrink-0 text-muted" />
            <div className="flex flex-col gap-2">
                <p className="text-30 leading-none">{t("laptop.desktop_screen.evidence_app.not_linked")}</p>
                <p className="text-22.5 leading-tight text-muted">{t("laptop.desktop_screen.evidence_app.not_linked_hint")}</p>
            </div>
        </div>
        <CitizenSearch onPick={picked => link({ type: kind, biometricData: caseFile.key, identifier: picked.identifier, citizen: picked })} />
    </div>;
}

export function CitizenSearch({ onPick }: { onPick: (citizen: Citizen) => void }) {
    const { t } = useTranslation();
    const [searchText, setSearchText] = useState("");
    const debouncedSearchText = useDebounce<string>(searchText, 500);
    const { data: citizens, setData: setCitizens, trigger: search } = useLuaCallback<{ searchText: string; offset: number }, Citizen[]>({ name: "evidences:getCitizens" });

    useEffect(() => {
        if (debouncedSearchText.trim()) search({ searchText: debouncedSearchText.trim(), offset: 0 });
        else setCitizens([]);
    }, [debouncedSearchText]);

    return <div className="flex flex-col gap-2">
        <div className="flex items-center gap-2 pl-3 bg-window/60 border-2 border-line rounded-10">
            <Search size={20} className="shrink-0 text-muted" />
            <input
                type="text"
                className="input text-25 p-2 bg-transparent border-none shadow-none outline-none appearance-none textable"
                placeholder={t("laptop.desktop_screen.evidence_app.search_citizens")}
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
                maxLength={25}
            />
        </div>

        {(citizens?.length ?? 0) > 0 && <div className="flex flex-col border-2 border-line rounded-10 overflow-hidden">
            {citizens!.slice(0, 5).map(citizen => (
                <div key={citizen.identifier} className="flex items-center gap-3 px-3 py-2 border-t-2 border-line/60 first:border-t-0">
                    <div className="min-w-0 flex-1">
                        <p className="text-25 leading-none truncate">{citizen.fullName}</p>
                        <p className="text-20 leading-tight text-muted">{String(citizen.birthdate)}</p>
                    </div>
                    <PillButton icon={Link2} onClick={() => onPick(citizen)}>{t("laptop.desktop_screen.evidence_app.link")}</PillButton>
                </div>
            ))}
        </div>}
    </div>;
}

function LinkedEvidenceList({ caseFile }: { caseFile: CaseFile }) {
    const { t } = useTranslation();
    const typeLabel = useTypeLabel();
    const matches = caseFile.matches ?? [];
    const locales = t("laptop.desktop_screen.common.date_locales");

    return <div className={cn("w-full flex flex-col gap-3 p-6", panel)}>
        <div className="flex items-center gap-2">
            <SectionTitle icon={Link2}>{t("lab.links.title")}</SectionTitle>
            <p className="text-20 leading-none text-muted">· {t("lab.links.count", matches.length)}</p>
        </div>

        {matches.length === 0
            ? <p className="text-22.5 text-muted">{t("lab.links.none")}</p>
            : <div className="flex flex-col">
                <div className="flex gap-4 pb-2 text-20 leading-none uppercase text-muted">
                    <p className="w-[22%]">{t("lab.links.columns.type")}</p>
                    <p className="flex-1">{t("lab.links.columns.crime_scene")}</p>
                    <p className="w-[22%]">{t("lab.links.columns.collected")}</p>
                    <p className="w-[24%] text-right">{t("lab.links.columns.analysed")}</p>
                </div>
                {matches.map(match => (
                    <div key={match.id} className="flex items-center gap-4 py-2 border-t-2 border-line/60">
                        <div className="w-[22%] min-w-0">
                            <p className="text-25 leading-none truncate">{typeLabel(match.evidenceType)}</p>
                            {match.weaponType && <p className="text-20 leading-tight text-muted truncate">{match.weaponType}</p>}
                        </div>
                        <div className="flex-1 min-w-0">
                            <p className="text-25 leading-none truncate">{match.crimeScene || "-"}</p>
                            {match.vehicleLocation && <p className="text-20 leading-tight text-muted truncate">{vehiclePlace(match)}</p>}
                        </div>
                        <p className="w-[22%] text-22.5 leading-none text-muted truncate">{match.collectionTime || "-"}</p>
                        <div className="w-[24%] text-right min-w-0">
                            <p className="text-22.5 leading-none truncate">{formatDateTime(match.analysedAt, locales)}</p>
                            <p className="text-20 leading-tight text-muted truncate">{match.analysedBy}</p>
                        </div>
                    </div>
                ))}
            </div>}
    </div>;
}
