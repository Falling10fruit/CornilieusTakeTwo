import { createSignal, createEffect, Switch, Match } from "solid-js";
import TitleScreen from "./jsx/welcome_screen.tsx";
import CreditsScreen from "./jsx/credits_screen.tsx";

enum Screens {
    WELCOME_SCREEN = "welcome_screen",
    CREDITS_SCREEN = "credits_screen"
}
const [current_scene, set_current_scene] = createSignal(Screens.WELCOME_SCREEN);

const switched_stylesheet = document.getElementById("switched_stylesheet") as HTMLLinkElement;
createEffect(() => { switched_stylesheet.href = `/src/css/${current_scene()}.css` });

function App ()  {
    return (<>
        <Switch fallback={<TitleScreen />}>
            <Match when={current_scene() === Screens.WELCOME_SCREEN}>
                <TitleScreen />
            </Match>
            
            <Match when={current_scene() === Screens.CREDITS_SCREEN}>
                <CreditsScreen />
            </Match>
        </Switch>
    </>)
}

export { App, Screens, set_current_scene };