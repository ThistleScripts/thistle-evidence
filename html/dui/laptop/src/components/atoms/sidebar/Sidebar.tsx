import * as React from "react"
import { cn } from "@/utils/cn";


function Sidebar({
    children,
    className,
    ...props
}: React.ComponentProps<"div">) {
    return (
        <div
            {...props}
            className={cn("flex flex-col gap-1 px-3 py-4 bg-white/20 shadow-glass border-2 border-white/80 rounded-16 overflow-y-hidden scrollbar hover:overflow-y-auto", className)}
        >
            {children}
        </div>
    )
}


function SidebarItem({
    children,
    imagePath,
    description,
    active,
    onClick,
    ...props
}: React.ComponentProps<"button"> & { active?: boolean, imagePath?: string, description?: string }) {
    return (
        <button
            className={`w-full flex justify-start items-center gap-4 px-1 py-1.5 border-none rounded-10 ${active ? "bg-button" : "bg-transparent"} duration-400 transition-all hoverable hover:bg-button`}
            onClick={onClick}
            {...props}
        >
            {imagePath && <img src={imagePath} className="w-7 h-7"></img>}

            <div className={`${imagePath ? "w-[calc(100%-55px)]" : "w-full"}`}>
                <p className="text-30 leading-none text-left truncate">{children}</p>
                {description && <p className="text-20 leading-none text-left truncate">{description}</p>}
            </div>
        </button>
    )
}


function SidebarSection({
    title,
    children,
    className,
}: {
    title: string
    children: React.ReactNode
    className?: string
}) {
    return (
        <div
            className={cn("my-2 first:mt-0 last:mb-0", className)}
        >
            <div className="flex flex-col gap-1">
                <p className="px-1 text-20 leading-none uppercase">{title}</p>
                {children}
            </div>
        </div>
    )
}


export {
    Sidebar,
    SidebarItem,
    SidebarSection,
}