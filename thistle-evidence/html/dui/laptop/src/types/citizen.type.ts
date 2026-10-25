export default interface Citizen {
    identifier: string;
    fullName: string;
    birthdate: string | number;
    gender: string;
    flags?: CitizenFlag[]; // warnings on the record, when the server sends them (server/citizens/records.lua)
}

export interface CitizenFlag {
    id: number;
    flag: "wanted" | "armed" | "bail" | "warning";
    note: string;
    addedBy: string;
    addedAt: number;
}

export interface Gender {
    id: string;
    translationKey: string;
}

export const genders: Gender[] = [
    {
        id: "male",
        translationKey: "laptop.desktop_screen.citizens_app.gender.male"
    },
    {
        id: "female",
        translationKey: "laptop.desktop_screen.citizens_app.gender.female"
    },
    {
        id: "non_binary",
        translationKey: "laptop.desktop_screen.citizens_app.gender.non_binary"
    }
];