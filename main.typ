#import "@preview/outrageous:0.1.0"
// #set text(font: "Charter")
#set text(font: "Charis SIL")
#show math.equation: set text(font: "Euler Math")
#show raw: set text(font: "Go Mono")

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
  #align(center, heading(outlined: false, level: 3, numbering: none, bookmarked: true)[#smallcaps[Abstract]])

  The software supply chain as we know it today is based
  on implicit trust present at multiple levels:
  trusting that (dependent) code is not malicious,
  and trusting that the code matches the trusted binaries.
  The “Trusting Trust” attack, popularised by Ken Thompson, showed that we cannot fully trust code that
  is not written and compiled by ourselves, because of the risk of interference coming
  from self-replicating compiler attacks.
  In this work, I take the Go compiler as an example and show that a self-replicating compiler attack is possible
  even when using a fully deterministic and reproducible compiler,
  for which we can independently verify that the compiler binary matches its source code.
  I also show that the attack is trivial to detect using a second compiler,
  and that the attack can still be easy to detect when the attacked
  compiler is the only one available. 
  // I also show that this attack is highly impractical—despite its possibility—and successfully detect a hidden self-reproducing compiler attack.
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

#show ref: it => {
  let el = it.element
  if el != none and el.func() == heading {
    link(el.location())[Section #numbering("1.1", ..counter(heading).at(el.location()))]
  } else {
    it
  }
}

#let todo(body) = [
  #set text(fill: maroon)
  #smallcaps([*To Do* ])
  #body
]
#let unix = smallcaps[Unix]
#let citationNeeded = link("https://www.youtube.com/watch?v=dQw4w9WgXcQ", text(fill: red, smallcaps[[citation needed]]))
#let tt = [_trusting trust_]

= Introduction

The source code of a program undergoes multiple transformations
before it becomes executable code, which can be later run by the processor.
Each intermediate form is stripped of information describing its semantics;
our current way of using computer systems depends on trusting that
the semantics of the source code match those of the generated machine code.

// Computer programs require a translation step from _source code_ to _machine code_
// before they can be executed by the computer. These two forms of code are not isomorphic:
// _source code_ is written in a _programming language_, which is a set of notations that express
// the logic and reasoning of the programmer when developing the algorithms which the computer program is based upon.
// Contrast this with _machine code_, which comprises instructions specifically targeted to the platform
// running the program, often unique to the combination of processor architecture and operating system.
// This second form of a computer program is stripped of information describing its semantics;
// our current way of using computer systems depends on trusting that the semantics of the source code match those of the generated machine code.
// The translation step is performed by a computer program called a _compiler_—more often than not the result of such a translation itself—in a process named _compilation_.

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
attack, based on the title of Thompson's lecture:
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
which is public by definition. In practice, most people still
consume this software by downloading binary executables directly #citationNeeded.
These binaries cannot be verified to be the direct product of the source code that is advertised to be used in their compilation, and as a result,
the distributor of the binaries is fully trusted to not interfere with the executables.
As a solution to this problem, a group of free software projects
formed the Reproducible Builds @ReproducibleBuildsOrg @reproduciblebuilds initiative, that aims to adapt software projects and build systems to
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

In the following subsections of this introduction,
I will further describe the background and the mode of operation
of the "trusting trust" attack and of reproducible builds in more detail,
complete with the research questions and the scope of this thesis.
@method describes a self-reproducing attack inserted in the Go compiler,
the reasons for choosing this toolchain for the scope of this paper,
and measures taken to hide the attack. I will also describe
a method of trivially discovering the attack with the help
of a second compiler that is not affected by the attack,
and how this second compiler can be easily obtained thanks to
Go's bootstrapping process. On top of that, I will propose
measures that can be taken by a concerned victim in the absence
of a second compiler, in order to stay protected.
@results shows the mode of operation of the attack proof-of-concept
that I developed, the results of the attack discovery method involving a second
compiler, and the outcomes to the defences proposed in @method.
In @related_work, I will have a look at other works written on related subjects,
followed by a conclusion of this thesis in @conclusion.

