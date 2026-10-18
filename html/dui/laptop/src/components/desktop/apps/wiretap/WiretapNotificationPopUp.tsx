import { useEffect, useState } from "react";
import useLuaCallback from "@/hooks/useLuaCallback";
import { useTranslation } from "@/components/TranslationContext";
import { useAppContext } from "@/hooks/useAppContext";

export default function WiretapNotificationPopUp() {
    const { t } = useTranslation();
    const appContext = useAppContext();
    const [input, setInput] = useState<string>("");
    const [subscribedTarget, setSubscribedTarget] = useState<string>("");
    const [isSubscribed, setSubscribed] = useState<boolean>(false);

    const {loading, trigger: triggerGetSubscription} = useLuaCallback<void, string>({
        name: "evidences:getSubscriptionTarget",
        onSuccess: (data) => {
            setInput(data);

            if (data) {
                setSubscribedTarget(data);
                setSubscribed(true);
            }
        }
    });

    const {trigger: subscribe} = useLuaCallback<{ target: string | null }, void>({
        name: "evidences:subscribe",
        onSuccess: (_, args) => appContext.displayNotification({
            type: "Success",
            message: args.target
                ? t("laptop.desktop_screen.wiretap_app.phone_calls.notifications.status_messages.subscribed")
                : t("laptop.desktop_screen.wiretap_app.phone_calls.notifications.status_messages.unsubscribed")
        })
    }); 

    useEffect(triggerGetSubscription, []);

    const sendNotifications = (target: string | null) => {
        if (!target) {
            setInput("");
            setSubscribedTarget("");
            setSubscribed(false);
        } else {
            setSubscribedTarget(target);
            setSubscribed(true);
        }

        subscribe({target: target});
    };

    const unsubscribed_placeholder = appContext.options?.displayPhoneNumbers ? "placeholder_phone_number" : "placeholder_full_name";
    const unsubscribed_translation = t(`laptop.desktop_screen.wiretap_app.phone_calls.notifications.${unsubscribed_placeholder}`);

    return <div className="w-full h-full justify-center items-center p-4 flex flex-col gap-4 bg-window">
        <div className = "w-[60%] h-full flex flex-col justify-evenly items-center">
            {loading && <p className="text-30 leading-none italic">{t("laptop.desktop_screen.common.statuses.loading")}</p>}
            {!loading && (<>
                {isSubscribed
                    ? <p className="text-30 leading-none">{t("laptop.desktop_screen.wiretap_app.phone_calls.notifications.status_subscribed", subscribedTarget)}</p>
                    : <p className="text-30 leading-none">{t("laptop.desktop_screen.wiretap_app.phone_calls.notifications.status_unsubscribed", unsubscribed_translation)}</p>
                }
                <input
                    className="input textable"
                    maxLength={35}
                    placeholder={unsubscribed_translation}
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                />
                <div className="flex gap-4">
                    <button
                        className="flex px-4 py-2 border-none rounded-10 text-white duration-400 text-30 leading-7 hover:-translate-y-0.5 hover:shadow-button bg-[rgb(0,136,255)] hoverable"
                        onClick={() => sendNotifications(input)}>{t("laptop.desktop_screen.wiretap_app.phone_calls.notifications.subscribe_button")}
                    </button>
                    <button
                        className="flex px-4 py-2 border-none rounded-10 text-white duration-400 text-30 leading-7 hover:-translate-y-0.5 hover:shadow-button bg-[rgb(72,72,74)] hoverable"
                        onClick={() => sendNotifications(null)}>{t("laptop.desktop_screen.wiretap_app.phone_calls.notifications.unsubscribe_button")}
                    </button>
                </div>
            </>)}
        </div>
    </div>
}