const fs = require('fs');
const path = require('path');
const os = require('os');

/**
 * L2LAAF Logic Patcher v2.8 (Newline Preservation Edition)
 * Fixes "Wall of Text" bug by explicitly handling line endings.
 */

try {
    const input = fs.readFileSync(0, 'utf8');
    
    // Pattern: L2LAAF_BLOCK_START(TYPE:TITLE:PATH)CONTENT...L2LAAF_BLOCK_END
    const regex = /L2LAAF_BLOCK_START\((\w+):([^:\)\n\r]+):([^:\)\n\r]+)\)([\s\S]*?)L2LAAF_BLOCK_END/g;

    let count = 0;
    console.log('--- L2LAAF PATCHER v2.8 ---');
    console.log(`Stream size: ${input.length} characters.`);

    let match;
    while ((match = regex.exec(input)) !== null) {
        const filepath = match[3].trim();
        let content = match[4].trim();

        // Handle Metadata
        if (filepath === 'COMMIT_MSG') {
            fs.writeFileSync('.commit_msg.tmp', content);
            console.log(`✅ Metadata captured for git commit.`);
            continue; 
        }

        // Fix potential "Wall of Text" by ensuring code blocks have proper spacing
        // if they were mangled by buffer transfers
        if (!content.includes('\n') && content.length > 100) {
            console.warn(`⚠️ Warning: Block ${filepath} appears to be a single line. Attempting recovery...`);
            content = content.replace(/([;{}])(?!\n)/g, '$1' + os.EOL);
        }

        const fullPath = path.resolve(process.cwd(), filepath);
        const dir = path.dirname(fullPath);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

        fs.writeFileSync(fullPath, content, 'utf8');
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