import { useTranslation } from "@/components/TranslationContext";
import { useEffect, useState } from "react";
import { useAppContext } from "./useAppContext";

interface useLuaCallbackProps<Request, Response> {
    name: string;
    defaultData?: Response;
    onRender?: () => void;
    onSuccess?: (data: Response, args: Request) => void;
    onError?: (message: string, args: Request) => void;
}


/**
 * React hook for triggering Lua server callbacks via HTTP.
 *
 * @template Request - Type of the request arguments sent to the server
 * @template Response - Type of the response returned by the server
 *
 * @param props.name Name of the Lua server callback to trigger
 * @param props.defaultData Optional default response data
 * @param props.onRender Optional callback executed once when the hook is mounted
 * @param props.onSuccess Optional callback executed when the request succeeds
 * @param props.onError Optional callback executed when the request fails
 *
 * @returns An object containing:
 * - data: The response data from the server
 * - loading: Indicates whether the request is in progress
 * - error: Indicates whether an error occurred
 * - trigger: Function to trigger the Lua server callback
 **/
export default function useLuaCallback<Request, Response>(props: useLuaCallbackProps<Request, Response>) {
    const appContext = useAppContext(false);
    const { t } = useTranslation();

    const [data, setData] = useState<Response | undefined>(props.defaultData || undefined);
    const [loading, setLoading] = useState<boolean>(false);
    const [error, setError] = useState<boolean>(false);


    useEffect(() => {
        if (props.onRender) props.onRender();
    }, []);
    

    const trigger = (args: Request) => {
        setLoading(true);
        setError(false);

        fetch(`https://${location.host}/triggerServerCallback`, {
            method: "post",
            headers: {
                "Content-Type": "application/json; charset=UTF-8",
            },
            body: JSON.stringify({
                name: props.name,
                arguments: {
                    ...args
                }
            })
        })
        .then(result => result.json()).then(result => {
            if ("success" in (result || {})) {
                if (result.success) {
                    setData(result.response);
                    props.onSuccess?.(result.response, args);
                    return;
                } else {
                    if (appContext) {
                        const translatedResponse = t(result.response);
                        if (translatedResponse != result.response) {
                            appContext.displayNotification({
                                type: "Error",
                                message: translatedResponse
                            });
                            return;
                        }
                    }

                    throw new Error(result.response || "Unknown error");
                }
            }

            setData(result);
            props.onSuccess?.(result, args);
        })
        .catch((err) => {
            setError(true)
            props.onError?.(err.message, args);
        })
        .finally(() => setLoading(false));
    }

    return { data, setData, loading, error, trigger }
}