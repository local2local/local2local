const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v3.0 (Corruption-Resistant Edition)
 * Actively scrubs Null Bytes and invisible control characters to prevent
 * "File appears to be binary" errors and YAML parsing failures.
 */

try {
    const input = fs.readFileSync(0, 'utf8');
    const regex = /L2LAAF_BLOCK_START\((\w+):([^:\)\n\r]+):([^:\)\n\r]+)(?::(\w+))?\)([\s\S]*?)L2LAAF_BLOCK_END/g;

    let count = 0;
    console.log('--- L2LAAF PATCHER v3.0 ---');

    let match;
    while ((match = regex.exec(input)) !== null) {
        const filepath = match[3].trim();
        const encoding = match[4] ? match[4].trim() : 'text';
        let rawContent = match[5].trim();
        let content = '';

        if (encoding === 'base64') {
            // Scrub any whitespace or hidden chars before decoding
            const cleanBase64 = rawContent.replace(/[^A-Za-z0-9+/=]/g, '');
            content = Buffer.from(cleanBase64, 'base64').toString('utf8');
        } else {
            content = rawContent;
        }

        // --- ANTI-CORRUPTION LAYER ---
        // Strip Null Bytes (\0) and ensure valid UTF-8 for YAML/TS
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