import { createSignal, Switch, Match } from "solid-js";
import TitleScreen from "./jsx/title_screen.tsx";
import CreditsScreen from "./jsx/credits_screen.tsx";

enum Scenes {
    TITLE_SCREEN = "title_screen",
    CREDITS_SCREEN = "credits_screen"
}
const [current_scene, set_current_scene] = createSignal(Scenes.TITLE_SCREEN);

function App ()  {

    return (<>
        <Switch fallback={<TitleScreen />}>
            <Match when={current_scene() === Scenes.TITLE_SCREEN}>
                <TitleScreen />
            </Match>
            
            <Match when={current_scene() === Scenes.CREDITS_SCREEN}>
                <CreditsScreen />
            </Match>
        </Switch>
    </>)
}

export { App, Scenes, set_current_scene };