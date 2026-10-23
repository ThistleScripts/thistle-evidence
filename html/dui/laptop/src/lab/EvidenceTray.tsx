import { CheckCircle2, CircleDashed, Package, RefreshCw } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { cn } from "@/utils/cn";
import type { LabInventory, Selection } from "./types";
import { KindChip, Label, useTypeLabel } from "./ui";

interface EvidenceTrayProps {
    inventories: LabInventory[];
    loading: boolean;
    selection: Selection | null;
    onSelect: (selection: Selection) => void;
    onRefresh: () => void;
}

// Everything the officer carries that holds evidence, grouped by pockets and evidence boxes.
// An item with several traces (e.g. a gun with blood and fingerprints) gets a row per trace.
export default function EvidenceTray({ inventories, loading, selection, onSelect, onRefresh }: EvidenceTrayProps) {
    const { t } = useTranslation();
    const typeLabel = useTypeLabel();
    const isEmpty = !loading && inventories.every(inventory => inventory.items.length === 0);

    return (
        <aside className="flex w-[360px] shrink-0 flex-col border-r border-line">
            <div className="flex items-center justify-between px-5 pb-3 pt-5">
                <Label>{t("lab.tray.title")}</Label>
                <button type="button" title={t("lab.tray.refresh")} onClick={onRefresh} className="cursor-pointer rounded-md p-1.5 text-muted transition-colors hover:bg-raised hover:text-ink">
                    <RefreshCw size={14} className={cn(loading && "animate-spin")} />
                </button>
            </div>

            <div className="th-scroll min-h-0 flex-1 space-y-5 overflow-y-auto px-3 pb-5">
                {isEmpty && (
                    <div className="mx-2 rounded-lg border border-dashed border-line p-5 text-center text-sm text-muted">
                        <Package size={22} className="mx-auto mb-2 opacity-60" />
                        {t("lab.tray.empty")}
                    </div>
                )}

                {inventories.map(inventory => (
                    <section key={String(inventory.inventory)}>
                        <p className="mb-1.5 flex items-center gap-1.5 px-2 text-xs font-medium text-muted">
                            <Package size={12} />
                            {inventory.label}
                        </p>

                        <ul className="space-y-1">
                            {inventory.items.flatMap(item => item.details.evidence.map(evidence => {
                                const selected = selection?.inventory === inventory.inventory
                                    && selection.item.slot === item.slot
                                    && selection.evidence.kind === evidence.kind;

                                return (
                                    <li key={`${item.slot}-${evidence.kind}`}>
                                        <button
                                            type="button"
                                            onClick={() => onSelect({ inventory: inventory.inventory, item, evidence })}
                                            className={cn(
                                                "flex w-full cursor-pointer items-center gap-3 rounded-lg border px-2.5 py-2 text-left transition-colors",
                                                selected ? "border-accent/60 bg-accent/10" : "border-transparent hover:bg-raised"
                                            )}
                                        >
                                            <img src={item.imagePath} className="h-11 w-11 shrink-0 rounded-md bg-raised object-contain p-1" />
                                            <div className="min-w-0 flex-1">
                                                <p className="truncate text-sm font-medium">{item.label}</p>
                                                <p className="truncate text-xs text-muted">{evidence.vehicleLocation || evidence.crimeScene || evidence.collectionTime || typeLabel(evidence.evidenceType)}</p>
                                            </div>
                                            <div className="flex flex-col items-end gap-1">
                                                <KindChip kind={evidence.kind} />
                                                {evidence.analysed
                                                    ? <CheckCircle2 size={14} className="text-ok" aria-label={t("lab.status.analysed")} />
                                                    : <CircleDashed size={14} className="text-muted" aria-label={t("lab.status.pending")} />}
                                            </div>
                                        </button>
                                    </li>
                                );
                            }))}
                        </ul>
                    </section>
                ))}
            </div>
        </aside>
    );
}
