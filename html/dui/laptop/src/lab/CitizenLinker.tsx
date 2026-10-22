import { useEffect, useState } from "react";
import { Link2, Search } from "lucide-react";
import { useTranslation } from "@/components/TranslationContext";
import { useDebounce } from "@/hooks/useDebounce";
import type Citizen from "@/types/citizen.type";
import { callServer } from "./server";
import type { Kind } from "./types";
import { Button } from "./ui";

interface CitizenLinkerProps {
    kind: Kind;
    biometricData: string;
    onLinked: () => void;
}

// Links an unmatched DNA profile or fingerprint to a citizen, so all evidence with it points to them
export default function CitizenLinker({ kind, biometricData, onLinked }: CitizenLinkerProps) {
    const { t } = useTranslation();
    const [searchText, setSearchText] = useState("");
    const debouncedSearchText = useDebounce(searchText, 300);
    const [citizens, setCitizens] = useState<Citizen[]>([]);
    const [linking, setLinking] = useState<string | null>(null);

    useEffect(() => {
        if (!debouncedSearchText) {
            setCitizens([]);
            return;
        }

        callServer<Citizen[]>("evidences:getCitizens", { searchText: debouncedSearchText, offset: 0 })
            .then(result => setCitizens(result.success && Array.isArray(result.response) ? result.response.slice(0, 5) : []));
    }, [debouncedSearchText]);

    const link = async (citizen: Citizen) => {
        setLinking(citizen.identifier);
        const result = await callServer("evidences:linkBiometricDataToIdentifier", { type: kind, biometricData, identifier: citizen.identifier });
        setLinking(null);

        if (result.success) onLinked();
    };

    return (
        <div className="space-y-2 pl-[38px]">
            <div className="relative">
                <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
                <input
                    className="th-input py-2 pl-9 pr-3 text-sm"
                    placeholder={t("lab.result.search_citizens")}
                    value={searchText}
                    onChange={event => setSearchText(event.target.value)}
                />
            </div>

            {citizens.length > 0 && (
                <ul className="overflow-hidden rounded-lg border border-line">
                    {citizens.map(citizen => (
                        <li key={citizen.identifier} className="flex items-center gap-3 border-t border-line/60 px-3 py-2 first:border-t-0">
                            <div className="min-w-0 flex-1">
                                <p className="truncate text-sm font-medium">{citizen.fullName}</p>
                                <p className="text-xs text-muted">{String(citizen.birthdate)}</p>
                            </div>
                            <Button variant="outline" className="px-2.5 py-1 text-xs" disabled={linking !== null} onClick={() => link(citizen)}>
                                <Link2 size={13} />
                                {t("lab.result.link_citizen")}
                            </Button>
                        </li>
                    ))}
                </ul>
            )}
        </div>
    );
}
