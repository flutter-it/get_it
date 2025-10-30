# get_it Open Issues Analysis

**Date**: 2025-10-30
**Repository**: https://github.com/fluttercommunity/get_it

This document contains an analysis of all open issues in the get_it repository, categorized by implementation effort and potential benefit.

---

## 🟢 Easy to Implement & High Benefit (Quick Wins)

### #192: Add code coverage badge
- **URL**: https://github.com/fluttercommunity/get_it/issues/192
- **Effort**: Very Low (1-2 hours)
- **Benefit**: High - Improves project transparency and quality signals
- **Implementation**: Setup GitHub Actions with Codecov
- **Priority**: ⭐⭐⭐⭐⭐
- **Comments**: 9 comments discussing various coverage tools

### #319: Add `onCreated` callback on lazy and async singletons
- **URL**: https://github.com/fluttercommunity/get_it/issues/319
- **Effort**: Low (3-4 hours)
- **Benefit**: Medium - Useful for logging and side effects
- **Implementation**: Add optional `onCreated: (instance) {}` parameter, invoke after instance creation
- **Priority**: ⭐⭐⭐⭐
- **Details**:
  - Should work on `registerLazySingleton` and `registerSingletonAsync`
  - Question: Should it support async callbacks? Who would await it?
  - Question: Should it be included in the `isReady` state?

### #320: Add `resetLazySingletonsInScope`
- **URL**: https://github.com/fluttercommunity/get_it/issues/320
- **Effort**: Low (2-3 hours)
- **Benefit**: Medium - Useful for testing and memory management
- **Implementation**: Similar to existing reset methods, scoped to current active scope
- **Priority**: ⭐⭐⭐⭐
- **Referenced from**: Issue #302

---

## 🟡 Medium Effort & High Benefit

### #397: Lifecycle logging/observer pattern
- **URL**: https://github.com/fluttercommunity/get_it/issues/397
- **Effort**: Medium (1-2 days)
- **Benefit**: High - Great for debugging and monitoring
- **Implementation**: Observer pattern with callbacks for creation/disposal events
- **Priority**: ⭐⭐⭐⭐⭐
- **Comments**: 5 comments discussing implementation
- **Details**:
  - Similar to BlocObserver pattern from bloc library
  - User wants to log: `✅ $className INITIALIZED ✅` and `❌ $className DISPOSED ❌`
  - Challenge: Disposal isn't always guaranteed (GC, weak references)
  - Could log: instance creation, disposal callback invocation, unregistration
  - Reference: https://bloclibrary.dev/bloc-concepts/#observing-a-bloc

### #339: Make `registerLazySingletonAsync` have `dependsOn`
- **URL**: https://github.com/fluttercommunity/get_it/issues/339
- **Effort**: Medium (1 day)
- **Benefit**: High - Fills API gap, enables better async dependency management
- **Implementation**: Add `dependsOn` parameter like `registerSingletonAsync` has
- **Priority**: ⭐⭐⭐⭐
- **Comments**: 7 comments
- **Details**:
  - Current gap: Can't have lazy singleton depend on async singleton
  - Causes memory management issues when all dependencies initialized upfront
  - Related to #340 (async factories)

### #333: Verify GetIt configuration
- **URL**: https://github.com/fluttercommunity/get_it/issues/333
- **Effort**: Medium (2-3 days)
- **Benefit**: High - Catches configuration errors at test time instead of runtime
- **Implementation**: Add testing utility that validates dependency graph
- **Priority**: ⭐⭐⭐⭐
- **Comments**: No comments yet
- **Details**:
  - Similar to Koin's CheckModules: https://insert-koin.io/docs/reference/koin-test/checkmodules/
  - Reference implementation: https://github.com/InsertKoinIO/koin/blob/main/core/koin-test/src/commonMain/kotlin/org/koin/test/check/CheckModules.kt#L96
  - Implementation steps:
    1. Add/enforce module structure to retrieve all bean definitions
    2. Provide mocked/fake beans for the definitions
    3. Try getting the beans, fail test if definition isn't provided
  - Challenge: Last layer (e.g., ViewModel) might not be in config, causing false positives

---

## 🔴 Already Being Worked On

### #412: Improve README/Docs structure
- **URL**: https://github.com/fluttercommunity/get_it/issues/412
- **Status**: Already in progress! https://flutter-it.dev exists, planning docs in place
- **Effort**: Ongoing
- **Benefit**: Very High - Critical for user adoption
- **Priority**: ⭐⭐⭐⭐⭐
- **Comments**: 4 comments discussing docs site approach
- **Details**:
  - Current README is 700+ lines, too long
  - Proposal: Split into getting started + detailed docs site
  - Reference: https://drift.simonbinder.eu/ (using mkdocs-material)
  - Current state: https://docs.page/flutter-it/docs
  - See also: https://github.com/orgs/flutter-it/discussions/1

---

## 🟠 Complex But Potentially High Benefit

### #342: Add scope type independent of stack
- **URL**: https://github.com/fluttercommunity/get_it/issues/342
- **Effort**: High (1 week)
- **Benefit**: High - Enables tab-based navigation scopes
- **Implementation**: Requires architectural redesign of scope system
- **Priority**: ⭐⭐⭐
- **Comments**: 1 comment suggesting groups
- **Labels**: enhancement
- **Details**:
  - Current scopes are hierarchical stack
  - Many users want scopes for disposal, not shadowing
  - Use case: Tab navigation with parallel scopes (not stack-based)
  - Current workaround: `dropScope()` allows accessing scope by name
  - Suggestion: Keep hierarchical scopes, add non-hierarchical groups where each scope layer can contain multiple groups

