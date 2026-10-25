import type Citizen from "@/types/citizen.type";
import type { RegisteredFirearm } from "@/types/firearm.type";

export type Kind = "dna" | "fingerprint" | "ballistics";

export interface LabEvidence {
    kind: Kind;
    evidenceType: string; // blood, saliva, fingerprint, bullet, casing, magazine, gunshot_residue, or an item name
    negative?: boolean; // a gunshot residue swab that found none
    analysed: boolean;
    result?: "full" | "partial" | "failed"; // how much the first analysis could read (config.evidenceAging)
    quality?: number; // the sample's condition, 0-100
    key?: string; // only once analysed, and only for a full result
    partialKey?: string; // a partial print or DNA profile, partly masked
    createdAt?: number;
    weaponType?: string;
    weaponImage?: string;
    crimeScene: string;
    vehicleLocation?: string; // where in a vehicle it was found, e.g. "Steering wheel (front driver's seat)"
    plate?: string;
    collectionTime: string;
    additionalData: string;
}

export interface LabItem {
    imagePath: string;
    label: string;
    slot: number;
    details: { evidence: LabEvidence[] };
}

export interface LabInventory {
    inventory: number | string;
    label: string;
    items: LabItem[];
}

export interface ForensicMatch {
    id: number;
    kind: Kind;
    matchKey: string;
    evidenceType: string;
    weaponType?: string;
    crimeScene?: string;
    vehicleLocation?: string;
    plate?: string;
    collectionTime?: string;
    collectedAt?: number;
    analysedAt: number;
    analysedBy: string;
}

export interface CaseFile {
    kind: Kind;
    result?: "full" | "partial" | "failed";
    candidates?: Citizen[]; // possible matches for a partial print or DNA profile
    key?: string;
    firearm?: RegisteredFirearm;
    citizen?: Citizen;
    matches?: ForensicMatch[];
}

export interface Selection {
    inventory: number | string;
    item: LabItem;
    evidence: LabEvidence;
}
