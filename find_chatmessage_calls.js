const fs = require('fs');
const content = fs.readFileSync('lib/main.dart', 'utf8');
const lines = content.split(/\r?\n/);

lines.forEach((line, idx) => {
  if (line.includes('ChatMessage(')) {
    console.log(`Line ${idx + 1}: ${line.trim()}`);
    // Print next 6 lines
    for (let i = 1; i <= 8; i++) {
      if (lines[idx + i]) {
        console.log(`  +${i}: ${lines[idx + i].trim()}`);
      }
    }
  }
});
