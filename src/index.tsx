import { createSignal, createEffect, Switch, Match } from "solid-js";
import TitleScreen from "./jsx/welcome_screen.tsx";
import CreditsScreen from "./jsx/credits_screen.tsx";
import PlayScreen from "./jsx/play_screen.tsx";

enum Screens {
    WELCOME_SCREEN = "welcome_screen",
    CREDITS_SCREEN = "credits_screen",
    PLAY_SCREEN = "play_screen"
}
const [current_screen, set_current_screen] = createSignal(Screens.WELCOME_SCREEN);

const switched_stylesheet = document.getElementById("switched_stylesheet") as HTMLLinkElement;
createEffect(() => { switched_stylesheet.href = `/src/css/${current_screen()}.css` });

function App ()  {
    return (<>
        <Switch fallback={<TitleScreen />}>
            <Match when={current_screen() === Screens.WELCOME_SCREEN}>
                <TitleScreen />
            </Match>
            
            <Match when={current_screen() === Screens.CREDITS_SCREEN}>
                <CreditsScreen />
            </Match>
            
            <Match when={current_screen() === Screens.PLAY_SCREEN}>
                <PlayScreen />
            </Match>
        </Switch>
    </>)
}

export { App, Screens, set_current_screen };