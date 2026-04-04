const fs = require('fs');
const path = require('path');

/**
 * L2LAAF PATCHER v6.1
 * Processes multi-block payloads from stdin.
 * Automates placeholder restoration for canvas-to-canvas resilience.
 */

function processContent(content) {
    if (!content) return "";
    
    let sanitized = content;
    
    // 1. Restore TypeScript generics from placeholders
    // Handles both terminal-standard (__LT__) and canvas-auto-convert ({{)
    sanitized = sanitized.replace(/__LT__/g, '<').replace(/__GT__/g, '>');
    sanitized = sanitized.replace(/\{\{/g, '<').replace(/\}\}/g, '>');
    
    // 2. Remove clipboard/markdown backslash escapes introduced by UI rendering
    sanitized = sanitized.replace(/\\\[/g, '[').replace(/\\\]/g, ']');
    sanitized = sanitized.replace(/\\\$/g, '$');
    sanitized = sanitized.replace(/\\\*/g, '*');
    sanitized = sanitized.replace(/\\-/g, '-');
    
    // 3. Restore backticks encoded as placeholders
    sanitized = sanitized.replace(/\[BACKTICK\]/g, '`');
    
    return sanitized;
}

try {
    // Read the entire payload from stdin (Redirected by relay.sh)
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
        
        // Ensure directory exists
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