import type { Notification, NotificationWithId } from "@/types/notification.type";
import { useCallback, useRef, useState } from "react";

export function useNotificationQueue() {
    const [notifications, setNotifications] = useState<NotificationWithId[]>([]);
    const nextId = useRef(0);

    const displayNotification = useCallback((notification: Notification) => {
        const id = nextId.current++;
        setNotifications(prev => [...prev, { ...notification, id }]);
    }, []);

    const closeNotification = useCallback((id: number) => {
        setNotifications(prev => prev.filter(notification => notification.id !== id))
    }, []);

    return { notifications, displayNotification, closeNotification };
}