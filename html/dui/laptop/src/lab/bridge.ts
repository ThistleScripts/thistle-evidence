import { resourceName } from "@/hooks/useLuaCallback";

export const post = (name: string, body: object) => fetch(`https://${resourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(body)
}).catch(() => {});

// What html/nui used to do before the lab became the NUI page.
export function startBridge() {
    // Keys and pastes are forwarded to the client for the laptop DUI and the fingerprint scanner
    // (https://github.com/citizenfx/fivem/pull/2195#issuecomment-1712832684)
    window.addEventListener("keydown", (event) => {
        if (event.ctrlKey) return;
        post("keydown", { key: event.key });
    });

    window.addEventListener("paste", (event) => {
        const clipboard = event.clipboardData?.getData("Text");
        if (clipboard) post("paste", { clipboard });
    });

    window.addEventListener("message", (event) => {
        const data = event.data;
        if (!data?.action) return;

        if (data.action === "getDateTime") {
            const date = new Date().toLocaleDateString(data.dateLocales, { day: "numeric", month: "numeric", year: "numeric", hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false });
            post("dateTimeCallback", { date });
            return;
        }

        // https://github.com/project-error/npwd/blob/d8dc5b7f47faf5fc581ffee30f31ff61d184cfe7/phone/src/os/phone/hooks/useClipboard.ts
        if (data.action === "copyToClipboard") {
            const input = document.createElement("input");
            input.value = data.value;
            document.body.appendChild(input);
            input.select();
            document.execCommand("copy");
            document.body.removeChild(input);
        }
    });
}

export const closeLab = () => post("lab:close", {});
