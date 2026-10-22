const fs = require('fs');
const path = require('path');

const webDir = path.resolve(__dirname, '../../web');
const wwwDir = path.resolve(__dirname, '../../www');
const srcDir = fs.existsSync(webDir) ? webDir : wwwDir;
const destDir = path.resolve(__dirname, './www');

fs.mkdirSync(destDir, { recursive: true });
for (const entry of fs.readdirSync(srcDir)) {
  const srcFile = path.join(srcDir, entry);
  const destFile = path.join(destDir, entry);
  if (fs.statSync(srcFile).isFile()) {
    fs.copyFileSync(srcFile, destFile);
  }
}
console.log('Synced www assets into windows/electron/www');
