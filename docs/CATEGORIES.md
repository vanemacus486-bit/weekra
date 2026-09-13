# Event category compatibility

Weekra's existing event format stored one of six display colors but did not
store category identities or names. The current compatibility model maps those
exact legacy palette values to stable IDs (`category-1` through `category-6`)
and writes `categoryId` on every subsequent save. Unknown legacy colors remain
visually unchanged and are treated as `uncategorized`.

The visible names are intentionally neutral (`Category 1` through
`Category 6`). Confirm the intended six names before replacing these labels;
changing a name or display color will not change event membership because
events refer to the stable ID.

Category suggestions stay on-device. A new event is suggested a category only
when its normalized title has one unambiguous category in existing local
events. A manual choice is final for that editing session, and an uncertain
event can always be saved as uncategorized.
