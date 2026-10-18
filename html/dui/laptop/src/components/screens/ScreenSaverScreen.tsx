import { useEffect, useState } from "react";
import backgroundImage from "@/assets/background.png";
import type { ScreenType } from "../App";
import { useTranslation } from "../TranslationContext";


// This is the interface for the props parsed by the parent component.
interface ScreenSaverScreenProps {
    switchScreen: (newScreen: ScreenType) => void;
}


// Render the screen saver screen.
export default function ScreenSaverScreen(props: ScreenSaverScreenProps) {
    const { t } = useTranslation();
    const [currentTime, setCurrentTime] = useState<Date>(new Date());
    const [animateOut, setAnimateOut] = useState(false);


    // Handle click and switch to login screen.
    function handleClick() {
        setAnimateOut(true);

        setTimeout(() => {
            props.switchScreen("login");
        }, 750);
    }


    // Update time on screen every second.
    useEffect(() => {
        const timer = setInterval(() => {
            setCurrentTime(new Date());
        }, 1000);

        return () => clearInterval(timer);
    }, []);


    const formatTime = (date: Date): string => {
        return date.toLocaleTimeString(t("laptop.desktop_screen.common.date_locales"), { hour: "2-digit", minute: "2-digit", hour12: false });
    };

    const formatDate = (date: Date): string => {
        return date.toLocaleDateString(t("laptop.desktop_screen.common.date_locales"), { weekday: "long", day: "numeric", month: "long" });
    };


    return (
        <div className="w-full h-full relative" style={{ background: `url(${backgroundImage})` }} onClick={handleClick}>
            <div className={`absolute flex flex-col gap-3 bottom-10 left-10 text-white z-10 transition-all duration-500 ease-in-out ${animateOut ? "-translate-y-150 opacity-0" : "translate-y-0 opacity-100"}`}>
                <p className="text-150 leading-none">{formatTime(currentTime)}</p>
                <p className="text-50 leading-none">{formatDate(currentTime)}</p>
            </div>
        </div>
    );
}
