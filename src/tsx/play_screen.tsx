import { For } from "solid-js"
import placeholder_image from "../placeholder.png"
import { Screens, set_current_screen } from ".."

export default function PlayScreen () {
    return (<main id="play_screen">
        <div id="inventory">
            <For each={Array.from({ length: 10 })}>
                {(_, index) =>
                    <div class="inventory_item">
                        <input type="radio" name="inventory" checked />
                        <img src={placeholder_image} alt={`inventory slot no. ${index}`}/>
                    </div>
                }
            </For>
        </div>
    </main>);
}