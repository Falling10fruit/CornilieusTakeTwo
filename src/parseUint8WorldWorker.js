onmessage = (message) => {
    const { Uint8World } = message.data;
    const worldData = new Uint8Array(Uint8World.length); // first value is tile type, second value is health

    const noOfTiles = Uint8World.length/4;
    for (let i = 0; i < noOfTiles; i += 4) {
        const tileType = Uint8World[i];
        const tileCarved = Uint8World[i + 1];

        worldData[i] = tileType;

        if (tileCarved == 0 ) {
            worldData[i + 1] = 0;
            continue;
        }

        switch (tileType) {
            case 0: // green stone
                worldData[i + 1] = 60;
            case 1: // dark stone
                worldData[i + 1] = 80;
            case 2: // aquarite
                worldData[i + 1] = 50;
            case 3: // ice
                worldData[i + 1] = 30;
        }
    }

    // console.log(worldData)

    postMessage({ worldData });
}