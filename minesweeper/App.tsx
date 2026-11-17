import { createSignal, createEffect } from 'solid-js'

const [bombsLeft, set_bombsLeft] = createSignal(0);
function App() {
  const [width, setWidth] = createSignal(10);
  const [height, setHeight] = createSignal(10);
  
  window.grid = {
      viewport_padding: 50,

      max_width: window.innerWidth/10,
      max_height: window.innerHeight/10,
      width: 10,
      height: 10,

      no_of_tiles: 100
  }

  createEffect(() => { window.grid.width = width(); window.grid.no_of_tiles = window.grid.width * window.grid.height});
  createEffect(() => { window.grid.height = height(); window.grid.no_of_tiles = window.grid.width * window.grid.height});

  return (
    <>
      <main>
        <section>
          <p style="margin-top:0px;">No. of bombs left: {bombsLeft()}</p>
          <label>controls</label>
          <input type="checkbox" id="control_toggle" />
        </section>

        <aside id="controls">
          <input type="range" min={10} max={window.grid.max_width} step={1} value={10} oninput={(e) => {setWidth(parseInt(e.target.value))}}/>
          <label>width {width()}</label>
          <br />
          <input type="range" min={10} max={window.grid.max_height} step={1} value={10} oninput={(e) => {setHeight(parseInt(e.target.value))}}/>
          <label>height {height()}</label>
        </aside>
      </main>
    </>
  )
}

export { App, set_bombsLeft }
