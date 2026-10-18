import React, { createContext, useEffect, useRef, useState } from "react";
import type { OpenApp } from "../screens/DesktopScreen";
import type { Options } from "../App";
import { useNotificationQueue } from "@/hooks/useNotificationQueue";
import type { AppArgs } from "@/types/appargs.type";
import type { Notification } from "@/types/notification.type";
import { Notifications } from "../atoms/Notifications";


// Props parsed by the parent.
interface MoveableAppProps {
    app: OpenApp;
    isPopUp?: boolean;
    defaultPosition?: { x: number, y: number };
    width: number;
    height: number;
    options: Options | undefined;
    playerName: string | undefined;
    onClose: (app: OpenApp) => void;
    onFocus: (app: OpenApp) => void;
    onMinimize: (app: OpenApp) => void;
    openPopUp: (name: string, content: React.ReactNode) => void;
    openApp: (appId: string, args?: AppArgs) => void;
    close: () => void;
    onUpdatePosition: (x: number, y: number) => void;
}


export interface AppContextType {
    playerName: string | undefined;
    options: Options | undefined;
    openPopUp: (name: string, content: React.ReactNode) => void;
    openApp: (appId: string, args?: AppArgs) => void;
    close: () => void;
    displayNotification: (notification: Notification) => void;
}

export const AppContext = createContext<AppContextType | undefined>(undefined);


// Renders an open app on the desktop.
export default function MoveableApp(props: MoveableAppProps) {
    const screenRef = useRef<HTMLDivElement>(null);
    const [position, setPosition] = useState(props.defaultPosition || { x: 0, y: 0 });
    const [dragging, setDragging] = useState(false);
    const [offset, setOffset] = useState(props.defaultPosition || { x: 0, y: 0 });

    const { notifications, displayNotification, closeNotification } = useNotificationQueue();


    useEffect(() => {
        props.onUpdatePosition(position.x, position.y);
    }, []);

    // Used to drag the window around.
    const onMouseDown = (e: React.MouseEvent<HTMLDivElement>) => {
        setDragging(true);
        setOffset({
            x: e.clientX - position.x,
            y: e.clientY - position.y,
        });
    };


    // When dragged update the window position.
    const onMouseMove = (e: MouseEvent) => {
        if (!dragging || !screenRef.current) return;

        const screen = screenRef.current.getBoundingClientRect();
        let newX = e.clientX - offset.x;
        let newY = e.clientY - offset.y;

        newX = Math.max(0, Math.min(screen.width - 25, newX));
        newY = Math.max(0, Math.min(screen.height - 25, newY));

        setPosition({ x: newX, y: newY });
        props.onUpdatePosition(newX, newY);
    };


    // Stop dragging.
    const onMouseUp = () => {
        setDragging(false);
    };


    // Listeners
    useEffect(() => {
        window.addEventListener("mousemove", onMouseMove);
        window.addEventListener("mouseup", onMouseUp);

        return () => {
            window.removeEventListener("mousemove", onMouseMove);
            window.removeEventListener("mouseup", onMouseUp);
        };
    });


    return (
        <div
            ref={screenRef}
            className="w-full h-full absolute overflow-hidden top-0 left-0 pointer-events-none"
        >
            <div
                onMouseDown={() => props.onFocus(props.app)}
                className={`absolute select-none overflow-hidden pointer-events-auto rounded-10 shadow-[0_0_5px_1px_rgba(0,0,0,0.4)] ${props.app.minimized ? "hidden" : "block"}`}
                style={{
                    width: props.width + "px",
                    height: props.height + "px",
                    left: position.x,
                    top: position.y,
                    zIndex: props.app.zIndex
                }}
            >
                <div onMouseDown={onMouseDown} className="w-full h-[42px] bg-window relative flex justify-end items-center">
                    <div className="absolute left-1/2 -translate-x-1/2 h-full flex items-center gap-2">
                        {props.app.icon("25px", "25px")}
                        <span className="text-25 truncate uppercase">{props.app.name}</span>
                    </div>

                    <div className="h-full flex items-center gap-1.5 mr-4">
                        {!props.isPopUp &&
                            <button
                                className="group h-4 w-4 flex items-center justify-center bg-[#383838] border-none rounded-full duration-400 transition-all hoverable hover:h-5 hover:w-5"
                                onClick={() => props.onMinimize(props.app)}
                            >
                                <svg className="opacity-0 group-hover:opacity-100 transition-opacity duration-400 ease-in-out" width="25px" height="25px" fill="#c0c0c0ff" xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960">
                                    <path d="M440-440v240h-80v-160H200v-80h240Zm160-320v160h160v80H520v-240h80Z"/>
                                </svg>
                            </button>
                        }

                        <button
                            className="group h-4 w-4 flex items-center justify-center bg-[#d62e30] border-none rounded-full duration-400 transition-all hoverable hover:h-5 hover:w-5"
                            onClick={() => props.onClose(props.app)}
                        >
                            <svg className="opacity-0 group-hover:opacity-100 transition-opacity duration-400 ease-in-out" width="25px" height="25px" fill="#c0c0c0ff" xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960">
                                <path d="m256-200-56-56 224-224-224-224 56-56 224 224 224-224 56 56-224 224 224 224-56 56-224-224-224 224Z"/>
                            </svg>
                        </button>
                    </div>
                </div>
                <div className="w-full bg-transparent" style={{ height: (props.height - 42) + "px" }}>
                    <Notifications notifications={notifications} onClose={closeNotification} />
                    <AppContext.Provider value={{ options: props.options, playerName: props.playerName, openPopUp: props.openPopUp, openApp: props.openApp, close: props.close, displayNotification: displayNotification }}>
                        {props.app.content(props.app.args)}
                    </AppContext.Provider>
                </div>
            </div>
        </div>
    );
}