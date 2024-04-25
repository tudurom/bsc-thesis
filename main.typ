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

#let tt = [_trusting trust_]

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
  In this work, I show that a self-replicating compiler attack is possible
  even when using a fully deterministic and reproducible compiler,
  for which we can independently verify that the compiler binary matches its source code,
  using the Go compiler as an example.
  I also show that this attack is highly impractical—despite its possibility—and successfully detect a hidden self-reproducing compiler attack.
]
#pagebreak()

#show outline.entry: outrageous.show-entry.with(
  ..outrageous.presets.typst,
  font-weight: ("bold", auto),
  fill: (none, repeat[~.],),
  vspace: (1.5em, none)
)
#outline(indent: auto)
#pagebreak(weak: true)

#set par(justify: true, leading: 0.65em, first-line-indent: 10pt)

#let todo(body) = box(inset: 0.5em, stroke: red)[
  #set text(fill: red)
  #smallcaps([*To Do* ])
  #body
]
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
The translation step is performed by a computer program called a _compiler_—more often than not the result of such a translation itself—in a process named _compilation_.

Ken Thompson, of #unix fame, raised awareness of a self-replicating compiler attack in the lecture he gave
upon receiving the Turing Award @trusting_trust. In his lecture, he highlights the possibility for an attacker to breach the security of a computer system
by modifying the compiler to insert malicious code when compiling a targeted security-sensitive source code file. The compiler is further altered to
insert the code that modifies the targeted program in newer versions of the compiler
itself. 
This way, even when compiling the legitimate, unaltered version of the compiler,
the malicious code will be proliferated in the resulting executable;
because of the non-triviality of comparing source code to the executable,
the attack would go unnoticed.
This attack is commonly referred to as the "trusting trust"
attack, based on the title of his lecture:
"Reflections on Trusting Trust."

Free and open-source software constitutes an important part of the
current software supply chain,
owing to the ease of reusing code in other software projects
@surviving_software_deps @reviewofosssupplychains.
As open-source code can depend upon multiple other open-source projects,
in turn with their own dependencies,
complex dependency chains are formed upon weak trust relations,
given that free and open-source software offers
no warranties, and no contracts and arrangements are needed
to integrate them into other works #citationNeeded.
Yet, one of the great advantages of open-source software is that,
in theory, anybody can verify the quality and security of the source code,
which is, public by definition. In practice, most people still
consume this software by downloading binary executables directly #citationNeeded.
These binaries cannot be verified to be the direct product of the source code that is advertised to be used in their compilation, and as a result,
the distributor of the binaries is fully trusted to not interfere with the executables.
As a solution to this problem, a group of free software projects
formed the Reproducible Builds @ReproducibleBuildsOrg initiative, that aims to adapt software projects and build systems to
generate identical build outputs, given the same compilation conditions and instructions.
This way, compiled programs are verifiable: anybody can take
the source code of a reproducible program, compile it on their system,
outside the authors' or project's influence,
and verify that the binary outputs offered for download
match their independently-built products, and are thus untampered.

With a compiler that generates reproducible binaries, even when compiling itself, one may wonder, are we safe against the self-replicating attacks mentioned above? Can we take the trusted source code of a compiler,
compile itself, check that it is identical to the official binary,
and be at peace that no self-replicating compiler attack was done on us?
What changed since Thompson delivered his speech in 1984, that protects us from this threat?
I pose the following research questions:

#box(inset: 1em)[
  #set enum(numbering: n => strong(smallcaps("RQ"+str(n))+":"))
  + How to perform a self-reproducing compiler attack, despite a reproducible toolchain?
  + How to protect from such an attack, in the context of reproducible builds?
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
of the Thompson attack and of reproducible builds in more detail.
@method describes the assumptions that narrow down the actions we can take
to defend against this attack, in order of practicality,
and present a practical setup in which the Thompson attack can be
done against the Go toolchain.
@results shows the mode of operation of the attack proof-of-concept
that I developed, and the result of the defences proposed in @method.

== The "Trusting Trust" Attack

There are multiple layers between the source code of a program
we want to execute, as written by the authors, and the actual
execution on the processor. The translation of
source code to another form that can be consumed
by a lower layer is done by compilers @dragonbook.
@v8_pipeline highlights the stages in the code compilation and interpretation
pipeline of the V8 JavaScript engine @v8website, used in
the Chrome™ browser and Node.js runtime.
Depending on the source and target languages, the prefered name for such a program
might be different, as is the case for assemblers—transforming assembly language
to machine code—or JavaScript module bundlers, such as Webpack, which
optimise JavaScript source code for distribution over the Web;
in the scope of this work, I will always use the general term "compiler".

#figure(
  image("v8_pipeline.png", width: 80%),
  caption: [V8 JavaScript Engine Pipeline @v8bytecode],
) <v8_pipeline>

#let ver(x) = $sans(#x)$

In his speech @trusting_trust, Thompson
presents the idea of introducing malicious behaviour
in a program by modifying a compiler to insert special code
when it detects that it is compiling the target.
He then highlights the ability of self-hosting
#footnote[Compilers that can compile themselves.]
compilers to learn:
after a new feature, or language construct, is implemented
in the source code of a compiler, it can be leveraged
in a newer version of the compiler code without
requiring the implementation of that construct to be present
anymore, as the compiler binary now implements the feature.
One example of this behaviour would be support for
multi-line string literals—a string literal that contains a
string spanning over multiple lines, shown in @go_strings.
Version #ver[1.0] of a fictional compiler may only support
strings written over a single line of code. I can
then add support for multi-line strings in version #ver[2.0],
without using this feature in the implementation. Later,
in a further version #ver[3.0], I can now make use of multi-line
strings in the compiler code itself, because the executable
of version #ver[2.0] will be able to handle them.

