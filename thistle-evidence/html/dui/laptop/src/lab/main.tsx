import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { TranslationProvider } from "@/components/TranslationContext";
import LabApp from "./LabApp";
import BookingApp from "./BookingApp";
import AdminApp from "./AdminApp";
import FirearmTerminalApp from "./FirearmTerminalApp";
import { startBridge } from "./bridge";
import "./lab.css";

// The lab, the booking and firearm terminals and the admin panel share this resource's NUI page, which also does the page's other jobs (clipboard, date, key forwarding)
startBridge();

createRoot(document.getElementById("root")!).render(
    <StrictMode>
        <TranslationProvider>
            <LabApp />
            <BookingApp />
            <AdminApp />
            <FirearmTerminalApp />
        </TranslationProvider>
    </StrictMode>,
);
