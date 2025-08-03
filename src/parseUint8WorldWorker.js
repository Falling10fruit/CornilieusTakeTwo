onmessage = (message) => {
    const {width, height, seed} = message.data;

    const data = [];
    
    for (let i = 0; i < width * height; i++) {
        data.push({
            type: Math.floor(Math.random()*2),
            health: 10
        });

        dataGPU[i * 4 + 0] = data[i].type;
    }

    postMessage();
}