import { Screens, set_current_scene } from ".."

export default function TitleScreen () {
    return (
        <main>
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
                                    <div class="menu_option"><p>new run</p></div>
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
                            <div class="menu_option"><p>controls</p></div>
                            <div class="menu_option"><p>diagnostic data</p>
                                <div class="side_menu">
                                    <label>fps</label><button>off</button>
                                    <br />
                                    <label>ping (multiplayer only)</label><button>off</button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div
                        class="menu_option primary_menu_option"
                        id="primary_option_credits"
                        onClick={() => set_current_scene(Screens.CREDITS_SCREEN)}
                    ><p>credits</p></div>
                </div>

                
            </div>
        </main>
    );
}