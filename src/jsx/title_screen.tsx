import { Scenes, set_current_scene } from "..";

export default function TitleScreen () {
    return (
        <main id="TitleScreen">
            <header>
                <h1>Cornilieus</h1>
                <p>v0.0.1</p>
            </header>

            <div id="menu">
                <div id="primary_menu">
                    <div class="menu_option primary_menu_option" id="primary_option_play">play</div>
                    <div class="menu_option primary_menu_option" id="primary_option_settings">settings</div>
                    <div
                        class="menu_option primary_menu_option"
                        id="primary_option_credits"
                        onClick={() => set_current_scene(Scenes.CREDITS_SCREEN)}
                    >credits</div>
                </div>

                <div class="side_menu" id="extension_option_play">
                    <div class="menu_option">campaign</div>
                    <div class="menu_option">local play</div>
                    <div class="menu_option">multiplayer</div>
                </div>
                
                <div class="side_menu" id="extension_option_settings">
                    <div class="menu_option">sound</div>
                    <div class="menu_option">control</div>
                    <div class="menu_option">anaylisis</div>
                </div>
            </div>
        </main>
    );
}