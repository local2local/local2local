const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v4.2 (NASA Standard - High Integrity)
 * Hardened against token stripping and character corruption.
 */

try {
    const input = fs.readFileSync(0, 'utf8');
    const regex = /L2LAAF_BLOCK_START\((\w+):([^:\)\n\r]+):([^:\)\n\r]+)\)([\s\S]*?)L2LAAF_BLOCK_END/g;

    let count = 0;
    console.log('--- L2LAAF PATCHER v4.2 ---');

    let match;
    while ((match = regex.exec(input)) !== null) {
        const filepath = match[3].trim();
        let content = match[4];

        // Root Cause Fix 1: High-integrity token reconstruction
        content = content.replace(/__BACKTICK__/g, '`');

        // Root Cause Fix 2: Scrub Null Bytes and binary noise
        content = content.replace(/\0/g, '').trim();

        if (filepath === 'COMMIT_MSG') {
            fs.writeFileSync('.commit_msg.tmp', content, 'utf8');
            console.log('✅ Metadata: COMMIT_MSG captured.');
            continue; 
        }

        const fullPath = path.resolve(process.cwd(), filepath);
        const dir = path.dirname(fullPath);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

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