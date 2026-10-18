import React, { createContext, useContext, useEffect, useRef, useState } from "react";
import { cn } from "@/utils/cn";
import { useTranslation } from "@/components/TranslationContext";


interface DropdownProps<ItemType> {
    items: ItemType[];
    selectedItem?: ItemType;
    onItemSelect: (item: ItemType) => void;
    itemToString?: (item: ItemType) => string;
    onScrollToBottom?: () => void;
    onUnfold?: () => void;
    loading?: boolean;
    searchText?: string;
    onSearchTextChange?: (text: string) => void;
}


interface DropdownContextType {
    items: any[];
    selectedItem?: any;
    dropdownOpen: boolean;
    setDropdownOpen: React.Dispatch<React.SetStateAction<boolean>>;
    refSelection: React.RefObject<HTMLDivElement | null>;
    refDropdown: React.RefObject<HTMLDivElement | null>;
    onItemSelect: (item: any) => void;
    itemToString: (item: any) => string;
    onScrollToBottom?: () => void;
    loading?: boolean;
    searchText?: string;
    onSearchTextChange?: (text: string) => void;
    registerCallback: (cb: SelectionDisplayCallback<any>) => void;
}

type SelectionDisplayCallback<ItemType> = (item: ItemType) => string;

const DropdownContext = createContext<DropdownContextType | null>(null);

function useDropdownContext<ItemType>() {
  const ctx = useContext(DropdownContext);
  if (!ctx) {
    throw new Error("Dropdown components must be used inside <Dropdown>");
  }

  return ctx as Omit<DropdownContextType, "items" | "onItemSelect"> & {
    items: ItemType[];
    selectedItem?: ItemType;
    onItemSelect: (item: ItemType) => void;
    itemToString: (item: ItemType) => string;
    registerCallback: (cb: SelectionDisplayCallback<ItemType>) => void;
  };
}


function Dropdown<ItemType>({
    items,
    selectedItem,
    onScrollToBottom,
    onItemSelect,
    itemToString,
    onUnfold,
    loading,
    searchText,
    onSearchTextChange,

    children,
    className,
    ...props
}: React.ComponentProps<"div"> & DropdownProps<ItemType>) {
    const [open, setOpen] = useState<boolean>(false);
    const refSelection = useRef<HTMLDivElement>(null);
    const refDropdown = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (open && onUnfold) onUnfold();
    }, [open]);

    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            if (refSelection.current && refDropdown.current && !refSelection.current.contains(event.target as Node) && !refDropdown.current.contains(event.target as Node)) {
                setOpen(false);
            }
        }

        document.addEventListener("mousedown", handleClickOutside);

        return () => document.removeEventListener("mousedown", handleClickOutside)
    }, []);


    const selectionToDisplaynameCallbackRef = useRef<SelectionDisplayCallback<ItemType>>(null);

    const registerCallback = (cb: SelectionDisplayCallback<ItemType>) => {
        selectionToDisplaynameCallbackRef.current = cb;
    };

    const callToDisplayname = (item: ItemType) => {
        return selectionToDisplaynameCallbackRef.current?.(item) || "";
    };

    const handleItemSelection = (item: ItemType) => {
        setOpen(false);
        onItemSelect(item);
        onSearchTextChange && onSearchTextChange(callToDisplayname(item));
    }

    const handleSearchTextChange = (text: string) => {
        setOpen(true);
        onSearchTextChange && onSearchTextChange(text);
    }


    const defaultItemToString = (item: any) => {
        return item;
    }

    return (
        <div
            {...props}
            className={cn("relative", className)}
        >
            <DropdownContext.Provider value={{
                items: items,
                onItemSelect: handleItemSelection,
                selectedItem: selectedItem,
                refSelection: refSelection,
                refDropdown: refDropdown,
                dropdownOpen: open,
                setDropdownOpen: (newValue) => setOpen(newValue),
                itemToString: itemToString || defaultItemToString,
                onScrollToBottom: onScrollToBottom,
                loading: loading,
                searchText: searchText,
                onSearchTextChange: handleSearchTextChange,
                registerCallback: registerCallback
            }}>
                {children}
            </DropdownContext.Provider>
        </div>
    )
}


interface DropdownSelectionProps<ItemType> extends Omit<React.ComponentProps<"div">, "children"> {
    placeholder: string;
    children: (item: ItemType) => React.ReactNode;
    includeSearch?: (item: ItemType) => string;
    displayArrow?: boolean;
}


