# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Navigation

### Tool

A self-contained developer utility surfaced in the app's sidebar. Each Tool declares its identity (`id`, `name`, `description`), visual presentation (`icon`, `iconColor`), and produces a SwiftUI view for the detail pane. Tools are the primary unit of functionality in Navi — the app is a shell that hosts and navigates between them.

### ToolRegistry

The central static registry that holds the canonical list of all available Tools. The sidebar and navigation derive their content from this single source of truth.
