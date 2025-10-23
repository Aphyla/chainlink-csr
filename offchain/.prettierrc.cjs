/**
 * Prettier configuration
 * 
 * Based on industry standards from major tech companies:
 * - Google: Consistent, minimal config
 * - Microsoft: TypeScript-friendly settings
 * - Meta: Performance-optimized
 * 
 * @see https://prettier.io/docs/en/configuration.html
 */
module.exports = {
  // Core formatting
  semi: true,                    // Always use semicolons (safety & consistency)
  singleQuote: true,            // Prefer single quotes (less visual noise)
  quoteProps: 'as-needed',      // Only quote props when necessary
  trailingComma: 'es5',         // Trailing commas where valid in ES5 (safer diffs)
  
  // Indentation & spacing
  tabWidth: 2,                  // 2 spaces (industry standard)
  useTabs: false,               // Spaces for consistency across editors
  
  // Line handling
  printWidth: 80,               // 80 chars (readable, fits most screens)
  endOfLine: 'lf',              // Unix line endings (consistent across platforms)
  
  // Bracket spacing
  bracketSpacing: true,         // { foo: bar } not {foo: bar}
  bracketSameLine: false,       // Put > on new line for readability
  
  // Arrow functions
  arrowParens: 'avoid',         // x => x not (x) => x (cleaner for single args)
  
  // TypeScript specific
  parser: 'typescript',         // Default parser for .ts files
  
  // File-specific overrides
  overrides: [
    {
      files: '*.json',
      options: {
        parser: 'json',
        trailingComma: 'none',  // JSON doesn't support trailing commas
      },
    },
    {
      files: '*.md',
      options: {
        parser: 'markdown',
        printWidth: 100,        // Longer lines OK for markdown
        proseWrap: 'preserve',  // Don't rewrap prose
      },
    },
    {
      files: '*.yaml',
      options: {
        parser: 'yaml',
        singleQuote: false,     // YAML prefers double quotes
      },
    },
  ],
}; 