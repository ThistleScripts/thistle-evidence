import { resourceName } from "@/hooks/useLuaCallback";
import { mockCallback } from "./mock";

export interface ServerResult<T> {
    success: boolean;
    response?: T;
}

export const inGame = typeof (window as any).GetParentResourceName === "function";

// Calls a server callback through the client (client/dui/dui.lua). Callbacks that don't answer
// with { success, response } are treated as a successful response.
export async function callServer<T>(name: string, args: object = {}): Promise<ServerResult<T>> {
    if (!inGame) return mockCallback<T>(name, args);

    try {
        const result = await fetch(`https://${resourceName()}/triggerServerCallback`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify({ name, arguments: args })
        }).then(response => response.json());

        if (result && typeof result === "object" && "success" in result) return result;
        return { success: true, response: result };
    } catch {
        return { success: false };
    }
}
