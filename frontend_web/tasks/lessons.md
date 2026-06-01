# Lessons

## 2026-05-18
- If the user says they are handling a missing local dependency like Flutter themselves, do not treat that dependency as a blocker for the current task.
- Keep integration work moving on the parts that are still actionable, and scope verification to the components the current environment can actually run.

## 2026-05-31
- When adding localized study content, verify the payload returned for an older saved lecture instead of relying only on fixture-based smoke tests.
- If the UI still shows fallback-language text, inspect whether the backend is returning empty placeholder localization entries that prevent a cleaner fallback path.
- Treat localization as incomplete when stored translations are present but still in the wrong language; completeness checks must validate language quality, not just non-empty fields.
