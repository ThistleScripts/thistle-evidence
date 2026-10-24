export interface Wiretap {
    type: "ObservableCall" | "ObservableRadioFreq" | "ObservableSpyMicrophone";
    startedAt: number;
    endedAt: number;
    observer: string;
    target: string;
    protocol?: string;
}

export type Interception = Wiretap & { id: number };