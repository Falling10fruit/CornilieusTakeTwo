import { Screens, set_current_scene } from "..";

export default function TitleScreen () {
    return (
        <main>
            <header>
                <h1>Cornilieus</h1>
                <p>v0.0.1</p>
            </header>

            <div id="menu">
                <div id="primary_menu">
                    <div class="menu_option primary_menu_option" id="primary_option_play">
                        play
                        
                        <div class="side_menu" id="extension_option_play">
                            <div class="menu_option">campaign</div>
                            <div class="menu_option">local play</div>
                            <div class="menu_option">multiplayer</div>
                        </div>
                    </div>
                    
                    <div class="menu_option primary_menu_option" id="primary_option_settings">
                        settings

                        <div class="side_menu" id="extension_option_settings">
                            <div class="menu_option">
                                sound
                            </div>
                            <div class="menu_option">control</div>
                            <div class="menu_option">anaylisis</div>
                        </div>
                    </div>

                    <div
                        class="menu_option primary_menu_option"
                        id="primary_option_credits"
                        onClick={() => set_current_scene(Screens.CREDITS_SCREEN)}
                    >credits</div>
                </div>

                
            </div>
        </main>
    );
}