#import "@preview/outrageous:0.1.0"
// #set text(font: "Charter")
#set text(font: "Charis SIL")
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

#let citationNeeded = link("https://www.youtube.com/watch?v=dQw4w9WgXcQ", text(fill: red, smallcaps[[citation needed]]))

#set page(numbering: "1")
#pad(x: 1em)[
  #set par(justify: true)
  #align(center, heading(outlined: false, level: 3, numbering: none, bookmarked: true)[#smallcaps[Abstract]])

  The software supply chain as we know it today is based
  on implicit trust present at multiple levels:
  trusting that (dependent) code is not malicious,
  and trusting that the code matches the trusted binaries.
  The “Trusting Trust” attack, popularised by Ken Thompson, showed that we cannot fully trust code that
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

#let todo(body) = box(inset: 0.2em, stroke: red, text(fill: red, smallcaps([To Do ])+body))
#let unix = smallcaps[Unix]

= Introduction

Computer programs require a translation step from _source code_ to _machine code_
before they can be executed by the computer. These two forms of code are not isomorphic:
_source code_ is written in a _programming language_, which is a set of notations that express
the logic and reasoning of the programmer when developing the algorithms which the computer program is based upon.
Contrast this with _machine code_, which comprises instructions specifically targeted to the platform
running the program, often unique to the combination of processor architecture and operating system.
This second form of a computer program is stripped of information describing its semantics;
our current way of using computer systems depends on trusting that the semantics of the source code match those of the generated machine code.
The translation step is performed by a computer program called a _compiler_—which more often than not is itself the result of such a translation—in a process named _compilation_.

Ken Thompson, of #unix fame, raised awareness of a self-replicating compiler attack in the lecture he gave
upon receiving the Turing Award #cite(<trusting_trust>). In his lecture, he highlights the possibility for an attacker to breach the security of a computer system
by modifying the compiler to insert malicious code when compiling a targeted security-sensitive source code file. The compiler is further altered to
insert the code that modifies the targeted program in newer versions of the compiler
itself, should this malicious compiler be used to compile versions of itself. 
This way, even when compiling the legitimate, unaltered version of the compiler,
the malicious code will be proliferated in the resulting executable;
because of the non-triviality of comparing source code to the executable,
the attack would go unnoticed.

This kind of attack was previously mentioned in
an evaluation of the security of Multics #cite(<airforce>)—the predecessor of #unix—performed by the United States Air Force in 1974, 10 years prior to Thompson's lecture
#footnote[This report is likely the “Unknown Air Force Document” referenced by Thompson.], in which the authors describe the possibility of developing a “trap door”. In a follow-up article written by the same authors #cite(<airforce_followup>, supplement: [p.~130]),
Karger and Schell relate that an instance of this kind of backdoor that they created, described in the original report, was later found in a computer inside the headquarters of the US Department of Defence, despite the fact that the attack was implanted at another institution, outside the US Air Force. #todo[That computer was exactly the computer on which Multics was developed or something like that. Read the paper carefully.] 

Free and open-source software constitutes an important part of the
current software supply chain, as shown by #citationNeeded.
One of the great advantages of open-source software is that,
in theory, anybody can verify the quality and security of the source code,
which is, by definition, public. In practice, most people still
consume this software by downloading binary executables directly #citationNeeded.
These binaries cannot be verified to be the direct product of the source code that is advertised to be used in their compilation, and as a result,
the distributor of the binaries is fully trusted to not interfere with the executables.
As a solution to this problem, a group of free software projects
formed the Reproducible Builds #cite(<ReproducibleBuildsOrg>) initiative, that aims to adapt software projects and build systems to
generate identical
#footnote[Within the scope of the Reproducible Builds project, two artifacts are identical if the file contents are identical ("bit-by-bit identical").]
build outputs, given the same compilation conditions and instructions.
This way, compiled programs are verifiable: anybody can take
the source code of a reproducible program, compile it on their system,
outside of the authors' or project's influence,
and verify that the binary outputs offered for download
match their independently-built products, and are thus untampered.

With a compiler that generates reproducible binaries, even when compiling itself, one may wonder, are we safe against the self-replicating attacks mentioned above? Can we take the trusted source code of a compiler,
compile itself, check that it is identical to the official binary,
and be at peace that no self-replicating compiler attack was done on us?
I pose the following research questions:

#box(inset: 1em)[
  #set enum(numbering: n => strong(smallcaps("RQ"+str(n))+":"))
  + How to perform a Thompson attack, despite a reproducible toolchain?
  + How to protect from a Thompson attack, in the context of reproducible builds?
]

#show ref: it => {
  let el = it.element
  if el != none and el.func() == heading and el.level == 1 {
    link(el.location())[Section #numbering("1", ..counter(heading).at(el.location()))]
  } else {
    it
  }
}

In the following subsections of this introduction,
I will further describe the background and the mode of operation
of the Thompson attack and of reproducible binaries in more detail.
@method describes the assumptions that narrow down the actions we can take
to defend against this attack, in order of practicality,
and present a practical setup in which the Thompson attack can be
done against the Go reproducible build system.
@results shows the mode of operation of the attack proof-of-concept
that I developed, and the result of the defences proposed in @method.

= Method <method>

#lorem(300)

#lorem(300)

= Results <results>
= Related Work <related_work>
= Conclusion
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
