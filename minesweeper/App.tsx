import { createSignal, createEffect } from 'solid-js'

const [bombsLeft, set_bombsLeft] = createSignal(0);
function App() {
  const [width, setWidth] = createSignal(10);
  const [height, setHeight] = createSignal(10);
  
  window.grid_dimensions = {
      max_width: window.innerWidth/10,
      max_height: window.innerHeight/10,
      width: 10,
      height: 10,
  }

  createEffect(() => { window.grid_dimensions.width = width(); });
  createEffect(() => { window.grid_dimensions.height = height(); });

  return (
    <>
      <main>
        <section>
          <label>controls</label>
          <input type="checkbox" id="control_toggle" />
          <button id="generate">regenerate</button>
          <p>No. of bombs left: {bombsLeft()}</p>
        </section>

        <aside id="controls">
          <input type="range" min={10} max={window.grid_dimensions.max_width} step={1} value={10} oninput={(e) => {setWidth(parseInt(e.target.value))}}/>
          <label>width {width()}</label>
          <br />
          <input type="range" min={10} max={window.grid_dimensions.max_height} step={1} value={10} oninput={(e) => {setHeight(parseInt(e.target.value))}}/>
          <label>height {height()}</label>
        </aside>
      </main>
    </>
  )
}

export { App, set_bombsLeft }
