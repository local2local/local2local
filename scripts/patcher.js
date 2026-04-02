const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v1.7 (UI-Safe Version)
 * This version avoids literal triple-backticks to prevent UI fragmentation.
 * Usage: pbpaste | node scripts/patcher.js
 */

const input = fs.readFileSync(0, 'utf8');

// Constructing the backtick sequence dynamically to avoid UI parser errors
const bt = String.fromCharCode(96);
const pattern = `${bt}${bt}${bt}(\\w+):(.*?):(.*?)\\n([\\s\\S]*?)\\n${bt}${bt}${bt}eof`;
const regex = new RegExp(pattern, 'g');

let match;
let count = 0;

console.log('--- L2LAAF PATCHER: SYNCHRONIZING FILES ---');

while ((match = regex.exec(input)) !== null) {
    // Group 3 is the filepath, Group 4 is the file content
    const filepath = match[3].trim();
    const content = match[4];
    
    const fullPath = path.resolve(process.cwd(), filepath);

    // Security Guard: Prevent writing files outside of the project directory
    if (!fullPath.startsWith(process.cwd())) {
        console.error(`❌ Security Violation: Unauthorized path: ${filepath}`);
        continue;
    }

    const dir = path.dirname(fullPath);

    try {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }

        fs.writeFileSync(fullPath, content);
        console.log(`✅ [${++count}] Updated: ${filepath}`);
    } catch (err) {
        console.error(`❌ Failed to synchronize ${filepath}: ${err.message}`);
    }
}

if (count === 0) {
    console.log('⚠️ No valid file blocks detected. Ensure you copied the entire AI response.');
    process.exit(1);
} else {
    console.log(`--- SUCCESS: ${count} FILES UPDATED ---`);
}