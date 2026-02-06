# Claude Code Skills for get_it

This directory contains **Claude Code skill files** that help AI assistants (like Claude Code, Cursor, GitHub Copilot) generate correct get_it code efficiently.

## What are Skills?

Skills are concise reference guides optimized for AI consumption. They contain:
- Critical rules and constraints
- Common usage patterns
- Anti-patterns with corrections
- Integration examples

**Note**: These are NOT replacements for comprehensive documentation. For detailed guides, see https://flutter-it.dev/documentation/get_it/

## Available Skills

This directory includes:

1. **`get_it-expert.md`** - get_it patterns, registration, scopes, async initialization
2. **`flutter-architecture-expert.md`** - High-level app architecture guidance

**Note**: For the ecosystem overview, see `/skills/flutter_it.md` in the monorepo root.

## Installation

To use these skills with Claude Code:

### Option 1: Copy to Global Skills Directory (Recommended)

```bash
# Copy all skills to your global Claude Code skills directory
cp skills/*.md ~/.claude/skills/
```

### Option 2: Symlink (Auto-updates when package updates)

```bash
# Create symlinks (Linux/Mac)
ln -s $(pwd)/skills/get_it-expert.md ~/.claude/skills/get_it-expert.md
ln -s $(pwd)/skills/flutter-architecture-expert.md ~/.claude/skills/flutter-architecture-expert.md
```

### Option 3: Manual Copy (Windows)

```powershell
# Copy files manually
copy skills\*.md %USERPROFILE%\.claude\skills\
```

## Using the Skills

Once installed, Claude Code will automatically have access to these skills when working on Flutter projects.

**For other AI assistants**:
- **Cursor**: Copy to project root or reference in `.cursorrules`
- **GitHub Copilot**: Copy to `.github/copilot-instructions.md`

## Verification

After installation, you can verify by asking Claude Code:

```
Can you help me set up get_it for dependency injection?
```

Claude should reference the skill and provide correct registration patterns.

## Contents Overview

### get_it-expert.md (~1200 tokens)

Covers:
- Basic registration patterns (singleton, lazy singleton, factory)
- Async initialization with `allReady()`
- Scopes for session management
- Named instances
- Disposal patterns
- Testing patterns
- Common anti-patterns

### flutter-architecture-expert.md (~800 tokens)

Covers:
- Startup orchestration with get_it
- Layer structure (domain/data/presentation)
- State management with managers
- Scoped services for user sessions
- Testing patterns

## Documentation Links

- **Comprehensive docs**: https://flutter-it.dev/documentation/get_it/
- **Package README**: https://pub.dev/packages/get_it
- **GitHub**: https://github.com/escamoteur/get_it
- **Discord**: https://discord.gg/ZHYHYCM38h

## Contributing

Found an issue or have suggestions for improving these skills?
- Open an issue on GitHub
- Join the Discord community
- Submit a PR with improvements

---

**Note**: These skills are designed for AI consumption. For human-readable documentation, please visit https://flutter-it.dev
