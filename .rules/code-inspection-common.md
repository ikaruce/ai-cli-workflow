# Code Quality Management & Inspection Standards

## Purpose of Quality Management
This project follows the **SonarQube Clean Code Taxonomy** to ensure the codebase remains healthy, scalable, and easy to collaborate on. The core objectives are:

1. **Consistency**: Ensure the code is uniform and predictable, making it easier for any developer (or AI) to read and understand.
2. **Intentionality**: Every line of code must have a clear purpose. We aim to eliminate ambiguity and dead logic.
3. **Adaptability**: The code must be easy to evolve and refactor. We prioritize low coupling and high cohesion to ensure long-term maintenance.
4. **Responsibility**: Code should be robust and handle edge cases gracefully, ensuring the reliability of the system's behavior.

## Expected Effects
- **Reduced Technical Debt**: Early detection of "Code Smells" prevents future refactoring costs.
- **Improved Team Velocity**: Standardized patterns reduce the cognitive load required to understand new features.
- **Enhanced AI Accuracy**: By providing clear "Clean Code" constraints, the AI generates more precise and production-ready suggestions.

---

## Universal Inspection Rules (Reliability & Maintainability)

### 1. Reliability (Bug Prevention)
- **Logical Soundness**: Do not use the same expression on both sides of a binary operator (e.g., `if (a == a)`).
- **Resource Management**: Always ensure resources (files, connections, streams) are explicitly closed after use, preferably using language-specific "try-with-resources" or "context manager" patterns.
- **Null Safety**: Proactively check for null/undefined values before accessing properties or methods to prevent runtime crashes.
- **Unreachable Code**: Eliminate code blocks that can never be executed (e.g., code after a unconditional `return` or `throw`).

### 2. Maintainability (Code Smells)
- **Cognitive Complexity**: Keep the cognitive complexity of any function or method below **31**. Avoid deep nesting of `if`, `switch`, or loops.
- **DRY (Don't Repeat Yourself)**: If a logic block is repeated more than twice, extract it into a reusable function or module.
- **Dead Code Removal**: Remove all unused variables, unused imports, and commented-out code blocks immediately.
- **Magic Numbers/Strings**: Never use hardcoded literals in business logic. Replace them with well-named constants.
- **Naming Intent**: Names must reveal intent. Avoid single-letter variables (except for loop counters like `i`) or generic names like `data`, `info`, or `temp`.

---

## AI Instruction

1. **Definition of Done**: A task is only considered "done" if the resulting code is both functional and compliant with the Clean Code standards defined above.
2. **Proactive Refactoring**: When asked to modify existing code, scan for existing "Code Smells" in the surrounding context and suggest refactors if they violate the 31-point complexity limit.
3. **Self-Correction Loop**: Before providing a final code snippet, perform a mental "Sonar Scan." If the code violates any reliability or maintainability rules, correct it and explain why.
4. **Consistency Check**: Ensure the new code matches the existing project's naming conventions and architectural patterns.
5. **No Technical Debt**: Never suggest a "quick fix" that introduces technical debt (e.g., `any` types, ignored errors, or duplicated logic) unless explicitly requested for temporary debugging.