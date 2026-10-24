export interface Observation {
    type: "ObservableCall" | "ObservableRadioFreq" | "ObservableSpyMicrophone";
    label?: string;
    channel?: number;
    targets?: {
        [playerId: number]: {
            playerId: number;
            name: string;
        }
    };
}