== The "Trusting Trust" Attack

There are multiple layers between the source code of a program
we want to execute, as written by the authors, and the actual
execution on the processor. The translation of
source code to another form that can be consumed
by a lower layer is done by compilers @dragonbook.
@v8_pipeline highlights the stages in the code compilation and interpretation
pipeline of the V8 JavaScript engine @v8website, used in
the Chrome™ browser and Node.js runtime;
each arrow represents a different program transformation step.
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
an evaluation of the security of Multics @airforce—the predecessor of #unix—performed by the United States Air Force in 1974, 10 years prior to Thompson's lecture.
The authors of the report describe the possibility of developing a self-perpetuating backdoor
#footnote[The authors use the term “trap door”.]
implanted in the PL/I compiler used to compile the Multics kernel.
#footnote[The authors use the term "supervisor".]
In a follow-up article written by the same authors #cite(<airforce_followup>, supplement: [p.~130]),
Karger and Schell relate that an instance of this kind of backdoor that they created, described in the original report, was later found in a computer inside the headquarters of the US Department of Defence, despite the fact that the attack was implanted at another institution, outside the US Air Force,
and thus demonstrating the significance of this class of attacks.

#todo[Describe XCodeGhost and other similar attacks as contemporary instances.]

== Reproducible Builds

Users of open-source software can be targetted by attacks
that inject malicious code during the build process @taxonomy_supply_chains @reviewofosssupplychains.
Those can become victims either by just using the compromised software packages—in Linux distributions, for example—or
by using software with compromised dependencies.
Even though the distribution media of the software packages can be trusted to not
tamper the files they offer—by
verifying hashes or digital signatures of known distributors—there is a
gap between trusting the source code and trusting the binary files that are later distributed:
source code is (relatively) easy to examine and to trust, especially in the context
of open-source software @peerreview, yet the result of its compilation
is not as easily verifiable.

Reproducible builds @reproduciblebuilds allow us to verify
that the executable version of a program matches its source code,
by ensuring that compiling the source code yields the same results
irrespective of the build environment.
If we get a mismatch in results, either the source code is different—it's not the code we expect—or
at least one of the dependencies is different—the environment is not the same.
In this work, I will abide by the reproducible build definition as
formulated by Lamb & Zacchiroli @reproduciblebuilds:

#figure(kind: "definition", supplement: [Definition])[
  #quote(block: true, attribution: <reproduciblebuilds>)[  
  #set text(style: "italic")
  *Definition 1.* The build process of a software
  product is reproducible if, after designating a
  specific version of its source code and all of its
  build dependencies, every build produces bit-for-bit
  identical artifacts, no matter the environment in which the build is performed.
  ]
] <def_reproducible_builds>

Reproducible Builds do not solve the problem of trust in software builds completely
when it comes to (self-hosting) compilers:
if I want to compile the clean source code of
a (reproducible) compiler and the outputs are matching,
that means the $(sans("source"), sans("compiler"))$ pairs are identical.
If both parties have the same attacked compiler, they cannot know
just by reproducing it.

To build a compiler, you need a previous version of itself.
We can expand this cycle by compiling compiler $sans(A)$ with an older compiler
$sans(B)$ which is in turn compiled by an even older compiler $sans(C)$, until
we reach version $frak(X)$,
which is not written in the language that it targets, and thus does not depend on
an earlier version of itself.
The longer the chain, the higher the chance that we cannot build compiler $frak(X)$
anymore, either because one of the dependencies cannot run in our build environment—for instance
when it's so old that it does not support our operating system or CPU architecture—or because one of the dependencies cannot even be found, or even $frak(X)$ itself.
Another obstacle can be time: if the chain is too long, the time required
to build all its components can be unfeasibly high.
To make this process feasible, the binary version of a more recent, known to work, version of the compiler is used.
We cannot, however, track the way these previous versions have been generated,
hence the weaker trust. Special care can be taken when engineering a software system
to make sure that it is easily buildable without cyclic dependencies, such as
by maintaining a second version of a compiler implemented in a different language,
as is the case of Go with its alternative implementation `gccgo`.
#footnote[https://gcc.gnu.org/onlinedocs/gccgo/]
These programs, for which not just the executable is reproducible, but also
the build tools involved in its production, are said to be bootstrappable @bootstrappableorg @og_bootstrap.
Bootstrappability is hard, because it requires developers to put in
additional work to maintain it, and is outside the scope of this thesis.

