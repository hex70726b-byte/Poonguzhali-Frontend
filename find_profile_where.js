const fs = require('fs');
const content = fs.readFileSync('lib/profile_page.dart', 'utf8');
const lines = content.split(/\r?\n/);

const keywords = ['.where(', '.any(', '.firstWhere(', '.indexWhere(', '.removeWhere(', '.retainWhere('];

lines.forEach((line, idx) => {
  let found = false;
  keywords.forEach(kw => {
    if (line.includes(kw)) found = true;
  });
  if (found) {
    console.log(`Line ${idx + 1}: ${line.trim()}`);
    for (let i = -3; i <= 3; i++) {
      if (i !== 0 && lines[idx + i]) {
        console.log(`  [${idx + 1 + i}]: ${lines[idx + i].trim()}`);
      }
    }
    console.log('--------------------');
  }
});
