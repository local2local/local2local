const fs = require('fs');
const path = require('path');

/**
 * L2LAAF PATCHER v8.0 (Minimalist)
 * Processes multi-block payloads from stdin.
 * Zero-Touch implementation: No sanitization or character substitution.
 */

function processContent(content) {
    // Pure extraction - no modifications to the string
    return content || "";
}

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
        const finalContent = processContent(rawContent.trim());
        
        const dir = path.dirname(finalPath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        
        fs.writeFileSync(finalPath, finalContent, 'utf8');
        console.log(`✅ [${++blocksProcessed}] Synchronized: ${filePath.trim()} (${title.trim()})`);
    }

    if (blocksProcessed === 0) {
        console.error("❌ Error: No valid L2LAAF_BLOCK sections found in input.");
        process.exit(1);
    }
} catch (err) {
    console.error("❌ Fatal Patcher Error:", err.message);
    process.exit(1);
}