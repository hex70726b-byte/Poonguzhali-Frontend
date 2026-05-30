const fs = require('fs');
const content = fs.readFileSync('lib/main.dart', 'utf8');
const lines = content.split(/\r?\n/);

lines.forEach((line, idx) => {
  if (line.includes('=>') && (line.includes('any') || line.includes('where') || line.includes('firstWhere') || line.includes('map') || line.includes('forEach'))) {
    console.log(`Line ${idx + 1}: ${line.trim()}`);
  }
});
