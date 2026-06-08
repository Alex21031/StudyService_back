# Lessons

## 2026-05-18
- If the user says they are handling a missing local dependency like Flutter themselves, do not treat that dependency as a blocker for the current task.
- Keep integration work moving on the parts that are still actionable, and scope verification to the components the current environment can actually run.

## 2026-05-31
- When adding localized study content, verify the payload returned for an older saved lecture instead of relying only on fixture-based smoke tests.
- If the UI still shows fallback-language text, inspect whether the backend is returning empty placeholder localization entries that prevent a cleaner fallback path.
- Treat localization as incomplete when stored translations are present but still in the wrong language; completeness checks must validate language quality, not just non-empty fields.

## 2026-06-04
- When a user asks for a UI redesign, do not stop at copy cleanup or subtle card polish if the screen still reads as the same layout; make at least one clearly visible structural change to the page.
- If the user says a redesign does not feel changed, treat that as a signal to revisit hierarchy, composition, and primary actions rather than only adjusting styling tokens.
- If a user points out a surface that feels like an internal or deployment-only control, remove it from the primary product UI instead of merely collapsing or softening it.
- If the user asks for login and signup to feel separate, do not keep them as adjacent buttons in the same generic form; give each mode its own interface and state.
- If the user says a screen has too many boxes or too much text, reduce the number of sections first; compressing copy inside the same layout is not enough.
- If the user provides a concrete landing-page reference structure, mirror that hierarchy closely instead of only borrowing the visual tone.
- If a landing page still feels like an internal dashboard, remove large section wrapper cards and rely on full-width sections plus contained inner content instead.
- If the user asks to simplify a landing-page navigation bar, remove non-essential menu items instead of preserving them for completeness.
- If you remove a shared UI block during refactoring, search for stale references before considering the page done.
- If the user says the auth pages still feel noisy, remove explanatory side panels and boxed page headers instead of only shortening the text inside them.
- If the user says the logged-in experience still shows landing-page marketing, split the authenticated dashboard branch from the public landing page at the top of the screen flow instead of trying to hide sections later with styling alone.
- If the user says the interior product pages feel cramped or boxy, remove one whole layer of wrapper cards before tuning colors or typography; nested panels are usually the bigger problem than styling.
- If AI-generated quiz creation feels slow, look first for per-item or per-language fallback calls and replace them with one batched generation/localization pass before tuning UI behavior.
