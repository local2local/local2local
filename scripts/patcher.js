const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v1.9 (Robust Edition)
 * Handles varying line endings and provides detailed debug logs.
 * Usage: pbpaste | node scripts/patcher.js
 */

const input = fs.readFileSync(0, 'utf8');

// Constructing a robust regex that handles \n, \r\n, and varying whitespace
const bt = String.fromCharCode(96); // The backtick character
const pattern = `${bt}{3}(\\w+):([^:\\n\\r]+):([^:\\n\\r]+)[\\r\\n]+([\\s\\S]*?)[\\r\\n]+${bt}{3}eof`;
const regex = new RegExp(pattern, 'g');

let match;
let count = 0;

console.log('--- L2LAAF PATCHER v1.9: SCANNING CLIPBOARD ---');

while ((match = regex.exec(input)) !== null) {
    // Group 3 is the filepath, Group 4 is the content
    const filepath = match[3].trim();
    const content = match[4];
    
    // Safety check: Prevent directory traversal
    const fullPath = path.resolve(process.cwd(), filepath);
    if (!fullPath.startsWith(process.cwd())) {
        console.error(`❌ Security Violation: Blocked write to ${filepath}`);
        continue;
    }

    const dir = path.dirname(fullPath);

    try {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }

        fs.writeFileSync(fullPath, content);
        console.log(`✅ [${++count}] Sync Successful: ${filepath}`);
    } catch (err) {
        console.error(`❌ Sync Failed: ${filepath} -> ${err.message}`);
    }
}

if (count === 0) {
    console.log('--- DEBUG INFO ---');
    console.log(`Input Length: ${input.length} characters`);
    console.log(`Starts with: "${input.substring(0, 50).replace(/\n/g, '\\n')}"`);
    console.log('------------------');
    console.log('⚠️ ERROR: No L2LAAF file blocks found. Ensure you copied the FULL AI response.');
    process.exit(1);
} else {
    console.log(`--- SUCCESS: ${count} CORE FILES SYNCHRONIZED ---`);
}