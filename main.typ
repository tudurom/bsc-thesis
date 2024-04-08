#import "@preview/outrageous:0.1.0"
#set text(font: "Charter")
#show math.equation: set text(font: "Euler Math")

#set text(size: 11pt, lang: "en", region: "gb")
#let numberFn(..numArgs) = {
  // let nums = numArgs.pos()
  // if nums.len() == 1 {
  //   str(nums.first())
  // } else {
  //   str(nums.map(str).join(".", last: "."))
  // }
  numbering("1.1", ..numArgs)
  h(0.75em)
}
#set heading(numbering: numberFn)
#show par: set block(spacing: 0.65em, width: 15cm, height: 22cm)

#include "cover.typ"

#show outline.entry: outrageous.show-entry.with(
  ..outrageous.presets.typst,
  font-weight: ("bold", auto),
  fill: (none, repeat[~~.],),
  vspace: (1.5em, none)
)
#outline(indent: auto)

#set par(justify: true, leading: 0.65em, first-line-indent: 10pt)

= Abstract
== Xd
#lorem(300)

= Introduction
= Background
= Problem
= Solution
= Concluding Remarks and Future Work
= Related Work
= References
