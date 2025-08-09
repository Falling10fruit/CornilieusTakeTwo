const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('node:path');

const createWindow = () => {
  const win = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js')
    }
  });

  win.loadFile('src/index.html')
}

app.whenReady().then(() => { createWindow() });

// quitting the app when no windows are open on non-macOS platforms
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit() });