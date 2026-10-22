import { useState } from "react";
import { FolderSearch, Search } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { cn } from "@/utils/cn";
import { callServer } from "./server";
import type { CaseFile, Kind } from "./types";
import { Button, KindChip, Label } from "./ui";
import CaseFileView from "./CaseFileView";

const kinds: Kind[] = ["ballistics", "dna", "fingerprint"];

// Look up everything analysed for a gun ID, DNA profile or fingerprint
export default function CaseFiles() {
    const { t } = useTranslation();
    const [kind, setKind] = useState<Kind>("ballistics");
    const [key, setKey] = useState("");
    const [caseFile, setCaseFile] = useState<CaseFile | null>(null);
    const [searching, setSearching] = useState(false);

    const search = async () => {
        const trimmed = key.trim().toUpperCase();
        if (!trimmed) return;

        setSearching(true);
        const result = await callServer<CaseFile>("evidences:lab:getCaseFile", { kind, key: trimmed });
        setCaseFile(result.success && result.response ? result.response : null);
        setSearching(false);
    };

    return (
        <section className="th-scroll flex min-w-0 flex-1 flex-col gap-5 overflow-y-auto p-6">
            <div className="space-y-1">
                <h2 className="font-display text-2xl font-bold">{t("lab.case.title")}</h2>
                <p className="text-sm text-muted">{t("lab.case.hint")}</p>
            </div>

            <form className="flex flex-wrap items-end gap-3" onSubmit={event => { event.preventDefault(); search(); }}>
                <div className="space-y-1.5">
                    <Label>{t("lab.case.kind")}</Label>
                    <div className="flex gap-1 rounded-lg border border-line bg-surface p-1">
                        {kinds.map(option => (
                            <button key={option} type="button" onClick={() => { setKind(option); setCaseFile(null); }}
                                className={cn("cursor-pointer rounded-md px-1.5 py-1 transition-opacity", kind === option ? "bg-raised" : "opacity-50 hover:opacity-100")}>
                                <KindChip kind={option} />
                            </button>
                        ))}
                    </div>
                </div>

                <label className="min-w-[320px] flex-1 space-y-1.5">
                    <Label>{t(`lab.result.key.${kind}`)}</Label>
                    <div className="relative">
                        <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
                        <input className="th-input py-2.5 pl-9 pr-3 font-mono text-sm uppercase tracking-wider" maxLength={50}
                            placeholder={t("lab.case.key_placeholder")} value={key} onChange={event => setKey(event.target.value)} />
                    </div>
                </label>

                <Button type="submit" disabled={searching || !key.trim()}>{t("lab.case.search")}</Button>
            </form>

            {caseFile ? (
                <CaseFileView caseFile={caseFile} onChanged={search} />
            ) : (
                <div className="flex flex-1 flex-col items-center justify-center gap-3 text-muted">
                    <FolderSearch size={40} strokeWidth={1.25} className="opacity-50" />
                    <p className="text-sm">{t("lab.case.empty")}</p>
                </div>
            )}
        </section>
    );
}
