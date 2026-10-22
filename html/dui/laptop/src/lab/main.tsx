import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { TranslationProvider } from "@/components/TranslationContext";
import LabApp from "./LabApp";
import { startBridge } from "./bridge";
import "./lab.css";

// The lab is this resource's NUI page, so it also does the page's other jobs (clipboard, date, key forwarding)
startBridge();

createRoot(document.getElementById("root")!).render(
    <StrictMode>
        <TranslationProvider>
            <LabApp />
        </TranslationProvider>
    </StrictMode>,
);
