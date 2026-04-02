const fs = require('fs');
const path = require('path');

/**
 * L2LAAF Logic Patcher v2.2 (Fragment-Proof Edition)
 * This version uses zero literal backticks in its own source to prevent
 * browser markdown parsing errors during "Guided Autonomy" transfers.
 */

try {
    const input = fs.readFileSync(0, 'utf8');
    
    // Constructing the marker components using character codes
    // 96 is the code for a backtick (`)
    const b = String.fromCharCode(96);
    const triple = b + b + b;
    
    // Pattern: ^^^(\w+):([^:\n\r]+):([^:\n\r]+)[\s\r\n]+([\s\S]*?)[\s\r\n]+^^^eof
    // We use double-backslashes for the RegExp constructor
    const pattern = "\\" + b + "{3}(\\w+):([^:\\n\\r]+):([^:\\n\\r]+)[\\s\\r\\n]+([\\s\\S]*?)[\\s\\r\\n]+\\" + b + "{3}eof";
    const regex = new RegExp(pattern, 'g');

    let match;
    let count = 0;

    console.log('--- L2LAAF PATCHER v2.2 ---');
    console.log(`Input size: ${input.length} characters`);

    while ((match = regex.exec(input)) !== null) {
        // Group 3 is the filepath, Group 4 is the file content
        const filepath = match[3].trim();
        const content = match[4];
        
        const fullPath = path.resolve(process.cwd(), filepath);

        // Security Guard: Prevent writing outside the current working directory
        if (!fullPath.startsWith(process.cwd())) {
            console.error(`❌ Security Violation: Attempted write to ${filepath}`);
            continue;
        }

        const dir = path.dirname(fullPath);

        try {
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }

            fs.writeFileSync(fullPath, content);
            console.log(`✅ [${++count}] Applied update: ${filepath}`);
        } catch (err) {
            console.error(`❌ Sync Failed: ${filepath} -> ${err.message}`);
        }
    }

    if (count === 0) {
        console.log('--- DIAGNOSTICS ---');
        console.log(`Triple-backtick sequence present in input: ${input.includes(triple)}`);
        console.log(`EOF marker present in input: ${input.includes(triple + 'eof')}`);
        console.log('--- DATA PREVIEW (First 200 chars) ---');
        console.log(input.substring(0, 200).replace(/\n/g, '\\n'));
        console.log('--------------------------------------');
        console.log('⚠️ Error: No valid L2LAAF file blocks detected.');
        process.exit(1);
    } else {
        console.log(`--- SUCCESS: ${count} CORE FILES SYNCHRONIZED ---`);
    }
} catch (err) {
    console.error(`SYSTEM ERROR: ${err.message}`);
    process.exit(1);
}