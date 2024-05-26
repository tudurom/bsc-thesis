#import "@preview/outrageous:0.1.0"
#import "./cover.typ": thesisCover

#let tudorThesis(
  body,
  title: "",
  kind: "",
  abstract: "",
  submitted: false,
  toc: true,
) = {
  set text(font: "XCharter")
  show math.equation: set text(font: "Euler Math")
  show raw: set text(font: "Go Mono")
  show link: it => {
    if type(it.dest) == str {
      text(fill: blue, it)
    } else {
      it
    }
  }
  set text(size: 11pt, lang: "en", region: "gb")
  let numberFn(..numArgs) = {
    numbering("1.1", ..numArgs)
    h(0.75em)
  }
  set heading(numbering: numberFn)
  show par: set block(spacing: 0.65em, width: 15cm, height: 22cm)
  show heading: set block(above: 1.4em, below: 1em)
  set page(paper: "a4", margin: (x: 4cm, top: 2.5cm, bottom: 2.5cm + 0.25in))

  thesisCover(
    title: title,
    kind: kind,
    submitted: submitted,
  )

  set page(numbering: "1")

  pad(x: 1em, {
    set par(justify: true)
    align(
      center,
      heading(
        outlined: false,
        level: 3,
        numbering: none,
        bookmarked: true,
        smallcaps[Abstract]
      )
    )
    abstract
  })
  if toc {
    pagebreak()
  }

  show outline.entry: outrageous.show-entry.with(
    ..outrageous.presets.typst,
    font-weight: ("bold", auto),
    fill: (none, repeat[~.],),
    vspace: (1.5em, none)
  )
  if toc {
    outline(indent: auto)
    pagebreak(weak: true)
  }

  set par(justify: true, leading: 0.65em, first-line-indent: 10pt)

  show ref: it => {
    let el = it.element
    if el != none and el.func() == heading {
      link(el.location())[Section #numbering("1.1", ..counter(heading).at(el.location()))]
    } else {
      it
    }
  }

  body
}
