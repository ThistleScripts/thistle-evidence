import { useEffect, useRef, useState } from "react";
import { AlertTriangle, CalendarClock, Car, MapPin, Microscope, Play } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { useDebounce } from "@/hooks/useDebounce";
import { cn } from "@/utils/cn";
import { callServer } from "./server";
import type { CaseFile, LabEvidence, Selection } from "./types";
import { Button, KindChip, Label, kindStyles, useTypeLabel, vehiclePlace } from "./ui";
import CaseFileView from "./CaseFileView";

interface AnalysisBenchProps {
    selection: Selection | null;
    onAnalysed: (selection: Selection) => void;
}

const stageCount = 4;
const stageDuration = 900;

export default function AnalysisBench({ selection, onAnalysed }: AnalysisBenchProps) {
    const { t } = useTranslation();
    const typeLabel = useTypeLabel();

    const [notes, setNotes] = useState(selection?.evidence.additionalData ?? "");
    const debouncedNotes = useDebounce(notes);
    const savedNotes = useRef(notes);

    const [stage, setStage] = useState<number | null>(null); // the running analysis step, null when idle
    const [caseFile, setCaseFile] = useState<CaseFile | null>(null);
    const [failed, setFailed] = useState(false);

    // Already analysed evidence shows its result straight away (the server just returns it again)
    useEffect(() => {
        if (selection?.evidence.analysed) analyse(false);
    }, []);

    useEffect(() => {
        if (!selection || debouncedNotes === savedNotes.current) return;
        savedNotes.current = debouncedNotes;
        callServer("evidences:updateAdditionalData", { inventory: selection.inventory, slot: selection.item.slot, additionalData: debouncedNotes });
    }, [debouncedNotes]);

    if (!selection) {
        return (
            <section className="flex flex-1 flex-col items-center justify-center gap-3 text-muted">
                <Microscope size={40} strokeWidth={1.25} className="opacity-50" />
                <p className="text-sm">{t("lab.bench.select")}</p>
            </section>
        );
    }

    const { item, evidence } = selection;
    const style = kindStyles[evidence.kind];

    async function analyse(animate: boolean) {
        if (!selection) return;

        setFailed(false);
        const request = callServer<{ evidence: LabEvidence; caseFile: CaseFile }>("evidences:lab:analyse", {
            inventory: selection.inventory,
            slot: selection.item.slot,
            kind: selection.evidence.kind
        });

        // the machine takes its time on a fresh sample
        if (animate) {
            for (let i = 0; i < stageCount; i++) {
                setStage(i);
                await new Promise(resolve => setTimeout(resolve, stageDuration));
            }
        }

        const result = await request;
        setStage(null);

        if (!result.success || !result.response) {
            setFailed(true);
            return;
        }

        setCaseFile(result.response.caseFile);
        onAnalysed({ ...selection, evidence: result.response.evidence });
    }

    return (
        <section className="th-scroll flex min-w-0 flex-1 flex-col gap-5 overflow-y-auto p-6">
            <div className="flex gap-5">
                <img src={item.imagePath} className={cn("h-24 w-24 shrink-0 rounded-lg border bg-raised object-contain p-2", style.border)} />

                <div className="min-w-0 flex-1 space-y-2">
                    <div className="flex items-center gap-2">
                        <KindChip kind={evidence.kind} />
                        <span className="text-xs text-muted">{typeLabel(evidence.evidenceType)}</span>
                    </div>
                    <h2 className="truncate font-display text-2xl font-bold">{item.label}</h2>
                    <div className="flex flex-wrap gap-x-6 gap-y-1 text-sm text-muted">
                        <span className="flex items-center gap-1.5"><MapPin size={14} />{evidence.crimeScene || "-"}</span>
                        {evidence.vehicleLocation && <span className="flex items-center gap-1.5 text-ink"><Car size={14} className="text-muted" />{vehiclePlace(evidence)}</span>}
                        <span className="flex items-center gap-1.5"><CalendarClock size={14} />{evidence.collectionTime || "-"}</span>
                    </div>
                </div>
            </div>

            <label className="block space-y-1.5">
                <Label>{t("lab.bench.notes")}</Label>
                <textarea
                    className="th-input h-20 resize-none px-3 py-2 text-sm"
                    maxLength={500}
                    placeholder={t("lab.bench.notes_placeholder")}
                    value={notes}
                    onChange={event => setNotes(event.target.value)}
                />
            </label>

            {failed && (
                <div className="flex items-center gap-2 rounded-lg border border-bad/40 bg-bad/10 px-4 py-3 text-sm text-bad">
                    <AlertTriangle size={16} />
                    {t("lab.errors.analyse")}
                </div>
            )}

            {stage !== null ? (
                <AnalysisProgress kind={evidence.kind} stage={stage} image={item.imagePath} />
            ) : caseFile ? (
                <CaseFileView caseFile={caseFile} evidence={selection.evidence} onChanged={() => analyse(false)} />
            ) : !evidence.analysed && (
                <div className="flex flex-1 flex-col items-center justify-center gap-4 rounded-lg border border-dashed border-line p-10">
                    <p className="max-w-md text-center text-sm text-muted">{t(`lab.bench.intro.${evidence.kind}`)}</p>
                    <Button onClick={() => analyse(true)}>
                        <Play size={15} />
                        {t("lab.bench.run")}
                    </Button>
                </div>
            )}
        </section>
    );
}

function AnalysisProgress({ kind, stage, image }: { kind: LabEvidence["kind"]; stage: number; image: string }) {
    const { t } = useTranslation();
    const style = kindStyles[kind];

    return (
        <div className="flex flex-1 items-center gap-8 rounded-lg border border-line bg-surface p-8">
            {/* the evidence under the microscope lens */}
            <div className={cn("relative h-44 w-44 shrink-0 overflow-hidden rounded-full border-4 bg-[radial-gradient(circle,rgb(40_46_60)_0%,rgb(9_11_16)_75%)] shadow-[inset_0_0_40px_rgba(0,0,0,0.9)]", style.border)}>
                <img src={image} className="h-full w-full scale-125 object-contain p-6 opacity-80" />
                <div className={cn("absolute inset-0 opacity-40", style.text)}>
                    <div className="absolute left-1/2 top-0 h-full w-px -translate-x-1/2 bg-current" />
                    <div className="absolute top-1/2 left-0 h-px w-full -translate-y-1/2 bg-current" />
                    <div className="absolute left-1/2 top-1/2 h-1/2 w-1/2 -translate-x-1/2 -translate-y-1/2 rounded-full border border-current" />
                </div>
                <div className={cn("animate-th-scan absolute left-0 h-0.5 w-full shadow-[0_0_12px_2px_currentColor]", style.text, "bg-current")} />
            </div>

            <div className="flex-1 space-y-4">
                <div className="h-1.5 overflow-hidden rounded-full bg-raised">
                    <div
                        className="h-full rounded-full bg-accent transition-[width] duration-[900ms] ease-linear"
                        style={{ width: `${((stage + 1) / stageCount) * 100}%` }}
                    />
                </div>

                <ol className="space-y-2">
                    {Array.from({ length: stageCount }, (_, i) => (
                        <li key={i} className={cn("flex items-center gap-2 text-sm transition-colors", i < stage ? "text-muted" : i === stage ? "text-ink" : "text-muted/40")}>
                            <span className={cn("h-1.5 w-1.5 rounded-full", i < stage ? "bg-ok" : i === stage ? "animate-th-pulse bg-accent" : "bg-line")} />
                            {t(`lab.stages.${kind}.${i + 1}`)}
                        </li>
                    ))}
                </ol>
            </div>
        </div>
    );
}
