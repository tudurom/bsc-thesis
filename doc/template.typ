#import "@preview/outrageous:0.1.0"
#import "./cover.typ": thesisCover

#let appendix(body) = {
  let headerNumbering = "A.1"
  let figNumberFn(..numArgs) = {
    numbering("A", (counter(heading).get().first()))
    "."
    numbering("1.1", ..numArgs)
  }
  set heading(numbering: headerNumbering, supplement: [Appendix])
  set figure(numbering: figNumberFn)
  counter(figure).update(0)
  counter(figure.where(kind: raw)).update(0)
  counter(figure.where(kind: table)).update(0)
  counter(heading).update(0)
  body
}

#let algorithm(..args) = figure(
  kind: "algorithm",
  supplement: [Algorithm],
  ..args
)

#let tudorThesis(
  body,
  title: "",
  kind: "",
  abstract: "",
  submitted: false,
  toc: true,
) = {
  set text(font: "XCharter")
  set document(title: title)
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
  set heading(numbering: "1.1")
  show par: set block(spacing: 0.65em, width: 15cm, height: 22cm)
  show heading: set block(above: 1.4em, below: 1em)
  show heading.where(level: 1): set text(size: 11.5pt)
  show heading.where(level: 2): set text(size: 11pt)
  show heading: it => {
    let number = if it.numbering != none {
      counter(heading).display(it.numbering)
      h(0.75em, weak: true)
    }
    block({
      number
      it.body
    })
  }
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

  if toc {
    {
      show outline.entry: outrageous.show-entry.with(
        ..outrageous.presets.outrageous-figures,
        font-weight: ("bold", auto),
        fill: (none, repeat[~.],),
        vspace: (1.5em, none),
        body-transform: (lvl, body) => {
          if body.has("text") {
            body
          } else {
            let (number, _, ..text) = body.children
            number
            h(0.75em)
            text.join()
          }
        }
      )
      outline(indent: auto)
    }
    // v(1em)
    // line(length: 100%, stroke: 0.5pt + rgb("#808080"))
    // pagebreak(weak: true)
    {
      // show outline.entry: set text(size: 10pt)
      show outline.entry: outrageous.show-entry.with(
        ..outrageous.presets.outrageous-figures,
        fill: (repeat[~.],),
      )
      outline(title: "Figures", target: figure.where(kind: image))
      outline(title: "Listings", target: figure.where(kind: raw))
      outline(title: "Algorithms", target: figure.where(kind: "algorithm"))
    }
    pagebreak(weak: true)
  }

  set par(justify: true, leading: 0.65em, first-line-indent: 10pt)

  set cite(style: "association-for-computing-machinery")
  set terms(hanging-indent: 0pt)


  body
}