#figure(
  caption: [
    The two kinds of string literals in Go: interpreted ("normal") and raw ("multi-line")
    @gospec
  ]
)[
  ```go
  fmt.Println("Printing multiple lines\nwith a normal\nstring literal\n")
  fmt.Println(`Printing multiple lines
  with a multi-line
  string literal
  `)
  ```
] <go_strings>

This property of self-hosting compilers gives us the ability to
also learn malicious code: we introduce another bit of code in the compiler
that detects whether it is compiling itself, and inserts
the behaviour of inserting the code described at the beginning of the previous
paragraph in the resulting compiler binary. With this in place,
the attack is concealed in the binary. Should the compiler
be compiled from clean source-code using an attacked binary,
the resulting binary will still contain the attack, even though
no trace of it is present in the source code.

The aforementioned attack was previously mentioned in
an evaluation of the security of Multics @airforce—the predecessor of #unix—performed by the United States Air Force in 1974, 10 years prior to Thompson's lecture,
in which the authors describe the possibility of developing a self-perpetuating backdoor
#footnote[The authors use the term “trap door”.]
implanted in the PL/I compiler used to compile the Multics kernel.
#footnote[The authors use the term "supervisor".]
In a follow-up article written by the same authors #cite(<airforce_followup>, supplement: [p.~130]),
Karger and Schell relate that an instance of this kind of backdoor that they created, described in the original report, was later found in a computer inside the headquarters of the US Department of Defence, despite the fact that the attack was implanted at another institution, outside the US Air Force,
and thus demonstrating the significance of this class of attacks.

#todo[Describe XCodeGhost and other similar attacks as contemporary instances.]

== Reproducible Builds and Bootstrapping

#todo[
  Introduce reproducible builds ("independently-verifiable path from source to binary code").

  Introduce Diverse Double-Compiling, and why it requires (or, can work) with reproducible compiler builds.

  Write about how trust is still needed even when using reproducible builds,
  because of the cyclic dependency graph in most software which requires using binary blobs (that we trust)
  ⇒ relevant to this thesis.

  Importance of bootstrappability (having a dependency tree instead of a graph, basically)
  is important to avoid "trusting trust" attacks:
  no binary blobs, or blobs outside the scope of a project, thus trusted;
  Go compiler is bootstrappable: https://go.dev/blog/rebuild

  $ "C" &-> "Go 1.4" \ &-> "A couple other Go versions" \ &-> "Go 1.21 (first reproducible version)" \ &-> "Go 1.22 (latest)" $

]

= Method <method>

#todo[
  First step: make hacked Go compiler.
  I make a self-reproducing attack against the Go compiler and the SHA256 function.
  If time allows, I extend it to `fmt.Println` and `os.ReadFile`.
  The hack will check if the SHA256 output equals the hash of the hacked compiler,
  and output the hash of the real compiler instead. We cannot embed this hash in the hack, what do we do?
  We hash `argv[0]` first of course. Real impact: recommended way to test the reproducibility of the Go
  compiler is to compile from source a Go program. Attacking the SHA256 function should make
  this program report to the user that the compiler is fine.

  Protection through scenarios:

  *Typical scenario*~~I download a software build, I want to compile it myself
  to verify it. I compile the software, and check the hashes; _I trust the hash_

  *Hash result is not trusted*~~I copy the artefact to another system (or more) and run the hash there.
  Why hash when I can just compare the files byte-by-byte? Because a hash is a value I can compare.
  Comparison is equal/not-equal, or equal/diff. Much easier to spoof, by making an attack that makes the diff empty.

  *Unable to copy to another system (secret code)*~~Code hash algorithm by hand; if attack, the algorithm cannot be detected.

  *Communication of hash to the user is not trusted*~~(hack in the `Println`, or daemon that scans files
  for hash of attacked compiler binary—reproducible compiler, thus reproducible hacked compiler too) code hash algorithm in another language.

  *File handling not trusted*~~(file API reads non-malicious compiler when it detects that the target is the malicious one) code hash algorithm in another language.

  *I don't trust another language*~~Diverse Double-Compiling. Works both when communicating the hash is not trusted, and when file handling is not trusted.
  It is valid to not trust another language, yet trust another compiler, which is what DDC needs.
  DDC needs not that we trust another compiler not to be hacked, but to not be hacked in the same way as the other.
  So we can both not trust another language, yet apply DDC. Case in point: bootstrapping the Go compiler
  needs a C compiler. C is bad and unsafe, we don't trust it (because we are the AIVD or something).

  "Communication of hash to the user" concerns the output of the hash.
  "File handling" refers to the input of the file comparison algorithm, hash or simple byte-by-byte comparison.

  If my reasoning turns out to be nonsense, at least I can show the attack and the Diverse Double-Compiling
  and show that the attack is really impractical, right?
]

= Results <results>

#lorem(30)

#lorem(60)

#lorem(90)

= Related Work <related_work>

Placed here close to the conclusion as clickbait.

= Conclusion

#lorem(30)

#lorem(69)

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