### #340: Async factories with `dependsOn`
- **URL**: https://github.com/fluttercommunity/get_it/issues/340
- **Effort**: High (1 week+)
- **Benefit**: Medium - Controversial, might not fit GetIt's design philosophy
- **Priority**: ⭐⭐
- **Comments**: 20 comments with long discussion
- **Details**:
  - User wants factory to depend on async singleton
  - Maintainer response: GetIt is service locator first, async init is for startup coordination
  - Philosophical disagreement about memory management
  - User argues: Lazy loading prevents memory bloat, especially for developing countries/low-memory devices
  - Maintainer argues: Memory isn't typically an issue, GC handles it, GetIt not meant for runtime dependency chains
  - Related to #339
  - Recommendation: Watch https://www.droidcon.com/2023/08/07/coding-the-happy-path-with-commands-and-exceptions/

---

## ❓ Documentation/Bug Issues

### #402: Question about `signalsReady` usage
- **URL**: https://github.com/fluttercommunity/get_it/issues/402
- **Type**: Documentation issue
- **Comments**: No comments yet
- **Solution**: Improve docs/examples for `signalsReady`
- **Details**:
  - User confused about when to use `signalsReady: true`
  - Error: "This instance... is not available in GetIt"
  - Code calls `getIt.signalReady(this)` in async init function
  - Needs clearer documentation on signalsReady workflow

### #331: Dart 3.0 type detection issue
- **URL**: https://github.com/fluttercommunity/get_it/issues/331
- **Type**: Language issue, not GetIt bug
- **Comments**: 6 comments including Dart team members
- **Solution**: Document workaround (explicit type parameters)
- **Details**:
  - After Dart 3.0, `registerSingleton` in VoidCallback doesn't infer type correctly
  - Generic defaults to `void` (return type), causing assertion failure
  - Workarounds:
    1. Explicitly provide type: `registerSingleton<MyType>(MyType())`
    2. Use `() {}` instead of `() =>`
  - Maintainer always recommends explicit types
  - Tagged @mraleph @munificent for Dart team input

### #136: Missing factory parameter silently becomes null
- **URL**: https://github.com/fluttercommunity/get_it/issues/136
- **Type**: Validation issue
- **Comments**: 6 comments
- **Solution**: Add runtime validation to throw clear error
- **Details**:
  - Calling `getIt<SettingsBloc>()` without required param works but param becomes null
  - Should throw clear error instead of silent null
  - Leads to confusing null pointer exceptions later

### #332: `registerFactoryParam` should use Record
- **URL**: https://github.com/fluttercommunity/get_it/issues/332
- **Type**: API improvement, potential breaking change
- **Effort**: Medium
- **Benefit**: Medium - Better ergonomics with Records
- **Comments**: 7 comments discussing implementation
- **Details**:
  - Current API limited to 2 params (param1, param2) with unclear names
  - Proposal: Use Dart 3 Records for named parameters
  - Challenge: Can't mix optional positional with named params, need to keep `instanceName`
  - Could be breaking change
  - Discussion concluded: Hard to find better name than "param"

### #5: GetIt best practice
- **URL**: https://github.com/fluttercommunity/get_it/issues/5
- **Type**: Documentation/discussion
- **Comments**: 11 comments
- **Solution**: Better documentation of best practices
- **Details**: User asking whether to create new GetIt instance or import shared one

---

## 📊 Recommendations

### Top 5 to Implement (Best ROI)

1. **#192 - Code coverage badge**
   - Effort: 1 hour
   - Impact: Immediate quality signal for users

2. **#320 - `resetLazySingletonsInScope`**
   - Effort: 2-3 hours
   - Impact: Useful for testing, completes scope API

3. **#319 - `onCreated` callback**
   - Effort: 3-4 hours
   - Impact: Enables lifecycle hooks without full observer pattern

4. **#397 - Lifecycle observer**
   - Effort: 1-2 days
   - Impact: Excellent debugging tool, frequently requested pattern

5. **#339 - `dependsOn` for lazy async**
   - Effort: 1 day
   - Impact: Completes the async API, fills real gap

### Issues That Need Better Documentation

- #402 (signalsReady usage) - Add examples and workflow explanation
- #331 (Dart 3.0 workarounds) - Document explicit type parameter recommendation
- #136 (factory parameter validation) - Add validation and clear error messages
- #5 (best practices) - Create best practices guide

### Complex Issues for Future Roadmap

- **#342 (non-stack scopes)** - Real use case for tab navigation, needs careful design
- **#333 (configuration verification)** - Valuable for large projects, testing tool
- **#340 (async factories)** - Philosophically contentious, may not align with GetIt's purpose

### Breaking Change Considerations

- **#332 (Record parameters)** - Would be breaking change, needs major version bump
- Consider bundling with other breaking changes if implemented

---

## Issue Statistics

- **Total Open Issues**: 14
- **Enhancement Requests**: 4 labeled as enhancement (#342, #320, #319, plus others)
- **Documentation Issues**: ~4 (#402, #331, #5, parts of #412)
- **API Gaps**: 3 (#339, #340, #333)
- **In Progress**: 1 (#412 - docs site)

## Next Steps

1. Start with quick wins (#192, #320, #319) to build momentum
2. Implement #397 (observer) and #339 (lazy async dependsOn) in parallel
3. Improve documentation for #402, #331, #136, #5
4. Design phase for #342 (non-stack scopes) and #333 (config verification)
5. Discuss #340 and #332 with community before committing

---

**Last Updated**: 2025-10-30
**Analyzed By**: Claude Code
