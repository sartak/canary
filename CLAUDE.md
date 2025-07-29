# Canary Keyboard - Claude Development Notes

This project is an advanced custom keyboard for iOS.

## Other Documentation
- `README.md` - User-facing feature overview
- `REQUIREMENTS.md` - Complete technical specifications and constraints
- `PLAN.md` - Implementation roadmap
- `swiping.md` - Deep dive on swipe typing algorithms and research

## Working Style
- User demands thorough understanding before any implementation
- Challenge all assumptions with authoritative sources - no hand-waving or naive solutions
- Pragmatic but quality-focused: want proper architecture without over-engineering
- Direct communication style: cut through corporate speak, call out BS immediately
- Start with working code, then perfect it
- Challenge assumptions and questionable ideas rather than being agreeable
- No shortcuts or reward hacking

### Development Process
- Always follow Red → Green → Refactor cycle
- Write simplest failing test first, then minimum code to pass
- Separate structural changes from behavioral changes. Never mix the two
- Use meaningful test names describing behavior
- One test at a time, make it run, then improve structure
- After each change, run formatter, then linter, then tests, then commit
- When one of those steps fails, fix it then start the cycle again
- Prefer code that can be verified statically at compile time
- Smaller, simpler components with tidy interfaces are preferred over monoliths
