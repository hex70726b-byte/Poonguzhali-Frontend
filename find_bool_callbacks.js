const fs = require('fs');

const files = fs.readdirSync('lib').filter(f => f.endsWith('.dart'));

files.forEach(file => {
  const filePath = `lib/${file}`;
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split(/\r?\n/);
  
  lines.forEach((line, idx) => {
    if (line.includes('bool ') && line.includes('(')) {
      console.log(`${file}:${idx + 1}: ${line.trim()}`);
    }
  });
});
