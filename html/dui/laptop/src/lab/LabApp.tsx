import { useCallback, useEffect, useState } from "react";
import { FolderSearch, Microscope, X } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { cn } from "@/utils/cn";
import { closeLab } from "./bridge";
import { callServer, inGame } from "./server";
import type { LabInventory, Selection } from "./types";
import EvidenceTray from "./EvidenceTray";
import AnalysisBench from "./AnalysisBench";
import CaseFiles from "./CaseFiles";

type Tab = "analysis" | "case_files";

export default function LabApp() {
    const { t, setLang } = useTranslation();
    const [visible, setVisible] = useState(!inGame);
    const [officer, setOfficer] = useState("");
    const [brand, setBrand] = useState("Thistle Evidence"); // "<config.cityName> Evidence", sent by the client
    const [tab, setTab] = useState<Tab>("analysis");
    const [inventories, setInventories] = useState<LabInventory[]>([]);
    const [loading, setLoading] = useState(false);
    const [selection, setSelection] = useState<Selection | null>(null);

    const loadEvidence = useCallback(async () => {
        setLoading(true);
        const result = await callServer<LabInventory[]>("evidences:lab:getEvidence");
        setInventories(result.success && Array.isArray(result.response) ? result.response : []);
        setLoading(false);
    }, []);

    useEffect(() => {
        const onMessage = (event: MessageEvent) => {
            const data = event.data;

            if (data?.action === "openLab") {
                if (data.language) setLang(data.language);
                setOfficer(data.playerName || "");
                if (data.brand) setBrand(data.brand);
                setSelection(null);
                setTab("analysis");
                setVisible(true);
                loadEvidence();
            } else if (data?.action === "closeLab") {
                setVisible(false);
            }
        };

        const onKeyDown = (event: KeyboardEvent) => {
            if (event.key === "Escape") closeLab();
        };

        window.addEventListener("message", onMessage);
        window.addEventListener("keydown", onKeyDown);

        if (!inGame) loadEvidence();

        return () => {
            window.removeEventListener("message", onMessage);
            window.removeEventListener("keydown", onKeyDown);
        };
    }, [loadEvidence]);

    // Keep the selected evidence in step with the server's copy after an analysis
    const onAnalysed = (updated: Selection) => {
        setSelection(updated);
        setInventories(current => current.map(inventory => inventory.inventory !== updated.inventory ? inventory : {
            ...inventory,
            items: inventory.items.map(item => item.slot !== updated.item.slot ? item : {
                ...item,
                details: { evidence: item.details.evidence.map(evidence => evidence.kind === updated.evidence.kind ? updated.evidence : evidence) }
            })
        }));
    };

    if (!visible) return null;

    const tabs: { id: Tab; icon: typeof Microscope }[] = [
        { id: "analysis", icon: Microscope },
        { id: "case_files", icon: FolderSearch }
    ];

    return (
        <div className={cn("flex h-full w-full items-center justify-center p-8", !inGame && "bg-[#2a2f3a]")}>
            <div className="th-panel th-grain animate-th-rise relative flex h-[min(860px,100%)] w-[min(1440px,100%)] flex-col overflow-hidden rounded-xl border border-line">
                <header className="relative z-10 flex items-center gap-6 border-b border-line px-6 py-4">
                    <div className="flex items-center gap-3">
                        <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-accent/15 text-accent">
                            <Microscope size={22} />
                        </div>
                        <div>
                            <p className="th-label text-accent">{brand}</p>
                            <h1 className="font-display text-xl font-black leading-tight">{t("lab.title")}</h1>
                        </div>
                    </div>

                    <nav className="flex gap-1 rounded-lg border border-line bg-surface p-1">
                        {tabs.map(({ id, icon: Icon }) => (
                            <button
                                key={id}
                                type="button"
                                onClick={() => setTab(id)}
                                className={cn(
                                    "flex cursor-pointer items-center gap-2 rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
                                    tab === id ? "bg-raised text-ink" : "text-muted hover:text-ink"
                                )}
                            >
                                <Icon size={15} />
                                {t(`lab.tabs.${id}`)}
                            </button>
                        ))}
                    </nav>

                    <div className="ml-auto flex items-center gap-4">
                        {officer && <p className="text-sm text-muted">{t("lab.officer", officer)}</p>}
                        <button type="button" title={t("lab.close")} onClick={closeLab} className="cursor-pointer rounded-md border border-line p-2 text-muted transition-colors hover:border-accent hover:text-accent">
                            <X size={16} />
                        </button>
                    </div>
                </header>

                <main className="relative z-10 flex min-h-0 flex-1">
                    {tab === "analysis" ? (
                        <>
                            <EvidenceTray
                                inventories={inventories}
                                loading={loading}
                                selection={selection}
                                onSelect={setSelection}
                                onRefresh={loadEvidence}
                            />
                            <AnalysisBench key={selection ? `${selection.inventory}-${selection.item.slot}-${selection.evidence.kind}` : "none"} selection={selection} onAnalysed={onAnalysed} />
                        </>
                    ) : (
                        <CaseFiles />
                    )}
                </main>
            </div>
        </div>
    );
}
