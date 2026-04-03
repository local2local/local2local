const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v4.0 (NASA Standard - Tokenized Literal Protocol)
 * Replaces _BT_ tokens with backticks and scrubs hidden binary corruption.
 */

try {
    const input = fs.readFileSync(0, 'utf8');
    // Regex for standard text blocks
    const regex = /L2LAAF_BLOCK_START\((\w+):([^:\)\n\r]+):([^:\)\n\r]+)\)([\s\S]*?)L2LAAF_BLOCK_END/g;

    let count = 0;
    console.log('--- L2LAAF PATCHER v4.0 ---');

    let match;
    while ((match = regex.exec(input)) !== null) {
        const filepath = match[3].trim();
        let content = match[4];

        // Root Cause Fix 1: Reconstruct template literals
        content = content.replace(/_BT_/g, '`');

        // Root Cause Fix 2: Scrub Null Bytes and non-UTF8 binary noise
        content = content.replace(/\0/g, '').trim();

        if (filepath === 'COMMIT_MSG') {
            fs.writeFileSync('.commit_msg.tmp', content, 'utf8');
            console.log(`✅ Metadata: COMMIT_MSG captured.`);
            continue; 
        }

        const fullPath = path.resolve(process.cwd(), filepath);
        const dir = path.dirname(fullPath);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

        // Force write as clean UTF-8
        fs.writeFileSync(fullPath, content, { encoding: 'utf8', flag: 'w' });
        console.log(`✅ [${++count}] Synchronized: ${filepath}`);
    }

    if (count === 0) {
        console.error('❌ Error: No valid L2LAAF logic blocks detected.');
        process.exit(1);
    }
} catch (err) {
    console.error(`SYSTEM ERROR: ${err.message}`);
    process.exit(1);
}