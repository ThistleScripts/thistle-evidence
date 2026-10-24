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
                details: { evidence: [{ kind: "fingerprint", evidenceType: "fingerprint", analysed: false, crimeScene: "Vespucci Blvd", vehicleLocation: "Steering wheel (front driver's seat)", plate: "46EEK572", collectionTime: "21/10/2026, 18:02", additionalData: "", quality: 34 }] }
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
    fingerprint: { kind: "fingerprint", key: "9F3A11C07BD24E58", citizen: { identifier: "XYZ789", fullName: "Rosa Lindqvist", birthdate: "1988-07-02", gender: "female" }, matches: [
        { id: 7, kind: "fingerprint", matchKey: "9F3A11C07BD24E58", evidenceType: "fingerprint", crimeScene: "Vespucci Blvd", vehicleLocation: "Steering wheel (front driver's seat)", plate: "46EEK572", collectionTime: "21/10/2026, 18:02", analysedAt: Date.now() - 600e3, analysedBy: "Ofc. Grant" },
        { id: 6, kind: "fingerprint", matchKey: "9F3A11C07BD24E58", evidenceType: "fingerprint", crimeScene: "Little Seoul", vehicleLocation: "Front driver's door", plate: "46EEK572", collectionTime: "19/10/2026, 02:41", analysedAt: Date.now() - 86400e3, analysedBy: "Det. Morgan" }
    ] }
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
            // a degraded sample: a partial print with a few possible citizens
            if ((analysed.quality ?? 100) < 50) {
                const partial = { ...analysed, result: "partial" as const, partialKey: "9F3•••••••••••58" };
                return { success: true, response: { evidence: partial, caseFile: { kind: args.kind, result: "partial", candidates: [
                    { identifier: "XYZ789", fullName: "Rosa Lindqvist", birthdate: "1988-07-02", gender: "female" },
                    { identifier: "ABC123", fullName: "Jamie Doyle", birthdate: "1994-03-11", gender: "male" },
                    { identifier: "DEF456", fullName: "Marcus Hale", birthdate: "1979-11-23", gender: "male" }
                ] } } as T };
            }
            const typeOnly = analysed.evidenceType === "gunshot_residue" || analysed.evidenceType === "magazine";
            if (!typeOnly) analysed.key = caseFile.key;
            return { success: true, response: { evidence: analysed, caseFile: typeOnly ? { kind: args.kind } : caseFile } as T };
        }
        case "evidences:lab:getCaseFile":
            return { success: true, response: (caseFiles[args.kind] ?? { kind: args.kind, key: args.key, matches: [] }) as T };
        case "evidences:getCitizens":
            return { success: true, response: [{ identifier: "ABC123", fullName: "Jamie Doyle", birthdate: "1994-03-11", gender: "male" }] as T };
        case "evidences:getBiometricDataLinkedToIdentifier":
            return { success: true, response: { fingerprint: "FP7Q2W9E4R1T6Y3U" } as T };
        case "evidences:getPlayersItemsWithEvidence":
            return { success: true, response: [{ inventory: 1, label: "Pockets", items: args.type === "dna"
                ? [{ slot: 7, label: "Collected Saliva", imagePath: image("Swab"), details: { identifier: "GATTACAGCTAGCTAA" } }]
                : [{ slot: 8, label: "Collected Fingerprint", imagePath: image("Print"), details: { identifier: "FP7Q2W9E4R1T6Y3U" } }] }] as T };
        case "evidences:getNotes":
            return { success: true, response: [{ id: 1, identifier: "ABC123", modifiedAt: Date.now() - 3600e3, modifiedBy: "Ofc. Grant", title: "Booked for armed robbery", text: "Arrested at Davis Ave. Fingerprints and swab taken on booking." }] as T };
        case "evidences:admin:get":
            return { success: true, response: {
                enabled: true,
                capabilities: [
                    { key: "laptop", group: "laptop" }, { key: "app_citizens", group: "laptop", needs: "laptop" }, { key: "app_firearms", group: "laptop", needs: "laptop" },
                    { key: "app_evidence", group: "laptop", needs: "laptop" }, { key: "app_cases", group: "laptop", needs: "laptop" }, { key: "app_wiretap", group: "laptop", needs: "laptop" },
                    { key: "microscope", group: "lab" }, { key: "collect", group: "field" }, { key: "swab", group: "field" }, { key: "fingerprints", group: "field" },
                    { key: "uv_flashlight", group: "equipment" }, { key: "uv_lamps", group: "equipment" }, { key: "markers", group: "equipment" }, { key: "lockers", group: "equipment" }
                ],
                defaults: { laptop: false, app_citizens: true, app_firearms: true, app_evidence: true, app_cases: true, app_wiretap: false, microscope: false,
                    collect: true, swab: true, fingerprints: true, uv_flashlight: true, uv_lamps: true, markers: true, lockers: true },
                officers: [
                    { identifier: "ABC12345", name: "Det. Sarah Shaw", capabilities: { laptop: true, microscope: true, app_wiretap: true }, updatedBy: "Kieran Grant", updatedAt: Date.now() - 864e5 },
                    { identifier: "QWE98765", name: "Ofc. Tom Reilly", capabilities: { collect: false }, updatedBy: "Kieran Grant", updatedAt: Date.now() - 36e5 }
                ],
                online: [{ identifier: "ZXC44556", name: "Ofc. Priya Nair", serverId: 14 }, { identifier: "ABC12345", name: "Det. Sarah Shaw", serverId: 3 }]
            } as T };
        case "evidences:admin:getGroundEvidence":
            return { success: true, response: {
                types: ["blood", "bullet", "casing", "fingerprint", "footprint", "gunshot_residue", "magazine", "saliva", "tyre_mark"],
                counts: { blood: 212, bullet: 64, casing: 301, fingerprint: 88, footprint: 57, tyre_mark: 49, magazine: 4 }
            } as T };
        case "evidences:admin:clearGroundEvidence":
            return { success: true, response: (args.evidenceType ? 64 : 775) as T };
        default:
            return { success: true };
    }
}
