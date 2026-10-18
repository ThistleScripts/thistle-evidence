import { useContext } from "react";
import { AppContext, type AppContextType } from "@/components/desktop/MoveableApp";

export function useAppContext(): AppContextType;
export function useAppContext(required: true): AppContextType;
export function useAppContext(required: false): AppContextType | undefined;

export function useAppContext(required: boolean = true) {
    const ctx = useContext(AppContext);
    if (!ctx && required) throw new Error("useAppContext must be used within an AppProvider");
    return ctx;
};