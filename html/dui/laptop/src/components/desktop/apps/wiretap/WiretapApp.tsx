import { useEffect, useRef, useState } from "react";
import InterceptionChooser from "./InterceptionChooser";
import { useAppContext } from "@/hooks/useAppContext";
import RunningWiretap from "./RunningWiretap";
import { useTranslation } from "@/components/TranslationContext";
import useLocalStorage from "@/hooks/useLocalStorage";
import { sha256 } from "@/utils/hash";
import WiretapNotificationPopUp from "./WiretapNotificationPopUp";
import type { Observation } from "@/types/observation.type";
import useLuaCallback from "@/hooks/useLuaCallback";

export default function WiretapApp() {
    const { t } = useTranslation();
    const appContext = useAppContext();

    const [displayPopUp, setDisplayPopUp] = useLocalStorage<string>("evidences_wiretapapp_warning", "");
    const [computetHash, setComputetHash] = useState<string | undefined>(undefined);

    const [activeCalls, setActiveCalls] = useState<{ [channel: number]: Observation }>({});
    const [spyMicrophones, setSpyMicrophones] = useState<{ [label: string]: Observation }>({});

    const observation = useRef<Observation | null>(null);
    const [radioFrequency, setRadioFrequency] = useState<string>("");

    useEffect(() => {
        async function runHashing() {
            const hashed = await sha256(t("laptop.desktop_screen.wiretap_app.warning_popup.warning"));
            setComputetHash(hashed)
        }
        runHashing();
    }, []);

    const openNotificationsPopup = () => {
        appContext.openPopUp(t("laptop.desktop_screen.wiretap_app.phone_calls.notifications.popup_header"), <WiretapNotificationPopUp />);
    };

    const startInterception = (newObservation: Observation) => {
        observation.current = newObservation;

        appContext.openPopUp(t(`laptop.desktop_screen.wiretap_app.running_observation_popup.${newObservation.type}`, newObservation.channel ?? newObservation.label ?? ""), <RunningWiretap observation={newObservation} onClose={(success) => {
            observation.current = null;
            
            if (success) {
                appContext.displayNotification({ type: "Success", message: t("laptop.desktop_screen.wiretap_app.running_observation_popup.status_messages.protocol_save_success") });
            } else {
                appContext.displayNotification({ type: "Error", message: t("laptop.desktop_screen.wiretap_app.running_observation_popup.status_messages.protocol_save_error") });
            }
        }} />);

        // Set the current observation to null, if all participants left the call
        // This prevents further updates to the RunningWiretap popup
        if (observation.current.type == "ObservableCall" && Object.keys(newObservation.targets!).length == 0) {
            observation.current = null;
        }
    };

    useEffect(() => {
        if (observation.current && observation.current.type == "ObservableCall") {
            const updatedObservation = observation.current.channel! in activeCalls   // Check if currently observed call is in updated activeCalls (= has not ended)
                ? activeCalls[observation.current.channel!]                          // If so, use the new call from the list (-> update participants in popup)
                : { ...observation.current, targets: {} };                           // Else, use the previous state of the call, but clear the list of participants
            
            if (!updatedObservation) return;
            startInterception(updatedObservation);
        }
    }, [activeCalls]);

    const startRadioObservation = () => {
        const frequency = parseFloat(radioFrequency);

        if (isNaN(frequency) || !isFinite(frequency)) return;

        const observation: Observation = {
            type: "ObservableRadioFreq",
            channel: frequency,
            targets: []
        }

        startObservation(observation);
    };

    const startObservation = (newObservation: Observation) => {
        if (observation.current) return;
        startInterception(newObservation);
    }

    const { trigger: retrieveActiveCalls, loading: loadingActiveCalls } = useLuaCallback<void, { [channel: number]: Observation }>({
        name: "evidences:getActiveCalls",
        onSuccess: (data) => {
            if (!data) return;

            const filteredCalls = Object.values(data as Record<string, Observation | null>).filter((call: Observation | null): call is Observation => call !== null);
            setActiveCalls(filteredCalls);
        }
    });

    const { trigger: retrieveSpyMicrophones, loading: loadingSpyMicrophones } = useLuaCallback<void, { [label: string]: Observation }>({
        name: "evidences:getSpyMicrophones",
        onSuccess: (data) => data && setSpyMicrophones(data)
    });

    useEffect(() => {
        retrieveActiveCalls();
        retrieveSpyMicrophones();

        const handleMessage = (event: MessageEvent) => {
            // Retrieve updates regarding the active calls
            if (event.data.action && event.data.action == "updateActiveCalls") {
                if (event.data.activeCalls) {
                    const filteredCalls = event.data.activeCalls.filter((call: Observation | null): call is Observation => call !== null);
                    setActiveCalls(filteredCalls);
                }
            }
            
            // Retrieve updates regarding the spy microphones
            if (event.data.action && event.data.action == "updateSpyMicrophones") {
                if (event.data.spyMicrophones) setSpyMicrophones(event.data.spyMicrophones);
            }
        };

        window.addEventListener("message", handleMessage);

        return () => window.removeEventListener("message", handleMessage);
    }, []);

    const handleRadioFrequencyChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const decimalRegex = /(\d*\.\d+|\d+\.?\d*)/;
        const match = e.target.value.match(decimalRegex);

        setRadioFrequency(match ? match[0] : "");
    };

    if (!computetHash) {
        return <div className="w-full h-full flex bg-window"></div>
    }

    return <div className="w-full h-full flex bg-window">
        {displayPopUp != computetHash && <div className="absolute w-full h-full bg-white/50 z-5 flex justify-center items-center">
            <div className="p-8 w-[75%] bg-white shadow-glass border-2 border-white/80 rounded-16">
                <div className="w-full flex gap-4">
                    <div className="pr-4">
                        <svg xmlns="http://www.w3.org/2000/svg" width="75px" height="75px" viewBox="0 -960 960 960" fill="#ff8800ff"><path d="m40-120 440-760 440 760H40Zm138-80h604L480-720 178-200Zm302-40q17 0 28.5-11.5T520-280q0-17-11.5-28.5T480-320q-17 0-28.5 11.5T440-280q0 17 11.5 28.5T480-240Zm-40-120h80v-200h-80v200Zm40-100Z"/></svg>
                    </div>
                    <div className="flex flex-col gap-3">
                        <p className="text-30 font-bold">{t("laptop.desktop_screen.wiretap_app.warning_popup.title")}</p>
                        <div className="flex flex-col">
                            {t("laptop.desktop_screen.wiretap_app.warning_popup.warning").split("\n").map((line) =>
                                <p className="text-30 leading-none">{line}</p>
                            )}
                        </div>
                    </div>
                </div>
                <div className="w-full flex justify-center mt-4">
                    <button onClick={() => setDisplayPopUp(computetHash)} className="border-2 rounded-10 flex justify-center items-center p-1 hover:bg-button text-30 leading-7 hoverable">{t("laptop.desktop_screen.wiretap_app.warning_popup.accept_button")}</button>
                </div>
            </div>
        </div>}
        <div className="w-full h-full flex gap-4 p-4">
            <div className="w-1/2 h-full flex flex-col gap-4">
                <div className="w-full grow flex flex-col gap-4 min-h-0">
                    <div className="w-full h-1/2 p-6 flex flex-col gap-2 bg-white/20 shadow-glass border-2 border-white/80 rounded-16 overflow-hidden">
                        <div className="w-full flex justify-between items-center -mt-1">
                            <p className="text-20 leading-none m-0 uppercase">{t("laptop.desktop_screen.wiretap_app.phone_calls.header")}</p>
                            
                            {appContext.options?.mayInterceptCalls &&
                                <div className="rounded-10 flex justify-center items-center p-1 hover:bg-button hoverable" onClick={openNotificationsPopup}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="20px" width="20px" fill="black" viewBox="0 -960 960 960"><path d="M160-200v-80h80v-280q0-83 50-147.5T420-792v-28q0-25 17.5-42.5T480-880q25 0 42.5 17.5T540-820v28q80 20 130 84.5T720-560v280h80v80H160Zm320-300Zm0 420q-33 0-56.5-23.5T400-160h160q0 33-23.5 56.5T480-80ZM320-280h320v-280q0-66-47-113t-113-47q-66 0-113 47t-47 113v280Z"/></svg>
                                </div>
                            }
                        </div>
                        <div className="mt-1 w-full flex-1 min-h-0 overflow-y-auto scrollbar">
                            {appContext.options?.mayInterceptCalls
                                ? loadingActiveCalls
                                    ? <div className="w-full h-full flex justify-center items-center">
                                        <p className="text-20 leading-none m-0">{t("laptop.desktop_screen.common.statuses.loading")}</p>
                                    </div>
                                    : Object.values(activeCalls).length == 0
                                        ? <div className="w-full h-full flex justify-center items-center gap-2">
                                            <svg xmlns="http://www.w3.org/2000/svg" height="30px" width="30px" viewBox="0 -960 960 960" fill="black"><path d="M162-120q-18 0-30-12t-12-30v-162q0-13 9-23.5t23-14.5l138-28q14-2 28.5 2.5T342-374l94 94q38-22 72-48.5t65-57.5q33-32 60.5-66.5T681-524l-97-98q-8-8-11-19t-1-27l26-140q2-13 13-22.5t25-9.5h162q18 0 30 12t12 30q0 125-54.5 247T631-329Q531-229 409-174.5T162-120Zm556-480q17-39 26-79t14-81h-88l-18 94 66 66ZM360-244l-66-66-94 20v88q41-3 81-14t79-28Zm358-356ZM360-244Z"/></svg>
                                            <p className="text-20 leading-none m-0">{t("laptop.desktop_screen.wiretap_app.phone_calls.no_calls_running")}</p>
                                        </div>
                                        : Object.values(activeCalls).map((call) =>
                                            <div key={call.channel} className="w-full flex items-center gap-2 rounded-10 p-1 overflow-hidden overflow-ellipsis hover:bg-button hoverable" onClick={() => startObservation(call)}>
                                                <svg xmlns="http://www.w3.org/2000/svg" height="50px" width="50px" viewBox="0 -960 960 960" fill="black"><path d="M162-120q-18 0-30-12t-12-30v-162q0-13 9-23.5t23-14.5l138-28q14-2 28.5 2.5T342-374l94 94q38-22 72-48.5t65-57.5q33-32 60.5-66.5T681-524l-97-98q-8-8-11-19t-1-27l26-140q2-13 13-22.5t25-9.5h162q18 0 30 12t12 30q0 125-54.5 247T631-329Q531-229 409-174.5T162-120Zm556-480q17-39 26-79t14-81h-88l-18 94 66 66ZM360-244l-66-66-94 20v88q41-3 81-14t79-28Zm358-356ZM360-244Z"/></svg>
                                                <div className="flex flex-col">
                                                    {Object.values(call.targets!).filter((target) => target).map((target) => <p key={target.playerId} className="text-30 leading-7">{target.name}</p>)}
                                                </div>
                                            </div>
                                        )
                                : <div className="w-full h-full flex justify-center items-center gap-2">
                                    <svg xmlns="http://www.w3.org/2000/svg" height="30px" width="30px" viewBox="0 -960 960 960" fill="black"><path d="M162-120q-18 0-30-12t-12-30v-162q0-13 9-23.5t23-14.5l138-28q14-2 28.5 2.5T342-374l94 94q38-22 72-48.5t65-57.5q33-32 60.5-66.5T681-524l-97-98q-8-8-11-19t-1-27l26-140q2-13 13-22.5t25-9.5h162q18 0 30 12t12 30q0 125-54.5 247T631-329Q531-229 409-174.5T162-120Zm556-480q17-39 26-79t14-81h-88l-18 94 66 66ZM360-244l-66-66-94 20v88q41-3 81-14t79-28Zm358-356ZM360-244Z"/></svg>
                                    <p className="text-20 leading-none m-0">{t("laptop.desktop_screen.wiretap_app.phone_calls.lacking_permissions")}</p>
                                </div>
                            }
                        </div>
                    </div>

                    <div className="w-full h-1/2 p-6 flex flex-col gap-2 bg-white/20 shadow-glass border-2 border-white/80 rounded-16 overflow-hidden">
                        <p className="text-20 leading-none m-0 uppercase">{t("laptop.desktop_screen.wiretap_app.spy_microphones.header")}</p>
                        <div className="mt-1 w-full flex-1 min-h-0 overflow-y-auto scrollbar">
                            {appContext.options?.mayListenToSpyMicrophones
                                ? loadingSpyMicrophones
                                    ? <div className="w-full h-full flex justify-center items-center">
                                        <p className="text-20 leading-none m-0">{t("laptop.desktop_screen.common.statuses.loading")}</p>
                                    </div>
                                    : Object.values(spyMicrophones).length == 0
                                        ? <div className="w-full h-full flex justify-center items-center gap-2">
                                            <svg xmlns="http://www.w3.org/2000/svg" width="30px" height="30px" fill="black" viewBox="0 -960 960 960"><path d="M480-200q66 0 113-47t47-113v-160q0-66-47-113t-113-47q-66 0-113 47t-47 113v160q0 66 47 113t113 47Zm-80-120h160v-80H400v80Zm0-160h160v-80H400v80Zm80 40Zm0 320q-65 0-120.5-32T272-240H160v-80h84q-3-20-3.5-40t-.5-40h-80v-80h80q0-20 .5-40t3.5-40h-84v-80h112q14-23 31.5-43t40.5-35l-64-66 56-56 86 86q28-9 57-9t57 9l88-86 56 56-66 66q23 15 41.5 34.5T688-640h112v80h-84q3 20 3.5 40t.5 40h80v80h-80q0 20-.5 40t-3.5 40h84v80H688q-32 56-87.5 88T480-120Z"/></svg>
                                            <p className="text-20 leading-none m-0">{t("laptop.desktop_screen.wiretap_app.spy_microphones.no_spy_microphones_placed")}</p>
                                        </div>
                                        : Object.values(spyMicrophones).map((spyMicrohpone) =>
                                            <div key={spyMicrohpone.label} className="w-full flex items-center gap-2 rounded-2 p-1 overflow-hidden overflow-ellipsis hover:bg-button hoverable" onClick={() => startObservation(spyMicrohpone)}>
                                                <svg xmlns="http://www.w3.org/2000/svg" width="50px" height="50px" fill="black" viewBox="0 -960 960 960"><path d="M480-200q66 0 113-47t47-113v-160q0-66-47-113t-113-47q-66 0-113 47t-47 113v160q0 66 47 113t113 47Zm-80-120h160v-80H400v80Zm0-160h160v-80H400v80Zm80 40Zm0 320q-65 0-120.5-32T272-240H160v-80h84q-3-20-3.5-40t-.5-40h-80v-80h80q0-20 .5-40t3.5-40h-84v-80h112q14-23 31.5-43t40.5-35l-64-66 56-56 86 86q28-9 57-9t57 9l88-86 56 56-66 66q23 15 41.5 34.5T688-640h112v80h-84q3 20 3.5 40t.5 40h80v80h-80q0 20-.5 40t-3.5 40h84v80H688q-32 56-87.5 88T480-120Z"/></svg>
                                                <p className="text-30">{spyMicrohpone.label}</p>
                                            </div>
                                        )
                                : <div className="w-full h-full flex justify-center items-center gap-2">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="30px" height="30px" fill="black" viewBox="0 -960 960 960"><path d="M480-200q66 0 113-47t47-113v-160q0-66-47-113t-113-47q-66 0-113 47t-47 113v160q0 66 47 113t113 47Zm-80-120h160v-80H400v80Zm0-160h160v-80H400v80Zm80 40Zm0 320q-65 0-120.5-32T272-240H160v-80h84q-3-20-3.5-40t-.5-40h-80v-80h80q0-20 .5-40t3.5-40h-84v-80h112q14-23 31.5-43t40.5-35l-64-66 56-56 86 86q28-9 57-9t57 9l88-86 56 56-66 66q23 15 41.5 34.5T688-640h112v80h-84q3 20 3.5 40t.5 40h80v80h-80q0 20-.5 40t-3.5 40h84v80H688q-32 56-87.5 88T480-120Z"/></svg>
                                    <p className="text-20 leading-none m-0">{t("laptop.desktop_screen.wiretap_app.spy_microphones.lacking_permissions")}</p>
                                </div>
                            }
                        </div>
                    </div>
                </div>
                
                <div className="w-full p-6 flex flex-col gap-1 bg-white/20 shadow-glass border-2 border-white/80 rounded-16">
                    <p className="text-20 uppercase">{t("laptop.desktop_screen.wiretap_app.radio.header")}</p>
                    {appContext.options?.mayInterceptRadio
                        ? <div className="w-full flex items-center gap-2">
                            <input className="rounded-10 min-w-0 grow bg-window border-none text-35 leading-none p-2 textable" placeholder="99.0 MHz" value={radioFrequency} onChange={handleRadioFrequencyChange} />
                            <div className="rounded-10 flex justify-center items-center p-1 hover:bg-button hoverable" onClick={startRadioObservation}>
                                <svg xmlns="http://www.w3.org/2000/svg" width="30px" height="30px" fill="black" viewBox="0 -960 960 960"><path d="m321-80-71-71 329-329-329-329 71-71 400 400L321-80Z"/></svg>
                            </div>
                        </div>
                        : <div className="w-full h-full flex justify-center items-center gap-2 p-2">
                            <svg xmlns="http://www.w3.org/2000/svg" width="30px" height="30px" fill="black" viewBox="0 -960 960 960"><path d="M196-276q-57-60-86.5-133T80-560q0-78 29.5-151T196-844l48 48q-48 48-72 110.5T148-560q0 63 24 125.5T244-324l-48 48Zm96-96q-39-39-59.5-88T212-560q0-51 20.5-100t59.5-88l48 48q-30 27-45 64t-15 76q0 36 15 73t45 67l-48 48ZM280-80l135-405q-16-14-25.5-33t-9.5-42q0-42 29-71t71-29q42 0 71 29t29 71q0 23-9.5 42T545-485L680-80h-80l-26-80H387l-27 80h-80Zm133-160h134l-67-200-67 200Zm255-132-48-48q30-27 45-64t15-76q0-36-15-73t-45-67l48-48q39 39 58 88t22 100q0 51-20.5 100T668-372Zm96 96-48-48q48-48 72-110.5T812-560q0-63-24-125.5T716-796l48-48q57 60 86.5 133T880-560q0 78-28 151t-88 133Z"/></svg>
                            <p className="text-20 leading-none m-0">{t("laptop.desktop_screen.wiretap_app.radio.lacking_permissions")}</p>
                        </div>
                    }
                </div>
            </div>

            <InterceptionChooser />
        </div>
    </div>;
}