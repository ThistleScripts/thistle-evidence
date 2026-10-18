import type { OpenApp } from "../screens/DesktopScreen";
import AppIcon from "./AppIcon";


// Props parsed by the parent.
interface TaskbarAppsProps {
    openApps: OpenApp[];
    maximizeApp: (app: OpenApp) => void;
}


// Renders the app icons in the taskbar.
export default function TaskbarApps(props: TaskbarAppsProps) {
    return <div className="h-full flex flex-1 items-center gap-1 px-2">
        {props.openApps.filter(app => !app.isPopUp).map(app =>
            <div key={app.name} className="h-[80%] aspect-square my-0">
                <AppIcon app={app} width="100%" height="100%" onClick={() => props.maximizeApp(app)} taskbarIcon />
            </div>
        )}
    </div>
}