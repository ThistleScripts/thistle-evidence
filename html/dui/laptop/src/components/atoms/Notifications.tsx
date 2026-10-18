import { useEffect, useState } from "react";
import { NotificationType, type NotificationWithId } from "@/types/notification.type";

export function Notifications({ notifications, onClose }: { notifications: NotificationWithId[] } & { onClose: (id: number) => void }) {
    return notifications && (
        <div className="absolute z-9999 flex flex-col gap-2 duration-300 transition-all ease-in-out top-9 right-4 items-end">
            {notifications.map((notification) => (
                <Notification
                    key={notification.id}
                    notification={notification}
                    onClose={onClose}
                />
            ))}
        </div>
    );
}

function Notification({ onClose, notification }: { notification: NotificationWithId } & { onClose: (id: number) => void }) {
    const duration = notification.duration ?? 4000;
    const [isMounted, setIsMounted] = useState(false);
    const [isClosing, setIsClosing] = useState(false);

    useEffect(() => {
        requestAnimationFrame(() => setIsMounted(true));

        const closeTimer = setTimeout(() => handleClose(), duration);
        return () => clearTimeout(closeTimer);
    }, [duration]);

    const handleClose = () => {
        setIsClosing(true);
        setTimeout(() => onClose(notification.id), 400);
    };

    return (
        <div
            className={`bg-white/20 shadow-glass border-2 border-white/80 rounded-16 px-4 py-3 min-w-60 max-w-80 flex justify-between items-start gap-2 relative overflow-hidden duration-400 transition-all ease-[cubic-bezier(0.68,-0.55,0.27,1.55)]`}
            style={{
                opacity: isMounted && !isClosing ? 1 : 0,
                transform: isMounted && !isClosing
                    ? "translateX(0)"
                    : "translateX(50px)"
            }}
        >
            <div className="w-full flex justify-center items-center gap-2">
                {NotificationType[notification.type]}
                <span className="text-20 leading-none overflow-hidden text-clip">{notification.message}</span>
            </div>

            <div className="hoverable" onClick={handleClose}>
                <svg xmlns="http://www.w3.org/2000/svg" height="25px" width="25px" fill="black" viewBox="0 -960 960 960"><path d="m256-200-56-56 224-224-224-224 56-56 224 224 224-224 56 56-224 224 224 224-56 56-224-224-224 224Z"/></svg>
            </div>
        </div>
    );
}