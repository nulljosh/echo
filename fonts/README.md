# Notate Sans

A proportionally spaced sans serif, derived from Inter 4.1 by Rasmus Andersson and The Inter Project Authors (https://github.com/rsms/inter), under the SIL Open Font License 1.1 (`OFL.txt`). Renamed, as the license requires.

Made for reading transcripts. Four forms are frozen on so they are the default:

- Tailed `l` (cv05), serifed capital `I` (cv08): `Il1` never blur together in a transcript.
- Round quotes and commas (ss03).
- Single-storey `a` (cv11).

Subset to Latin, punctuation, arrows and the math signs. Kerning, ligatures and tabular figures kept. Four weights: Regular, Medium, SemiBold, Bold. `build.py` rebuilds them from the Inter static TTFs.

`docs/fonts/*.woff2` is the web copy. Both apps bundle the TTFs and use them everywhere through `Font.notate`.
