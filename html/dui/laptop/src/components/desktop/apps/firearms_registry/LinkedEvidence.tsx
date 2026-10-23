import { useEffect } from "react";
import { FileSearch, Link2 } from "lucide-react";
import { useAppContext } from "@/hooks/useAppContext";
import { useTranslation } from "@/components/TranslationContext";
import useLuaCallback from "@/hooks/useLuaCallback";
import type { CaseFile } from "@/lab/types";

// Evidence analysed in the forensics lab that came from this gun (bullets and casings carry its ID)
export default function LinkedEvidence({ serial }: { serial: string }) {
    const { t } = useTranslation();
    const appContext = useAppContext();
    const { data: caseFile, trigger: fetchCaseFile, loading } = useLuaCallback<{ kind: "ballistics", key: string }, CaseFile>({
        name: "evidences:lab:getCaseFile"
    });

    useEffect(() => fetchCaseFile({ kind: "ballistics", key: serial }), [serial]);

    const matches = caseFile?.matches ?? [];

    return <div className="w-full flex flex-col gap-3 p-6 bg-raised/70 shadow-glass border-2 border-line rounded-16 max-h-[300px] min-h-0">
        <div className="flex items-center gap-2">
            <Link2 size={22} className="text-accent" />
            <p className="text-20 leading-none m-0 uppercase">{t("lab.links.title")}</p>
            <p className="text-20 leading-none text-muted">· {t("lab.links.count", matches.length)}</p>
            <div className="ml-auto flex items-center gap-2 px-2 py-1 rounded-10 hoverable hover:bg-accent/30" onClick={() => appContext.openApp("evidence", { kind: "ballistics", matchKey: serial })}>
                <FileSearch size={18} />
                <p className="text-20 leading-none">{t("laptop.desktop_screen.evidence_app.open_evidence")}</p>
            </div>
        </div>

        {loading
            ? <p className="text-25 text-muted">{t("laptop.desktop_screen.common.statuses.loading")}</p>
            : matches.length === 0
                ? <p className="text-25 text-muted">{t("lab.links.none")}</p>
                : <ul className="flex flex-col overflow-y-auto scrollbar min-h-0">
                    {matches.map(match => (
                        <li key={match.id} className="flex items-center gap-4 py-2 border-t-2 border-line/60 first:border-t-0">
                            <p className="text-25 leading-none w-[22%] truncate">{t(`lab.types.${match.evidenceType}`)}</p>
                            <p className="text-25 leading-none flex-1 truncate">{match.crimeScene || "-"}</p>
                            <p className="text-22.5 leading-none text-muted w-[28%] truncate text-right">{match.collectionTime || "-"}</p>
                        </li>
                    ))}
                </ul>
        }
    </div>
}
