# Issue tracker: GitHub

Issues and PRDs for this repository live as GitHub issues in
`Ash-Dilussi/Mobile-Appointmenting`. Use the `gh` CLI for operations and pass
`--repo Ash-Dilussi/Mobile-Appointmenting` when repository auto-detection is
unavailable.

## Conventions

- Create: `gh issue create --repo Ash-Dilussi/Mobile-Appointmenting --title "..." --body "..."`
- Read: `gh issue view <number> --repo Ash-Dilussi/Mobile-Appointmenting --comments`
- List: `gh issue list --repo Ash-Dilussi/Mobile-Appointmenting --state open`
- Comment: `gh issue comment <number> --repo Ash-Dilussi/Mobile-Appointmenting --body "..."`
- Label: `gh issue edit <number> --repo Ash-Dilussi/Mobile-Appointmenting --add-label "..."`
- Close: `gh issue close <number> --repo Ash-Dilussi/Mobile-Appointmenting --comment "..."`

When a skill says to publish to the issue tracker, create a GitHub issue. When
it says to fetch a ticket, read the corresponding issue and its comments.
