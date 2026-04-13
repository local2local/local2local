const fs = require('fs');
const path = require('path');

/**
 * L2LAAF PATCHER v8.2 (User-Friendly Logs)
 * Fix: Only removes the wrapping newlines from blocks.
 * Update: Displays actual commit message in logs for COMMIT_MSG files.
 */

try {
    const rawInput = fs.readFileSync(0, 'utf8');
    if (!rawInput || rawInput.trim().length === 0) {
        console.error("❌ Error: Payload input is empty.");
        process.exit(1);
    }

    const blockRegex = /L2LAAF_BLOCK_START\((.*?):(.*?):(.*?)\)([\s\S]*?)L2LAAF_BLOCK_END/g;
    let match;
    let blocksProcessed = 0;

    while ((match = blockRegex.exec(rawInput)) !== null) {
        const [fullMatch, type, title, filePath, rawContent] = match;
        
        const finalPath = path.resolve(process.cwd(), filePath.trim());
        
        // Clean only the leading and trailing newline added by the block format
        const cleanContent = rawContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "");
        
        const dir = path.dirname(finalPath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        
        fs.writeFileSync(finalPath, cleanContent, 'utf8');

        // Logic for specialized console logging
        const isCommitMsg = filePath.trim().toUpperCase() === 'COMMIT_MSG';
        const displayContext = isCommitMsg ? `"${cleanContent.trim()}"` : title.trim();
        
        console.log(`✅ [${++blocksProcessed}] Synchronized: ${filePath.trim()} (${displayContext})`);
    }

    if (blocksProcessed === 0) {
        console.error("❌ Error: No valid L2LAAF_BLOCK sections found in input.");
        process.exit(1);
    }
} catch (err) {
    console.error("❌ Fatal Patcher Error:", err.message);
    process.exit(1);
}