declare global {
    interface window {
        renderWorld: {
            setUp: (device: GPUDevice) => void; 
            bindWorldStorageBuffer: ({ width: number, height: number, storageBuffer: GPUBuffer }) => void;
            writeViewportBuffer: ({ width: number, height: number }) => void;
            renderWorld: () => void;
        };
        generateWorld: any;
        canvasResize: ({ width: number, height: number }) => void;
        device: GPUDevice;
        world: {
            width: number;
            height: number;
            seed: number;
            storageBuffer: GPUBuffer;
        };
        resizeCanvas: any;
        render: any;
        logBuffer: (buffer: GPUBuffer, size: number) => void;
    }
}