== Research Questions and The Scope of This Thesis

In this work, I pose the following research questions:

#box(inset: 1em)[
  #set enum(numbering: n => strong(smallcaps("RQ"+str(n))+":"))
  + How to perform a self-reproducing compiler attack against a reproducible toolchain?
  + How to protect from such an attack, harnessing reproducible builds?
]

To keep the scope of this work simple, yet relevant, I will consider
these research questions under the assumption that the target programming language
is the main language used in the development of the platform  on which it runs.
Such platforms, or operating systems, include FreeBSD, OpenBSD, and Illumos, which are written
primarily in C, and Gokrazy, a Linux-based operating system
made for running only software written in Go #citationNeeded.
I will also assume that there is a program $frak(R)$ written in the target language, that verifies the
reproducibility of a compiler. This program can be as simple as a
hash validation program, or be a complex program that downloads and verifies
the source code and the dependencies for you, and then verifies the output with
a known artifact.

= Method <method>

== The Attack

#todo[Describe `gorebuild` and why it's feasible to be attacked (verification tool written in the same language as the compiler).]

== Diverse Double-Compiling

#todo[Describe set up of DDC experiment]

== Defending with only one compiler available

#todo[
  Describe lack of confidence in hashes, and the three points in which they can go wrong:
  - Input of hash (file operations are bugged)
  - Calculation of hash (hash function detects hash of bugged compiler, replaces it with the legitimate one)
  - Output of hash (print operations are bugged)

  Those three places might be bugged, but an attacker cannot make a general bug.
  Therefore, a party can make a private implementation of a verifier program
  (i.e. alternative to `gorebuild`) that can, for example,
  make simple transformations to the input and output, and use a hand-made hash implementation.
  This verifier program must be kept private, and maybe even updated from time to time,
  to prevent an attacker from (also) targeting it.

  Possible defences:
  - Copy input file, then truncate them so they become the original file together.
  - Hand-written SHA-256
  - Print hash, but with a random hex letter char before each character
    to make the hash look like SHA-512.
]

= Results <results>

== Attack Implementation

#todo[
  Describe attack inner workings, challenges, mode of operation.
  Demonstrate attack.
]

#lorem(30)

== Application of Diverse Double-Compiling

#todo[
  Show application of DDC and the output hashes, showing a detected attack.
]

#lorem(60)

== Implementation of Defences with Only One Compiler

#todo[
  Demonstrate alternative verifier tool.
]

#lorem(90)

= Related Work <related_work>

Placed here close to the conclusion as clickbait.
#todo[Related work relevant to Reproducible Builds.
See: https://reproducible-builds.org/docs/publications/.
Also https://dwheeler.com/trusting-trust/]

== Bootstrapping <bootstrapping>

#todo[Bootstrapping is the closest thing to a solution, and there
are some things written about it. Most interesting
and popular are probably the Guix blog articles about their full-source bootstrap:

- https://guix.gnu.org/en/blog/2023/the-full-source-bootstrap-building-from-source-all-the-way-down/
- http://diyhpl.us/wiki/transcripts/breaking-bitcoin/2019/bitcoin-build-system/

Builds and packages are pure functions in Guix, which allows for all this cool tech.
Also mention Nix and the works of Eelco Dolstra, author of Nix.
Nix helps enforce some kind of reproducibility, but not the bit-by-bit kind.
]

= Conclusion <conclusion>

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
