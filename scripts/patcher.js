const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v2.9 (Base64 Hardened Edition)
 * Supports standard text blocks and Base64 encoded blocks to prevent 
 * "Wall of Text" newline stripping issues.
 */

try {
    const input = fs.readFileSync(0, 'utf8');
    
    // Pattern: L2LAAF_BLOCK_START(TYPE:TITLE:PATH:ENCODING)CONTENT...L2LAAF_BLOCK_END
    const regex = /L2LAAF_BLOCK_START\((\w+):([^:\)\n\r]+):([^:\)\n\r]+)(?::(\w+))?\)([\s\S]*?)L2LAAF_BLOCK_END/g;

    let count = 0;
    console.log('--- L2LAAF PATCHER v2.9 ---');
    console.log(`Stream size: ${input.length} characters.`);

    let match;
    while ((match = regex.exec(input)) !== null) {
        const filepath = match[3].trim();
        const encoding = match[4] ? match[4].trim() : 'text';
        let rawContent = match[5].trim();
        let content = '';

        if (encoding === 'base64') {
            // Remove any whitespace introduced by line wrapping
            content = Buffer.from(rawContent.replace(/\s/g, ''), 'base64').toString('utf8');
        } else {
            content = rawContent;
        }

        // Handle Metadata
        if (filepath === 'COMMIT_MSG') {
            fs.writeFileSync('.commit_msg.tmp', content);
            console.log(`✅ Metadata captured for git commit.`);
            continue; 
        }

        const fullPath = path.resolve(process.cwd(), filepath);
        const dir = path.dirname(fullPath);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

        fs.writeFileSync(fullPath, content, 'utf8');
        console.log(`✅ [${++count}] Synchronized: ${filepath} (${encoding})`);
    }

    if (count === 0) {
        console.error('❌ Error: No valid L2LAAF logic blocks detected.');
        process.exit(1);
    }
} catch (err) {
    console.error(`SYSTEM ERROR: ${err.message}`);
    process.exit(1);
}