const eyedropper = document.createElement("input");
eyedropper.type = "color";

/**
 * Where the game world information is set.
 * 
 * @default
 * ```
 *  window.world = {
 *      width: 80,
 *      height: 60,
 *      seed: 43758.5453,
 *      storageBuffer: null, 
 * }
 * ```
 * Initialized at {@link window.world} */
window.world = {
    width: 80,
    height: 60,
    seed: 43758.5453,
    storageBuffer: null,
};

/**
 * Where the camera information is set.
 * 
 * @default
 * ```
 *  window.camera = {
 *      xPos: 0,
 *      yPos: 0,
 *      yVel: 0,
 *      xVel: 0,
 *      scale: 16,
 *      scaleVel: 0,
 *      rotation: (0)*Math.PI/180,
 *      rotationVel: 0,
 *      uniformBuffer: null,
 *  };
 * ```
 * Initialized at {@link window.camera}
 * 
 * The uniform buffer is a struct:
 * ```
 *  struct TransformStruct {
 *      location(0) translate : vec2f,
 *      location(1) scale : f32,
 *      location(2) rotation : f32,
 *  }
 * ```
 * The `@` is implicit; they are reserved in JSDoc.
 */
window.camera = {
    xPos: 0,
    yPos: 0,
    yVel: 0,
    xVel: 0,
    scale: 16,
    scaleVel: 0,
    rotation: (0)*Math.PI/180,
    rotationVel: 0,
    uniformBuffer: null,
};

window.spritesheet = {
    texture: null,
    sampler: null,
};

window.keyIsDown = {};

window.onkeyup = (e) => { window.keyIsDown[e.key] = false; }
window.onkeydown = (event) => {
    window.keyIsDown[event.key] = true;
    console.log(event.key);

    if (event.key === "F2") eyedropper.click();
};