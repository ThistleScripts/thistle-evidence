import { useEffect, useState } from "react";
import { useTranslation } from "@/components/TranslationContext";
import EvidenceSidebar from "@/components/atoms/sidebar/EvidenceSidebar";
import type { Evidence, EvidenceDetails } from "@/types/evidence.type";
import EvidenceAnalysis from "@/components/atoms/EvidenceAnalysis";


export default function FingerprintApp() {
    const { t } = useTranslation();
    const [selectedEvidence, setSelectedEvidence] = useState<Evidence | null>(null);
    const [evidenceDetails, setEvidenceDetails] = useState<EvidenceDetails | null>(null);
    const [evidencesAvailable, setEvidencesAvailable] = useState<boolean>(false);

    const handleEvidenceSelection = (label: string, imagePath: string, inventory: number | string, slot: number, identifier: string, analysed: boolean, details: EvidenceDetails) => {
        setSelectedEvidence({
            label: label,
            imagePath: imagePath,
            inventory: inventory,
            slot: slot,
            identifier: identifier,
            analysed: analysed
        });
        setEvidenceDetails(details);
    };

    useEffect(() => {
        const handleMessage = (event: MessageEvent) => {
            if (event.data.action && event.data.action == "focus") {
                setSelectedEvidence(null);
            }
        };

        window.addEventListener("message", handleMessage);

        return () => window.removeEventListener("message", handleMessage);
    }, []);

    return <div className="w-full h-full px-4 pb-4 flex gap-4 bg-window">
        <EvidenceSidebar
            type="fingerprint"
            evidence={selectedEvidence}
            translations={{
                noItemsWithEvidences: t("laptop.desktop_screen.fingerprint_app.no_items_with_fingerprints")
            }}
            onEvidenceSelection={handleEvidenceSelection}
            onDataChange={setEvidencesAvailable}
        />

        {evidencesAvailable && <EvidenceAnalysis selectedEvidence={selectedEvidence} evidenceDetails={evidenceDetails} type="fingerprint" />}
    </div>;
}