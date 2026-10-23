import { useState } from "react";
import { Check, Copy, Link2, ShieldAlert, ShieldCheck, UserCheck, UserSearch } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { getStatusById, Status } from "@/types/firearm.type";
import { cn } from "@/utils/cn";
import type { CaseFile, LabEvidence } from "./types";
import { Card, Label, copyText, formatDateTime, kindStyles, useTypeLabel, vehiclePlace } from "./ui";
import CitizenLinker from "./CitizenLinker";

interface CaseFileViewProps {
    caseFile: CaseFile;
    evidence?: LabEvidence; // set when showing an analysis; absent for a case file search
    onChanged: () => void;
}

export default function CaseFileView({ caseFile, evidence, onChanged }: CaseFileViewProps) {
    // Magazines and gunshot residue only tell the weapon type
    if (!caseFile.key && evidence) {
        return <WeaponTypeResult evidence={evidence} />;
    }

    return (
        <div className="animate-th-rise space-y-5">
            <KeyRow caseFile={caseFile} />
            {caseFile.kind === "ballistics"
                ? <FirearmResult caseFile={caseFile} />
                : <CitizenResult caseFile={caseFile} onChanged={onChanged} />}
            <LinkedEvidence caseFile={caseFile} />
        </div>
    );
}

function KeyRow({ caseFile }: { caseFile: CaseFile }) {
    const { t } = useTranslation();
    const [copied, setCopied] = useState(false);
    const style = kindStyles[caseFile.kind];
    const Icon = style.icon;

    const copy = () => {
        copyText(caseFile.key!);
        setCopied(true);
        setTimeout(() => setCopied(false), 1500);
    };

    return (
        <Card className="flex items-center gap-4 px-5 py-4">
            <div className={cn("flex h-10 w-10 items-center justify-center rounded-lg", style.bg, style.text)}>
                <Icon size={20} />
            </div>
            <div className="min-w-0 flex-1">
                <Label>{t(`lab.result.key.${caseFile.kind}`)}</Label>
                <p className="truncate font-mono text-lg tracking-wider">{caseFile.key}</p>
            </div>
            <button type="button" onClick={copy} className="flex cursor-pointer items-center gap-1.5 rounded-md border border-line px-2.5 py-1.5 text-xs text-muted transition-colors hover:border-accent hover:text-accent">
                {copied ? <Check size={13} /> : <Copy size={13} />}
                {t("lab.result.copy")}
            </button>
        </Card>
    );
}

function FirearmResult({ caseFile }: { caseFile: CaseFile }) {
    const { t } = useTranslation();
    const firearm = caseFile.firearm;

    if (!firearm) {
        return (
            <Card className="flex gap-4 border-warn/40 bg-warn/5 px-5 py-4">
                <ShieldAlert size={22} className="mt-0.5 shrink-0 text-warn" />
                <div className="space-y-1">
                    <p className="font-display font-bold text-warn">{t("lab.result.unregistered")}</p>
                    <p className="text-sm text-muted">{t("lab.result.unregistered_hint")}</p>
                </div>
            </Card>
        );
    }

    const status = getStatusById(firearm.status) ?? Status.UNKNOWN;

    return (
        <Card className="overflow-hidden">
            <div className="flex items-center gap-2 border-b border-line bg-ok/5 px-5 py-2.5 text-sm font-semibold text-ok">
                <ShieldCheck size={16} />
                {t("lab.result.registered")}
            </div>
            <div className="flex items-center gap-5 px-5 py-4">
                <img src={firearm.imagePath} className="h-16 w-24 shrink-0 object-contain" />
                <div className="min-w-0 flex-1 space-y-1">
                    <div className="flex items-center gap-2">
                        <p className="truncate font-display text-lg font-bold">{firearm.label}</p>
                        <span className={cn("rounded-full px-2 py-0.5 text-[11px] font-semibold text-bg", status.className)}>{t(status.translationKey)}</span>
                    </div>
                    <p className="text-sm text-muted">{t("lab.result.registered_by", firearm.registeredBy)}</p>
                </div>
                <div className="text-right">
                    <Label>{t("lab.result.registered_to")}</Label>
                    <p className="font-medium">{caseFile.citizen?.fullName ?? t("laptop.desktop_screen.common.statuses.unknown")}</p>
                    {caseFile.citizen && <p className="text-xs text-muted">{String(caseFile.citizen.birthdate)}</p>}
                </div>
            </div>
        </Card>
    );
}

