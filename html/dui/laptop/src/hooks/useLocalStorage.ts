import { useEffect, useState } from "react";

/**
 * useLocalStorage Hook
 * @param key Key for the local storage
 * @param defaultValue Value if the key is not present of type T.
 * @returns a array with the current value (of type T) and a function to set a new value of type T.
 */
export default function useLocalStorage<T>(key: string, defaultValue: T): [T, (newValue: T) => void] {
    const [data, setData] = useState<string>(localStorage.getItem(key) || "");

    function setNewData(newValue: T) {
        setData(JSON.stringify(newValue));
    }

    useEffect(() => {
        localStorage.setItem(key, data);
    }, [data]);

    return [data ? JSON.parse(data) : defaultValue, setNewData];
}