import { Screens, set_current_screen } from ".."

export default function TitleScreen () {
    return (
        <main id="welcome_screen">
            <header>
                <h1>Cornilieus</h1>
                <p style="text-align: right">v0.0.1</p>
            </header>

            <div id="menu">
                <div id="primary_menu">
                    <div class="menu_option primary_menu_option">
                        <p>play</p>
                        
                        <div class="side_menu" id="extension_option_play">
                            <div class="menu_option"><p>campaign</p>
                            
                                <div class="side_menu">
                                    <div
                                        class="menu_option"
                                        onClick={() => set_current_screen(Screens.PLAY_SCREEN)}
                                    ><p>new run</p></div>
                                    <div class="menu_option"><p>save 1</p></div>
                                    <div class="menu_option"><p>save 2</p></div>
                                    <div class="menu_option"><p>save 3</p></div>
                                </div>
                            </div>

                            <div class="menu_option"><p>local play</p>
                            
                                <div class="side_menu">
                                    <div class="menu_option"><p>world 1</p></div>
                                    <div class="menu_option"><p>world 2</p></div>
                                    <div class="menu_option"><p>world 3</p></div>
                                </div>
                            </div>

                            <div class="menu_option"><p>multiplayer</p></div>
                        </div>
                    </div>
                    
                    <div class="menu_option primary_menu_option">
                        <p>settings</p>

                        <div class="side_menu" id="extension_option_settings">
                            <div class="menu_option"> <p>sound</p>
                                
                                <div class="side_menu">
                                    <label>master volume</label> <input
                                        id="master_volume_range"
                                        type="range"
                                    ></input>
                                    <br />
                                    <label>music volume</label> <input
                                        id="music_sound"
                                        type="range"
                                    ></input>
                                    <br />
                                    <label>music volume</label> <input
                                        id="music_sound"
                                        type="range"
                                    ></input>
                                </div>
                            </div>

                            <div class="menu_option"><p>controls</p>
                                <div class="side_menu">
                                    <div></div>
                                </div>
                            </div>
                            
                            <div class="menu_option"><p>diagnostic data</p>
                                <div class="side_menu">
                                    <label>fps</label>
                                    <input type="checkbox" id="fps_checkbox"></input>
                                    <br />
                                    <label>ping (multiplayer only)</label>
                                    <input type="checkbox" id="ping_checkbox"></input>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div
                        class="menu_option primary_menu_option"
                        id="primary_option_credits"
                        onClick={() => set_current_screen(Screens.CREDITS_SCREEN)}
                    ><p>credits</p></div>
                </div>

                
            </div>
        </main>
    );
}