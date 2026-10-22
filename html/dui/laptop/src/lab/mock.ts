// Sample data so the lab can be previewed in a normal browser (outside the game). Never used in game.
import type { ServerResult } from "./server";
import type { CaseFile, LabInventory } from "./types";

const image = (name: string) => "data:image/svg+xml," + encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><rect width="96" height="96" rx="12" fill="#191d28"/><text x="48" y="54" font-family="sans-serif" font-size="14" fill="#a855f7" text-anchor="middle">${name}</text></svg>`
);

const evidence: LabInventory[] = [
    {
        inventory: 1,
        label: "Pockets",
        items: [
            {
                imagePath: image("Bullet"), label: "Collected Bullet", slot: 4,
                details: { evidence: [{ kind: "ballistics", evidenceType: "bullet", analysed: false, weaponType: "Pistol", crimeScene: "Strawberry Ave – Davis Ave", collectionTime: "22/10/2026, 21:14", additionalData: "" }] }
            },
            {
                imagePath: image("Blood"), label: "Collected Blood", slot: 5,
                details: { evidence: [{ kind: "dna", evidenceType: "blood", analysed: true, key: "GATTACAGCTAGCTAA", crimeScene: "Grove Street", collectionTime: "22/10/2026, 20:58", additionalData: "Found by the back door" }] }
            }
        ]
    },
    {
        inventory: "box-1",
        label: "Case #0412",
        items: [
            {
                imagePath: image("Casing"), label: "Collected Casing", slot: 1,
                details: { evidence: [{ kind: "ballistics", evidenceType: "casing", analysed: false, weaponType: "Pistol", crimeScene: "Strawberry Ave – Davis Ave", collectionTime: "22/10/2026, 21:15", additionalData: "" }] }
            },
            {
                imagePath: image("Print"), label: "Collected Fingerprint", slot: 2,
                details: { evidence: [{ kind: "fingerprint", evidenceType: "fingerprint", analysed: false, crimeScene: "Vespucci Blvd", collectionTime: "21/10/2026, 18:02", additionalData: "" }] }
            },
            {
                imagePath: image("Residue"), label: "Collected Gunshot Residue", slot: 3,
                details: { evidence: [{ kind: "ballistics", evidenceType: "gunshot_residue", analysed: false, weaponType: "Pistol", weaponImage: image("Pistol"), createdAt: Date.now() / 1000 - 600, crimeScene: "", collectionTime: "22/10/2026, 21:20", additionalData: "" }] }
            }
        ]
    }
];

const caseFiles: Record<string, CaseFile> = {
    ballistics: {
        kind: "ballistics", key: "482913KQZ771204",
        firearm: { serial: "482913KQZ771204", label: "Pistol", imagePath: image("Pistol"), identifier: "ABC123", registeredBy: "Ofc. Grant", registeredAt: Date.now() - 86400000 * 12, reason: "Personal protection", status: "stolen" },
        citizen: { identifier: "ABC123", fullName: "Jamie Doyle", birthdate: "1994-03-11", gender: "male" },
        matches: [
            { id: 3, kind: "ballistics", matchKey: "482913KQZ771204", evidenceType: "bullet", weaponType: "Pistol", crimeScene: "Strawberry Ave – Davis Ave", collectionTime: "22/10/2026, 21:14", analysedAt: Date.now(), analysedBy: "Ofc. Grant" },
            { id: 2, kind: "ballistics", matchKey: "482913KQZ771204", evidenceType: "casing", weaponType: "Pistol", crimeScene: "Little Seoul", collectionTime: "19/10/2026, 02:41", analysedAt: Date.now() - 86400000 * 3, analysedBy: "Det. Reyes" },
            { id: 1, kind: "ballistics", matchKey: "482913KQZ771204", evidenceType: "bullet", weaponType: "Pistol", crimeScene: "Mirror Park", collectionTime: "14/10/2026, 23:09", analysedAt: Date.now() - 86400000 * 8, analysedBy: "Det. Reyes" }
        ]
    },
    dna: { kind: "dna", key: "GATTACAGCTAGCTAA", matches: [{ id: 4, kind: "dna", matchKey: "GATTACAGCTAGCTAA", evidenceType: "blood", crimeScene: "Grove Street", collectionTime: "22/10/2026, 20:58", analysedAt: Date.now(), analysedBy: "Ofc. Grant" }] },
    fingerprint: { kind: "fingerprint", key: "9F3A11C07BD24E58", citizen: { identifier: "XYZ789", fullName: "Rosa Lindqvist", birthdate: "1988-07-02", gender: "female" }, matches: [] }
};

export async function mockCallback<T>(name: string, args: any): Promise<ServerResult<T>> {
    await new Promise(resolve => setTimeout(resolve, 250));

    switch (name) {
        case "evidences:lab:getEvidence":
            return { success: true, response: evidence as T };
        case "evidences:lab:analyse": {
            const caseFile = caseFiles[args.kind]!;
            const item = evidence.flatMap(inventory => inventory.items).find(item => item.slot === args.slot && item.details.evidence[0]?.kind === args.kind);
            const analysed = { ...item!.details.evidence[0]!, analysed: true };
            const typeOnly = analysed.evidenceType === "gunshot_residue" || analysed.evidenceType === "magazine";
            if (!typeOnly) analysed.key = caseFile.key;
            return { success: true, response: { evidence: analysed, caseFile: typeOnly ? { kind: args.kind } : caseFile } as T };
        }
        case "evidences:lab:getCaseFile":
            return { success: true, response: (caseFiles[args.kind] ?? { kind: args.kind, key: args.key, matches: [] }) as T };
        case "evidences:getCitizens":
            return { success: true, response: [{ identifier: "ABC123", fullName: "Jamie Doyle", birthdate: "1994-03-11", gender: "male" }] as T };
        default:
            return { success: true };
    }
}