function DropdownSelection<ItemType>({ includeSearch, displayArrow = true, placeholder, children, className, ...props }: DropdownSelectionProps<ItemType>) {
    const dropdownContext = useDropdownContext<ItemType>();

    useEffect(() => {
        dropdownContext.registerCallback(item => {
            return includeSearch && includeSearch(item) || "";
        });
    }, [dropdownContext]);


    return <div
        ref={dropdownContext?.refSelection}
        onClick={() => dropdownContext?.setDropdownOpen(includeSearch ? true : prev => !prev)}
        {...props}
        className={cn("flex justify-between items-center bg-white/20 shadow-glass border-2 border-white/80 rounded-10 p-2", displayArrow && (includeSearch ? "textable" : "hoverable"), className)}
    >
        {includeSearch
            ? <input
                type="text"
                placeholder={placeholder}
                onChange={(e) => dropdownContext.onSearchTextChange && dropdownContext.onSearchTextChange(e.target.value)}
                value={dropdownContext.searchText || ""}
                className="outline-none appearance-none bg-transparent border-none text-30 leading-none"
            />
            : dropdownContext.selectedItem === undefined
                ? <p className="flex-1 min-w-0 text-30 leading-none opacity-50">{placeholder}</p>
                : <div>
                    {children(dropdownContext.selectedItem)}
                </div>
        }
        {displayArrow &&
            <svg xmlns="http://www.w3.org/2000/svg" width="35px" height="35px" fill="black" viewBox="0 -960 960 960"><path d="M480-80 240-320l57-57 183 183 183-183 57 57L480-80ZM298-584l-58-56 240-240 240 240-58 56-182-182-182 182Z"/></svg>
        }
    </div>
}


interface DropdownUnfoldedProps<ItemType> extends Omit<React.ComponentProps<"div">, "children"> {
  children: (item: ItemType, selected: boolean) => React.ReactNode;
}


function DropdownUnfolded<ItemType>({
    children,
    className,
    ...props
}: DropdownUnfoldedProps<ItemType>) {
    const { t } = useTranslation();
    const dropdownContext = useDropdownContext<ItemType>();
    if (!dropdownContext.dropdownOpen) return null;

    const rect = dropdownContext?.refSelection.current?.getBoundingClientRect();

    const scrollRef = useRef(null);
    const handleScroll = () => {
        if (!scrollRef.current) return;

        const { scrollTop, scrollHeight, clientHeight } = scrollRef.current;
        const isBottom = Math.abs(scrollHeight - (scrollTop + clientHeight)) <= 1;

        if (isBottom && dropdownContext.onScrollToBottom) {
            dropdownContext.onScrollToBottom();
        }
    };

    return dropdownContext?.dropdownOpen && (<div
        ref={dropdownContext.refDropdown}
        {...props}
        className={cn("fixed z-1000 bg-window rounded-16 mt-2", className)}
        style={{
            top: rect?.bottom,
            left: rect?.left,
            width: rect?.width
        }}
    >
        <div ref={scrollRef} onScroll={handleScroll} className="flex flex-col gap-1 p-2 max-h-60 bg-white/20 shadow-glass border-2 border-white/80 rounded-16 overflow-y-hidden scrollbar hover:overflow-y-auto">
            {dropdownContext.loading && Array.from({ length: 10 }).map(() =>
                <div className="w-full flex flex-col gap-1 justify-center items-start px-1 py-1.5 border-unset bg-transparent">
                    <div className="w-full flex gap-1">
                        <div className="w-[30%] h-6 bg-button animate-skeleton-pulse" />
                        <div className="w-1/2 h-6 bg-button animate-skeleton-pulse" />
                    </div>

                    <div className="w-full flex gap-1">
                        <div className="w-[40%] h-4 bg-button animate-skeleton-pulse" />
                        <div className="w-2 h-4 bg-button animate-skeleton-pulse" />
                        <div className="w-[12.5%] h-4 bg-button animate-skeleton-pulse" />
                    </div>
                </div>
            )}
            {!dropdownContext.loading &&
                dropdownContext.items.length === 0
                    ? <p className="text-20 leading-none italic p-2">{t("laptop.desktop_screen.common.statuses.no_selection")}</p>
                    : dropdownContext.items.map((item) => children(item, dropdownContext.selectedItem && (dropdownContext.itemToString(dropdownContext.selectedItem) === dropdownContext.itemToString(item))))
            }
        </div>
    </div>);
}



interface DropdownItemProps<ItemType> extends React.ComponentProps<"div"> {
  item: ItemType;
  selected?: boolean;
}


function DropdownItem<ItemType>({
    selected,
    item,
    children,
    className,
    ...props
}: DropdownItemProps<ItemType>) {
    const dropdownContext = useDropdownContext<ItemType>();
    if (!dropdownContext.dropdownOpen) return null;

    return <div
        className={cn("w-full flex flex-col justify-center items-start gap-4 px-1 py-1.5 border-none rounded-10 duration-400 transition-all hoverable hover:bg-button", selected ? "bg-button" : "bg-transparent", className)}
        onClick={() => dropdownContext.onItemSelect(item)}
        {...props}
    >
        <div>
            {children}
        </div>
    </div>
}


export {
    Dropdown,
    DropdownSelection,
    DropdownUnfolded,
    DropdownItem,
}