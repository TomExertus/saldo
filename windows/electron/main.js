const { app, BrowserWindow, ipcMain, dialog, Notification, shell } = require('electron');
const path = require('path');
const fs = require('fs');

function createWindow() {
  const win = new BrowserWindow({
    width: 1220,
    height: 860,
    minWidth: 420,
    minHeight: 600,
    backgroundColor: '#070b14',
    title: 'Saldo e Movimenti',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  const localIndex = path.join(__dirname, 'www', 'index.html');
  const webIndex = path.join(__dirname, '..', '..', 'web', 'index.html');
  const wwwIndex = path.join(__dirname, '..', '..', 'www', 'index.html');
  const fallbackIndex = fs.existsSync(webIndex) ? webIndex : wwwIndex;
  win.loadFile(fs.existsSync(localIndex) ? localIndex : fallbackIndex);

  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      shell.openExternal(url);
      return { action: 'deny' };
    }
    return { action: 'allow' };
  });
}

ipcMain.handle('saldo:save-file', async (_event, fileName, content) => {
  const { canceled, filePath } = await dialog.showSaveDialog({
    title: 'Salva su File',
    defaultPath: fileName || 'saldo-dati.json',
    filters: [
      { name: 'File JSON Saldo', extensions: ['json'] },
      { name: 'Tutti i file', extensions: ['*'] }
    ]
  });
  if (canceled || !filePath) return null;
  fs.writeFileSync(filePath, content, 'utf8');
  return filePath;
});

ipcMain.on('saldo:notify', (_event, title, body) => {
  if (Notification.isSupported()) {
    new Notification({ title: title || 'Saldo e Movimenti', body: body || '' }).show();
  }
});

app.whenReady().then(() => {
  if (process.platform === 'win32') {
    app.setAppUserModelId('com.tommasonguyen.saldomovimenti');
  }
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
