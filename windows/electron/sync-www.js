const fs = require('fs');
const path = require('path');

const srcDir = path.resolve(__dirname, '../../www');
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
