import { useEffect, useState } from "react";
import { Microscope } from "lucide-react";
import type { ScreenType } from "../App";
import { useTranslation } from "../TranslationContext";


// This is the interface for the props parsed by the parent component.
interface ScreenSaverScreenProps {
    brand: string;
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
        <div className="th-wallpaper w-full h-full relative" onClick={handleClick}>
            <div className="absolute top-10 left-10 flex items-center gap-4">
                <div className="flex h-20 w-20 items-center justify-center rounded-16 bg-accent/15 text-accent">
                    <Microscope size={44} />
                </div>
                <div>
                    <p className="text-20 font-semibold uppercase tracking-[0.2em] text-accent">{t("laptop.brand")}</p>
                    <p className="font-display text-45 font-black leading-none text-white">{props.brand}</p>
                </div>
            </div>

            <div className={`absolute flex flex-col gap-3 bottom-10 left-10 text-white z-10 transition-all duration-500 ease-in-out ${animateOut ? "-translate-y-150 opacity-0" : "translate-y-0 opacity-100"}`}>
                <p className="font-display text-150 font-black leading-none">{formatTime(currentTime)}</p>
                <p className="text-50 leading-none">{formatDate(currentTime)}</p>
            </div>
        </div>
    );
}
