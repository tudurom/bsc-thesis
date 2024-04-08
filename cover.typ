#align(center)[
  #set par(justify: false)
  #image("vu-griffioen.svg", height: 28mm)
  #v(1.5cm)
  #text(1.5em)[#strike[Bachelor Thesis] Research Proposal]
  #v(1.5cm)
  #line(length: 100%)
  #v(0.4cm)
  #text(2em)[*Protecting Against the Thompson Attack \ in The Context of Reproducible Builds*]
  #v(0.4cm)
  #line(length: 100%)
  #v(1.5cm)
  #text(1.5em, grid(
    columns: (2.5cm, 5cm, 3cm),
    rows: (auto,),
    align: (left, center, right),
    gutter: 5pt,
    grid.cell[*Author*:],
    grid.cell[Tudor-Ioan Roman],
    grid.cell[(2728722)],
  ))
  #v(1.5cm)
  #grid(
    columns: (auto,) * 3,
    rows: (auto,) * 3,
    align: (left, center, center),
    gutter: 1em,
    grid.cell[_1st supervisor_:],
    grid.cell[Atze van der Ploeg],
    grid.cell[],

    grid.cell[_daily supervisor:_],
    grid.cell[Atze van der Ploeg],
    grid.cell[],

    grid.cell[_2nd reader:_],
    grid.cell[TBD],
    grid.cell[],
  )
  #v(2cm)
  #strike[_A thesis submitted in fulfillment of the requirements for\
  the VU Bachelor of Science degree in Computer Science_]
  #v(1cm)
  #datetime.today().display("[month repr:long] [day padding:none], [year]")
]
#pagebreak()
