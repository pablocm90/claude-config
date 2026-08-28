# Connascence — TypeScript/React Supplement

React-specific material beyond the language notes in SKILL.md.

## CoE smell: custom hooks that require call order

Rules of hooks give React inherent, framework-managed CoE (call order, dependency arrays). Custom hooks that *additionally* require a specific internal call order re-expose CoE to maintainers:

```typescript
// ❌ CoE smell — hooks that must be called in a specific order
const useBalanceTab = (debtorId: string) => {
  const config = useCompanyConfiguration(); // must come first
  const balance = useLoadDebtorBalance(debtorId); // depends on config being loaded
  // ...
};
```

Fix as with any CoE: encapsulate the ordering — have the dependent hook load its own prerequisites, or take them as explicit arguments so the dependency becomes CoN.
