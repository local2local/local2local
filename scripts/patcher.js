const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v2.3 (Metadata-Aware)
 * Extracts files AND identifies embedded commit messages for the Relay.
 */

try {
    const input = fs.readFileSync(0, 'utf8');
    const b = String.fromCharCode(96);
    const pattern = "\\" + b + "{3}(\\w+):([^:\\n\\r]+):([^:\\n\\r]+)[\\s\\r\\n]+([\\s\\S]*?)[\\s\\r\\n]+\\" + b + "{3}eof";
    const regex = new RegExp(pattern, 'g');

    let match;
    let count = 0;
    let commitMsg = '';

    console.log('--- L2LAAF PATCHER v2.3 ---');

    while ((match = regex.exec(input)) !== null) {
        const filepath = match[3].trim();
        const content = match[4];
        
        // SPECIAL CASE: Extract Commit Message for Relay
        if (filepath === 'COMMIT_MSG') {
            commitMsg = content.trim();
            // Write to a temporary file that the shell script can read
            fs.writeFileSync('.commit_msg.tmp', commitMsg);
            continue; 
        }

        const fullPath = path.resolve(process.cwd(), filepath);
        if (!fullPath.startsWith(process.cwd())) continue;

        const dir = path.dirname(fullPath);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

        fs.writeFileSync(fullPath, content);
        console.log(`✅ [${++count}] Synced: ${filepath}`);
    }

    if (count === 0 && !commitMsg) {
        console.log('⚠️ Error: No valid file blocks or commit metadata detected.');
        process.exit(1);
    }

    console.log(`--- SUCCESS: ${count} FILES + METADATA SYNCED ---`);
} catch (err) {
    console.error(`SYSTEM ERROR: ${err.message}`);
    process.exit(1);
}