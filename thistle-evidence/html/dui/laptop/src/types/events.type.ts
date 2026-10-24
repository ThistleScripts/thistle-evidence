import type Citizen from "./citizen.type";
import type { BiometricEvidence } from "./evidence.type";
import type { Interception } from "./wiretap.type";


export interface InterceptionStoredEvent {
    interception: Interception;
}

export interface BiometricDataLinkedEvent {
    type: BiometricEvidence;
    identifier?: string;
    citizen: Citizen;
}