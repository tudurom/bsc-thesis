#import "@preview/outrageous:0.1.0"
#set text(font: "Charter")
#show math.equation: set text(font: "Euler Math")

#set text(size: 11pt, lang: "en", region: "gb")
#let numberFn(..numArgs) = {
  numbering("1.1", ..numArgs)
  h(0.75em)
}
#set heading(numbering: numberFn)
#show par: set block(spacing: 0.65em, width: 15cm, height: 22cm)
#show heading: set block(above: 1.4em, below: 1em)
#set page(paper: "a4", margin: (x: 4cm, top: 2.5cm, bottom: 2.5cm + 0.25in))

#include "cover.typ"

#set page(numbering: "1")
#pad(x: 1em)[
  #set par(justify: true)
  #align(center, heading(outlined: false, level: 3, numbering: none)[Abstract])

  The software supply chain as we know it today is based
  on implicit trust present at multiple levels:
  trusting that (dependent) code is not malicious,
  and trusting that the code matches the trusted binaries.
  The “Trusting Trust” attack, popularised by Ken Thomspon, showed that we cannot fully trust code that
  is not written and compiled by ourselves, because of the risk of interference coming
  from self-replicating compiler attacks.
  In this work, I show that a self-replicating compiler attack is viable
  even when using a fully deterministic and reproducible compiler,
  for which we can independently verify that the compiler binary matches its source code,
  using the Go compiler as an example.
  I also show that this attack is highly impractical, despite its possibility,
  and successfully detect a hidden self-reproducing compiler attack.
]
#pagebreak()

#show outline.entry: outrageous.show-entry.with(
  ..outrageous.presets.typst,
  font-weight: ("bold", auto),
  fill: (none, repeat[~~.],),
  vspace: (1.5em, none)
)
#outline(indent: auto)
#pagebreak(weak: true)

#set par(justify: true, leading: 0.65em, first-line-indent: 10pt)

= Introduction

#lorem(50) #cite(<ddc_paper>)

#lorem(30) #cite(<trusting_trust>)

#lorem(100)

#lorem(300)

= Method

#lorem(300)

#lorem(300)

= Results
= Discussion
= Future Work
= Conclusion
= Related Work
#pagebreak(weak: true)
#heading(outlined: false, numbering: none)[References]

#bibliography(title: none, "works.bib")
#pagebreak(weak: true)

#heading(outlined: false, numbering: none)[Appendix]

```c
#include <stdio.h>

int main() {
  printf("Hello, world!\n");

  return 0;
}
```
