import { Screens, set_current_screen } from "..";

export default function CreditsScreen () {
    return (
        <main id="credits_screen">
            <p>
                    ### WGSL Simplex Noise 2D
                <br />* **Authors:** Ian McEwan, Stefan Gustavson, Munrocket, Johan Helsing
                <br />* **Source:** https://gist.github.com/munrocket/236ed5ba7e409b8bdf1ff6eca5dcdc39
                <br />* **License:** MIT License
            </p>

            <p>
                      // Hilbert Curve implementation
                <br />// Adapted from Daniel Shiffman / The Coding Train
                <br />// Original tutorial: https://youtu.be/dSK-MW-zuAc
                <br />// License: GNU Lesser General Public License (LGPL v2.1)
            </p>

            <p>
                      ### 2D Simplex Noise / Kogge-Stone Parallel Prefix
                <br />* **Concept:** Kogge-Stone Parallel Prefix Layout (Peter M. Kogge, Harold S. Stone)
                <br />* **Code Authors:** Ian McEwan, Stefan Gustavson, Munrocket, Johan Helsing
                <br />* **Source Implementation:** [GitHub Gist by munrocket](https://github.com)
                <br />* **License:** MIT License
            </p>

            <button onClick={() => set_current_screen(Screens.WELCOME_SCREEN)}>back to welcome screen</button>
        </main>
    );
}