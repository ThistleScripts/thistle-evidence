import type React from "react";
import { ScrollText, Users, AudioLines, FileSearch, FolderKanban, type LucideIcon } from "lucide-react";
import CitizensApp from "@/components/desktop/apps/citizens/CitizensApp";
import FirearmsRegistryApp from "@/components/desktop/apps/firearms_registry/FirearmsRegistryApp";
import WiretapApp from "@/components/desktop/apps/wiretap/WiretapApp";
import EvidenceApp from "@/components/desktop/apps/evidence/EvidenceApp";
import CasesApp from "@/components/desktop/apps/cases/CasesApp";
import { useTranslation } from "@/components/TranslationContext";

export interface AppPosition {
    col: number;
    row: number;
}

export interface App {
    id: string;
    name: string;
    position: AppPosition;
    icon: (width: string, height: string) => React.ReactNode;
    content: (props?: any) => React.ReactNode;
}

// Thistle-style app tile: a Lucide icon on a tinted rounded square
const tile = (Icon: LucideIcon, className: string) => (width: string, height: string) => (
    <div style={{ width, height }} className={`flex shrink-0 items-center justify-center rounded-[22%] border-2 ${className}`}>
        <Icon style={{ width: "55%", height: "55%" }} strokeWidth={1.75} />
    </div>
);

export const AppsList = (): App[] => {
    const { t } = useTranslation();

    return [
        {
            id: "citizens",
            name: t("laptop.desktop_screen.citizens_app.name"),
            position: { col: 1, row: 1 },
            icon: tile(Users, "bg-info/15 border-info/40 text-info"),
            content: (props) => <CitizensApp {...props} />
        },
        {
            id: "firearms_registry",
            name: t("laptop.desktop_screen.firearms_registry_app.name"),
            position: { col: 1, row: 2 },
            icon: tile(ScrollText, "bg-warn/15 border-warn/40 text-warn"),
            content: (props) => <FirearmsRegistryApp {...props} />
        },
        {
            id: "evidence",
            name: t("laptop.desktop_screen.evidence_app.name"),
            position: { col: 1, row: 3 },
            icon: tile(FileSearch, "bg-accent/15 border-accent/40 text-accent"),
            content: (props) => <EvidenceApp {...props} />
        },
        {
            id: "cases",
            name: t("laptop.desktop_screen.cases_app.name"),
            position: { col: 2, row: 1 },
            icon: tile(FolderKanban, "bg-ok/15 border-ok/40 text-ok"),
            content: (props) => <CasesApp {...props} />
        },
        {
            id: "wiretap",
            name: t("laptop.desktop_screen.wiretap_app.name"),
            position: { col: 1, row: 4 },
            icon: tile(AudioLines, "bg-bad/15 border-bad/40 text-bad"),
            content: (props) => <WiretapApp {...props} />
        }
    ];
};