function CitizenResult({ caseFile, onChanged }: { caseFile: CaseFile; onChanged: () => void }) {
    const { t } = useTranslation();
    const citizen = caseFile.citizen;

    if (citizen) {
        return (
            <Card className="flex items-center gap-4 border-ok/40 bg-ok/5 px-5 py-4">
                <UserCheck size={22} className="shrink-0 text-ok" />
                <div className="flex-1">
                    <Label className="text-ok">{t("lab.result.citizen_match")}</Label>
                    <p className="font-display text-lg font-bold">{citizen.fullName}</p>
                </div>
                <div className="text-right text-sm text-muted">
                    <p>{String(citizen.birthdate)}</p>
                    <p>{t(`laptop.desktop_screen.citizens_app.gender.${citizen.gender}`)}</p>
                </div>
            </Card>
        );
    }

    return (
        <Card className="space-y-3 px-5 py-4">
            <div className="flex gap-4">
                <UserSearch size={22} className="mt-0.5 shrink-0 text-muted" />
                <div className="space-y-1">
                    <p className="font-display font-bold">{t("lab.result.no_citizen")}</p>
                    <p className="text-sm text-muted">{t("lab.result.no_citizen_hint")}</p>
                </div>
            </div>
            <CitizenLinker kind={caseFile.kind} biometricData={caseFile.key!} onLinked={onChanged} />
        </Card>
    );
}

function LinkedEvidence({ caseFile }: { caseFile: CaseFile }) {
    const { t } = useTranslation();
    const typeLabel = useTypeLabel();
    const matches = caseFile.matches ?? [];
    const locales = t("laptop.desktop_screen.common.date_locales");

    return (
        <div className="space-y-2">
            <div className="flex items-center gap-2">
                <Link2 size={15} className="text-accent" />
                <Label>{t("lab.links.title")}</Label>
                <span className="text-xs text-muted">· {t("lab.links.count", matches.length)}</span>
            </div>

            {matches.length === 0 ? (
                <p className="rounded-lg border border-dashed border-line px-4 py-3 text-sm text-muted">{t("lab.links.none")}</p>
            ) : (
                <Card className="overflow-hidden">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="text-left">
                                {["type", "crime_scene", "collected", "analysed"].map(column => (
                                    <th key={column} className="th-label px-4 py-2.5 font-semibold">{t(`lab.links.columns.${column}`)}</th>
                                ))}
                            </tr>
                        </thead>
                        <tbody>
                            {matches.map(match => (
                                <tr key={match.id} className="border-t border-line/60 transition-colors hover:bg-raised/60">
                                    <td className="px-4 py-2.5">
                                        <p className="font-medium">{typeLabel(match.evidenceType)}</p>
                                        {match.weaponType && <p className="text-xs text-muted">{match.weaponType}</p>}
                                    </td>
                                    <td className="px-4 py-2.5">
                                        <p>{match.crimeScene || "-"}</p>
                                        {match.vehicleLocation && <p className="text-xs text-muted">{vehiclePlace(match)}</p>}
                                    </td>
                                    <td className="px-4 py-2.5 text-muted">{match.collectionTime || "-"}</td>
                                    <td className="px-4 py-2.5 text-muted">
                                        <p>{formatDateTime(match.analysedAt, locales)}</p>
                                        <p className="text-xs">{match.analysedBy}</p>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </Card>
            )}
        </div>
    );
}

function WeaponTypeResult({ evidence }: { evidence: LabEvidence }) {
    const { t } = useTranslation();
    const locales = t("laptop.desktop_screen.common.date_locales");

    return (
        <Card className="animate-th-rise flex items-center gap-6 px-6 py-5">
            {evidence.weaponImage && <img src={evidence.weaponImage} className="h-20 w-28 shrink-0 object-contain" />}
            <div className="space-y-2">
                <p className="text-sm text-muted">{t(`lab.result.type_only.${evidence.evidenceType}`)}</p>
                <div>
                    <Label>{t("lab.result.weapon_type")}</Label>
                    <p className="font-display text-xl font-bold">{evidence.weaponType ?? t("laptop.desktop_screen.common.statuses.unknown")}</p>
                </div>
                {evidence.evidenceType === "gunshot_residue" && evidence.createdAt && (
                    <p className="text-sm text-muted">{t("lab.result.fired_at")}: {formatDateTime(evidence.createdAt * 1000, locales)}</p>
                )}
            </div>
        </Card>
    );
}
