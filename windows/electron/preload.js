const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('WindowsBridge', {
  saveFile: (fileName, content) => ipcRenderer.invoke('saldo:save-file', fileName, content),
  showNotification: (title, body) => ipcRenderer.send('saldo:notify', title, body)
});
