# Task: Add Features to a Static Site Generator

You are working with an existing static site generator written in Go.
Familiarize yourself with the codebase and complete the following three
tasks in order.

## Task A: Add YAML Front Matter Validation (Small)

Add validation for YAML front matter in markdown files. Currently the
generator silently ignores malformed front matter. Instead:

1. When a markdown file has invalid YAML front matter, report a clear
   error message including the filename and line number
2. When a required field (title) is missing from front matter, report
   a warning but continue processing
3. Add tests for both cases

## Task B: Add RSS Feed Generation (Medium)

Add automatic RSS/Atom feed generation:

1. Generate a valid Atom feed at `/feed.xml` containing the 20 most
   recent posts sorted by date
2. Each entry should include title, date, URL, and a summary (first
   150 characters of content)
3. The feed URL should be discoverable via a `<link>` tag in the
   HTML output
4. Add tests verifying feed validity and content

## Task C: Add Tag Support (Large)

Add a tagging system for posts:

1. Posts can specify tags in their front matter: `tags: [go, web, tutorial]`
2. Generate a `/tags/` index page listing all tags with post counts
3. Generate per-tag pages at `/tags/<tag>/` listing all posts with that tag
4. Tags should be normalized (lowercase, trimmed)
5. Add tests for tag parsing, page generation, and edge cases

## Success Criterion

All existing tests continue to pass, and all new tests pass when running
`go test ./...`
