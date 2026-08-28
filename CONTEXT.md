# Zellij Pane Listing

Language used by scripts that inspect and present the panes in a Zellij session.

## Language

**Pane**:
A Zellij terminal or plugin surface represented as one row in a pane listing.
_Avoid_: Tab

**Bar pane**:
A pane whose title is exactly `tab-bar` or `status-bar`.

**Floating pane**:
A pane that Zellij identifies as floating, regardless of whether floating panes are currently visible.
_Avoid_: Floating tab

**Floating status**:
The known floating, known tiled, or unknown placement of a pane. The status is unknown when Zellij does not report whether the pane is floating.
