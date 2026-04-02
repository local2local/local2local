const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v2.6 (Renderer-Safe Edition)
 * Optimized for local filesystem synchronization before GitHub Push.
 * Uses non-backtick delimiters to prevent UI truncation.
 */

try {
    const input = fs.readFileSync(0, 'utf8');
    
    // Pattern: L2LAAF_BLOCK_START(TYPE:TITLE:PATH)CONTENT...L2LAAF_BLOCK_END
    const regex = /L2LAAF_BLOCK_START\((\w+):([^:\n\r]+):([^:\n\r]+)\)([\s\S]*?)L2LAAF_BLOCK_END/g;

    let count = 0;
    console.log('--- L2LAAF PATCHER v2.6 ---');
    console.log(`Stream size: ${input.length} characters.`);

    let match;
    while ((match = regex.exec(input)) !== null) {
        const filepath = match[3].trim();
        const content = match[4].trim();

        if (filepath === 'COMMIT_MSG') {
            fs.writeFileSync('.commit_msg.tmp', content);
            console.log(`✅ Metadata captured for git commit.`);
            continue; 
        }

        const fullPath = path.resolve(process.cwd(), filepath);
        
        // Security check
        if (!fullPath.startsWith(process.cwd())) {
            console.error(`❌ Security: Blocked out-of-bounds write to ${filepath}`);
            continue;
        }

        const dir = path.dirname(fullPath);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

        fs.writeFileSync(fullPath, content);
        console.log(`✅ [${++count}] Synchronized: ${filepath}`);
    }

    if (count === 0) {
        console.error('❌ Error: No valid L2LAAF logic blocks detected.');
        process.exit(1);
    }
} catch (err) {
    console.error(`SYSTEM CRASH: ${err.message}`);
    process.exit(1);
}