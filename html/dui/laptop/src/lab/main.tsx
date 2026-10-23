import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { TranslationProvider } from "@/components/TranslationContext";
import LabApp from "./LabApp";
import BookingApp from "./BookingApp";
import { startBridge } from "./bridge";
import "./lab.css";

// The lab and the booking terminal share this resource's NUI page, which also does the page's other jobs (clipboard, date, key forwarding)
startBridge();

createRoot(document.getElementById("root")!).render(
    <StrictMode>
        <TranslationProvider>
            <LabApp />
            <BookingApp />
        </TranslationProvider>
    </StrictMode>,
);
