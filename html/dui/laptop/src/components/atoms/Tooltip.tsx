import { useState } from "react";

export const Tooltip = ({ text, children }: { text: string, children: React.ReactNode }) => {
    const [isVisible, setVisisble] = useState<boolean>(false);

    return (
        <div
            onMouseEnter={() => setVisisble(true)}
            onMouseLeave={() => setVisisble(false)}
            className="relative flex items-center"
        >
            {children}
            {isVisible && <span className="absolute top-[calc(-100%-100px)] bg-[#333] rounded-10 z-1 min-w-60 text-white p-2 text-20 leading-5">{text}</span>}
        </div>
    );
};