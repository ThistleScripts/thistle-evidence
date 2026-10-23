import { useEffect, useRef, useState } from "react";
import { Microscope, NotebookPen } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { useDebounce } from "@/hooks/useDebounce";
import useLuaCallback from "@/hooks/useLuaCallback";
import type { LabEvidence, LabItem } from "@/lab/types";
import { useTypeLabel } from "@/lab/ui";
import { cn } from "@/utils/cn";
import EvidenceCase, { Detail, SectionTitle, panel } from "./EvidenceCase";

interface CarriedEvidenceProps {
    selection: { inventory: number | string; item: LabItem; evidence: LabEvidence };
}

// A piece of evidence the officer is carrying: its details and notes, and what the microscope found once it's analysed
export default function CarriedEvidence({ selection }: CarriedEvidenceProps) {
    const { t } = useTranslation();
    const typeLabel = useTypeLabel();
    const { item, evidence } = selection;

    return <>
        <div className={cn("w-full flex flex-col gap-4 p-6", panel)}>
            <div className="flex items-center gap-4">
                {item.imagePath && <img src={item.imagePath} className="w-16 h-16 shrink-0 object-contain" />}
                <div className="min-w-0">
                    <p className="text-30 leading-none truncate">{item.label}</p>
                    <p className="text-20 leading-tight text-muted">{typeLabel(evidence.evidenceType)}{evidence.weaponType ? ` · ${evidence.weaponType}` : ""}</p>
                </div>
            </div>
            <div className="grid grid-cols-2 gap-x-6 gap-y-4">
                <Detail label={t("laptop.desktop_screen.evidence_app.crime_scene")}>{evidence.crimeScene}</Detail>
                <Detail label={t("laptop.desktop_screen.evidence_app.collected")}>{evidence.collectionTime}</Detail>
            </div>
            <Notes selection={selection} />
        </div>

        {!evidence.analysed
            ? <div className={cn("w-full flex gap-4 p-6", panel, "border-accent/40")}>
                <Microscope size={28} className="shrink-0 text-accent" />
                <div className="flex flex-col gap-2">
                    <p className="text-30 leading-none">{t("laptop.desktop_screen.evidence_app.not_analysed")}</p>
                    <p className="text-22.5 leading-tight text-muted">{t("laptop.desktop_screen.evidence_app.not_analysed_hint")}</p>
                </div>
            </div>
            : evidence.key
                ? <EvidenceCase kind={evidence.kind} matchKey={evidence.key} />
                // magazines and gunshot residue only tell the weapon type
                : <div className={cn("w-full flex flex-col gap-2 p-6", panel)}>
                    <p className="text-22.5 leading-tight text-muted">{t(`lab.result.type_only.${evidence.evidenceType}`)}</p>
                    <Detail label={t("lab.result.weapon_type")}>{evidence.weaponType ?? t("laptop.desktop_screen.common.statuses.unknown")}</Detail>
                </div>}
    </>;
}

function Notes({ selection }: CarriedEvidenceProps) {
    const { t } = useTranslation();
    const [notes, setNotes] = useState(selection.evidence.additionalData || "");
    const debouncedNotes = useDebounce(notes, 750);
    const saved = useRef(notes);

    const { trigger: save } = useLuaCallback<{ inventory: number | string; slot: number; additionalData: string }, void>({ name: "evidences:updateAdditionalData" });

    useEffect(() => {
        if (debouncedNotes === saved.current) return;

        saved.current = debouncedNotes;
        save({ inventory: selection.inventory, slot: selection.item.slot, additionalData: debouncedNotes });
    }, [debouncedNotes]);

    return <div className="flex flex-col gap-2">
        <SectionTitle icon={NotebookPen}>{t("laptop.desktop_screen.evidence_app.notes")}</SectionTitle>
        <textarea
            className="w-full h-28 input resize-none scrollbar textable"
            maxLength={500}
            placeholder={t("laptop.desktop_screen.evidence_app.notes_placeholder")}
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
        />
    </div>;
}
