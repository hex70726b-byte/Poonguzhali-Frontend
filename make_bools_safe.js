const fs = require('fs');

const path = 'lib/main.dart';
let content = fs.readFileSync(path, 'utf8');

// Replace any/firstWhere closures
content = content.replace(/messages\.any\(\(m\) => m\.isPinned\)/g, 'messages.any((m) => m.isPinned == true)');
content = content.replace(/messages\.firstWhere\(\(m\) => m\.isPinned\)/g, 'messages.firstWhere((m) => m.isPinned == true)');

// Replace inline conditional evaluations inside ListView item builder and Bottom Sheet
content = content.replace(/if \(msg\.isPinned\)/g, 'if (msg.isPinned == true)');
content = content.replace(/if \(msg\.isEdited\)/g, 'if (msg.isEdited == true)');
content = content.replace(/msg\.isPinned\s*\?/g, '(msg.isPinned == true) ?');

fs.writeFileSync(path, content, 'utf8');
console.log("SUCCESS: Made all boolean evaluations safe against Null!");
