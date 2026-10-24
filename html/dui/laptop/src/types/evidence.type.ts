export type BiometricEvidence = "fingerprint" | "dna";
export type BallisticsEvidence = "ballistics";
export type EvidenceType = BiometricEvidence | BallisticsEvidence;

export interface Evidence {
    label: string;
    imagePath: string;
    inventory: number | string;
    slot: number;
    identifier: string;
    analysed: boolean;
}

export interface EvidenceDetails {
    createdAt: number;
    identifier: string;
    analysed: boolean;
    collectionTime: string;
    crimeScene: string;
    additionalData: string;
}
