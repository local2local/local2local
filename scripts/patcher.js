const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v2.5 (The "Hardened Vacuum" Edition)
 * Optimized for the Canvas Payload Method.
 * Uses stdin ingestion and runtime regex reconstruction to bypass truncation.
 * Lead: Senior Cloud Architect
 */

try {
    // Read from stdin (fd 0) to capture the full payload without truncation
    const input = fs.readFileSync(0, 'utf8');
    
    // Character reconstruction to keep source free of rendering triggers
    const b = String.fromCharCode(96); // backtick (`)
    const s = String.fromCharCode(92); // backslash (\)

    /**
     * Pattern Reconstruction
     * We build the regex string dynamically to ensure no literal triple-backticks 
     * appear in this source code, preventing renderer truncation.
     */
    const p = s + b + "{3}(\\w+):([^:\\n\\r]+):([^:\\n\\r]+)[\\s\\S]*?([\\s\\S]*?)" + s + b + "{3}eof";
    const regex = new RegExp(p, 'g');

    let count = 0;
    let commitMsg = '';

    console.log('--- L2LAAF PATCHER v2.5 ---');
    console.log(`Payload size: ${input.length} characters detected`);

    let match;
    while ((match = regex.exec(input)) !== null) {
        const title = match[2].trim();
        const filepath = match[3].trim();
        const rawContent = match[4];

        // Clean content: Remove the header tail residue (the first line break)
        const lines = rawContent.split(/\r?\n/);
        const content = lines.slice(1).join('\n').trim();

        // Metadata extraction (from v2.4 logic)
        if (filepath === 'COMMIT_MSG') {
            commitMsg = content.trim();
            fs.writeFileSync('.commit_msg.tmp', commitMsg);
            console.log(`✅ Metadata found: "${commitMsg}"`);
            continue; 
        }

        const fullPath = path.resolve(process.cwd(), filepath);
        
        // Security boundary check: ensure we stay inside the project root
        if (!fullPath.startsWith(process.cwd())) {
            console.error(`❌ Security: Blocked out-of-bounds write to ${filepath}`);
            continue;
        }

        const dir = path.dirname(fullPath);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

        fs.writeFileSync(fullPath, content);
        console.log(`✅ [${++count}] Synchronized: ${filepath} (${title})`);
    }

    if (count === 0 && !commitMsg) {
        console.error('⚠️ Error: No valid L2LAAF file blocks detected in stdin.');
        process.exit(1);
    }

    console.log(`--- SUCCESS: ${count} FILES SYNCED TO LOCAL REPOSITORY ---`);
} catch (err) {
    console.error(`SYSTEM CRASH: ${err.message}`);
    process.exit(1);
}