#let thesisCover(
  title: "",
  kind: "",
  submitted: false
) = context align(center, {
  set par(justify: false)
  set page(margin: auto)
  image("vu-griffioen.svg", height: 28mm)
  v(1.5cm)
  text(1.5em)[#kind]
  v(1.5cm)
  line(length: 100%)
  v(0.4cm)
  text(1.75em, strong(title))
  v(0.4cm)
  line(length: 100%)
  v(1.5cm)
  let studentId = $[2728722]$
  let renderedStudentId = text(size: super.size, studentId)
  text(1.5em, grid(
    columns: (measure(renderedStudentId).width + 10pt, 2.5cm, 8cm, 2.5cm),
    rows: (auto,),
    align: (left, left, center, right),
    gutter: 5pt,
    grid.cell[],
    grid.cell[*Author*:],
    grid.cell[Tudor-Ioan Roman#super(studentId)],
    grid.cell[],
  ))
  // #text(1.5em, align(center)[Tudor-Ioan Roman])
  grid(
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
  if submitted {
    v(2cm)
    [_A thesis submitted in fulfilment of the requirements for\
    the VU Bachelor of Science degree in Computer Science._]
    v(1cm)
  }
  align(bottom, datetime.today().display("[month repr:long] [day padding:none], [year]"))
  pagebreak(weak: true)
})
