#import "template.typ": *
#import "@preview/lovelace:0.3.0": *
#import "@preview/fletcher:0.5.0" as fletcher: diagram, node, edge

#set document(author: "Tudor Roman", date: none)

#let final = false
#show: tudorThesis.with(
  title: [
    Protecting Against the 'Trusting Trust' Attack in The Context of
    Reproducible Builds
  ],
  kind: [Bachelor's Thesis #if not final { text(fill: red)[*Draft*] }],
  submitted: final,
  abstract: [
    Reproducible builds can be used to defend against software supply-chain
    attacks.
    By making build processes output bit-by-bit identical artefacts,
    independent reviewers can rebuild code and verify that the outputs match
    those of others',
    establishing trust between source code and binaries.
    The 'Trusting Trust' attack, popularised by Ken Thompson, showed that
    we cannot fully trust code that is not written by ourselves, owing to the
    risk of interference coming from self-replicating compiler attacks. In this
    work, I take the Go compiler and associated reproducibility tooling as an
    example and show that a self-replicating compiler attack is possible even
    when using a fully deterministic and reproducible compiler, that can be
    verified to yield the same results in independent compilations. I also show
    that the attack is trivial to detect using a second compiler, and that the
    attack can still be easy to detect when the attacked compiler is the only
    one available.
  ]
)

#let unix = smallcaps[Unix]

= Introduction

The source code of a program undergoes multiple transformations before it
becomes executable code. Each intermediate form is stripped of information
describing its semantics; our current way of using computer systems depends
on trusting that the semantics of the source code match those of the generated
machine code.

Ken Thompson, one of the original authors of #unix,
raised awareness of a self-replicating compiler attack in a lecture
he gave upon receiving the Turing Award @trusting_trust.
In his lecture, he highlights the possibility for an attacker to breach the
security of a computer system by modifying the compiler to insert malicious code
when compiling a targeted security-sensitive source code file. The compiler is
further altered to
also insert the attack in itself when it detects that it is compiling its own
source. The logic is as follows:

#figure(kind: raw, caption: "The logic of the attack.")[
#set align(left)
#pad(x: 1em)[_
  - If the source file being compiled belongs to the target, then insert code to
    breach its security.
  - Else, if the source file is of the compiler, then insert
    code following the logic from @attack_logic.
_]
] <attack_logic>

This way, even when compiling the legitimate,
unaltered version of the compiler, the malicious code will be proliferated in
the resulting executable, which will then infect the originally targeted program
when it gets the chance. Due to the non-triviality of comparing source
code to executables, the attack would go unnoticed: the user can compile
the compiler again from clean sources and believe that the binary follows
the expected semantics. This attack is commonly referred to as the 'trusting
trust' attack, based on the title of Thompson's lecture: 'Reflections on
Trusting Trust'.

Free and open-source software constitutes an important part of the current
software supply chain, owing to the ease of reusing code in other software
projects @surviving_software_deps @reviewofosssupplychains. As open-source
code can depend upon multiple other open-source projects—in turn with
their own dependencies—complex dependency chains are formed upon weak trust
relations, given that free and open-source software offers no warranties, and
no contracts and arrangements are needed to integrate them into other works.
Yet, one of the great advantages of open-source software is that, in theory,
anybody can verify the quality and security of the source code.
In practice, most people still consume this software by
downloading binary executables directly. These binaries cannot be verified to
be the direct product of the source code that is advertised to be used in their
compilation, and as a result, the distributor of the binaries is fully trusted
to not interfere with the executables. As a solution to this problem, a group
of free software projects formed the Reproducible Builds @ReproducibleBuildsOrg
@reproduciblebuilds initiative, which aims to adapt software projects and
build systems to generate identical build outputs, given the same compilation
conditions and instructions. This way, compiled programs are verifiable: anybody
can take the source code of a reproducible program, compile it on their
system—outside the authors' or the project's influence—and verify that the binary
outputs offered for download match their independently-built products, and are
thus untampered.

With a compiler that generates reproducible binaries, even when compiling
itself, one may wonder, are we safe against the self-replicating attacks
mentioned above? Can we take the trusted source code of a compiler, compile
itself, check that it is identical to the official binary, and be at peace that
no self-replicating compiler attack was done on us? What changed since Thompson
delivered his speech in 1984, that protects us from this threat?

In the following subsections of this introduction, I further describe the
background and the mode of operation of the 'trusting trust' attack.
On top of that, I write about
what reproducible builds are in more detail and
introduce a method to discover the attack involving a second compiler,
complete with the research questions and
the scope of this thesis. @method describes a self-reproducing attack inserted
in the Go compiler and its implementation.
@results shows a method to trivially discover the attack with the help of
a second compiler, and defensive measures that can be taken when there
is only one compiler available.
In @related_work, I have a look at other works written on related
subjects, followed by a summary of this thesis in @conclusion.

== The 'Trusting Trust' Attack

#let ver(x) = raw(x)

In his speech @trusting_trust, Thompson presents the idea of introducing
malicious behaviour in a program by modifying a compiler to insert special code
when it detects that it is compiling the target of the attack. 
He then highlights the ability of self-hosting
#footnote[Compilers that can compile themselves.]
compilers to learn: after a new feature, or language construct, is implemented
in the source code of a compiler, it can be leveraged in a newer version of
the compiler code without requiring the implementation of that construct to
be present any more, as the compiler binary now implements the feature.

#grid(
  columns: (auto, auto),
  gutter: 1em,
  [
    #figure(
      caption: [Associating the escape sequence with an explicit value in
      #ver("2.0").]
    )[
      ```go
      if characterLiteral == "\\x" {
        return '\U0001F913'
      }
      ```
    ] <ver2>
  ],
  [
    
    #figure(
      caption: [The escape sequence can be used in its
        definition in #ver("3.0").]
    )[
      ```go
      if characterLiteral == "\\x" {
        return '\x'
      }
      ```
    ] <ver3>

  ]
)


One example of this behaviour would be support for a new escape sequence in
string literals. Version #ver("1.0") of a fictional compiler may not
support an escape sequence `\x` in strings, representing Unicode code point
`U+1F913`. I can then add support for
this new escape sequence in version #ver("2.0")—a possible implementation is
shown in @ver2.
Later, in a further version #ver("3.0"), I can now make use
of `\x` in the compiler code itself—as shown in @ver3—perhaps in the
implementation of this escape sequence even, because the
executable of
version #ver("2.0") will be able to interpret it correctly in the #ver("3.0")
code.

This property of self-hosting compilers allows for learning malicious code: I
can introduce another bit of code in the compiler that detects whether it is
compiling itself, as shown in @tt_flowchart. If it is indeed compiling itself, the compiler can then insert
in the resulting binary the logic from @attack_logic. With this in
place, the attack is concealed in the binary. Should the compiler be compiled
from clean source-code using an attacked binary, the resulting binary will still
contain the attack, even though no trace of it is present in the source code.


The aforementioned attack was previously mentioned in an evaluation of the
security of Multics @airforce—the predecessor of #unix—performed by the United
States Air Force in 1974, 10 years prior to Thompson's lecture. The authors of
the report describe the possibility of developing a self-perpetuating backdoor
#footnote[The authors use the term 'trap door'.]
implanted in the PL/I compiler used to compile the Multics kernel
#footnote[The authors use the term 'supervisor'.].
In a follow-up article written by the same authors
#cite(<airforce_followup>),
Karger and Schell relate that an instance of this kind of backdoor that they
created, described in the original report, was later found in a computer inside
the headquarters of the US Department of Defence, despite the fact that the
attack was implanted at another institution, outside the US Air Force, and thus
demonstrating the significance of this class of attacks.

#import fletcher.shapes: diamond, rect
#let recdiagram(orig_n, n) = {
  let textSize = 10pt
  let scaleFactor = 2.5
  let rhombusPadding = v(0.3em)
  set par(justify: false)
  set text(size:
    if orig_n - n == 0 {
      textSize
    } else {
      textSize / calc.pow(scaleFactor, orig_n - n)
    })
  diagram(
    node-stroke: 1pt / calc.pow(scaleFactor, orig_n - n),
    edge-stroke: 1pt / calc.pow(scaleFactor, orig_n - n),
    node-inset: 0.75em,
    edge-corner-radius: 2.5pt / calc.pow(scaleFactor, orig_n - n),
    node-corner-radius: 1.5pt / calc.pow(scaleFactor, orig_n - n),
    node((0, 0), align(center)[#rhombusPadding Compiling the\ target?#v(0.1em, weak: true)], shape: diamond),
    edge((0, 0), (2, 0), "-|>", [Yes], label-pos: 0.2),
    edge((0, 0), (0, 1), "-|>", [No], label-pos: 0.1),
    node((0, 1), align(center)[#rhombusPadding Compiling the\ compiler?], shape: diamond),
    edge((0, 1), (2, 1), "-|>", [Yes], label-pos: 0.2),
    edge((0, 1), (0, 2), "-|>", [No], label-pos: 0.1),
    node((2, 1), [
      Insert this code:

      #if n > 0 {
        recdiagram(orig_n, n - 1)
      } else {
        block(width: 10em, height: 3em)[
          #set text(size: 0.8em)
          Nothing to be seen here #text(font: "Go")[:D]
        ]
      }
    ], shape: rect),
    node((0, 2), [Compile the code.]),
    node((2, 0), [Add code that compromises the target.]),
    edge("r,dd,lll", "-|>"),
    edge((2, 1), "d,ll", "-|>"),
  )
}

#figure(
  caption: [The compiler learning malicious code.],
  kind: image,
  placement: top,
)[
  #recdiagram(3, 3)
  // #align(center)[|]
] <tt_flowchart>

== Reproducible Builds <section_reproducible_builds>

Reproducible builds @reproduciblebuilds allow us to verify that the executable
version of a program matches its source code, by ensuring that compiling the
source code yields the same results irrespective of the build environment. If
we get a mismatch in results, either the source code is different—it is not the
code we expect—or at least one of the dependencies is different—the environment
is not the same. In this work, I abide by a definition of reproducible builds
similar to the one formulated by Lamb & Zacchiroli @reproduciblebuilds:

#[
#show figure: set block(breakable: true)
#figure(kind: "definition", supplement: [Definition])[
  #set align(left)
  *Definition 1.*
  Given the same version of a program's source code and the same version of the
  programs it depends upon and other associated resources, the build process
  shall result in identical files—with the same bytes—in any build environment
  _with the relevant attributes established by its authors_.
]
]

Reproducible Builds do not solve the problem of trust in software builds
completely when it comes to (self-hosting) compilers: if I want to compile the
clean source code of a (reproducible) compiler and the outputs are matching,
that means the $(sans("source"), sans("compiler"))$ pairs are identical. If both
parties have the same attacked compiler, they cannot be aware of it just
because they reproduced the compiler binary successfully.

To build a bootstrapped compiler—i.e. one that can compile itself—you need a
previous version of itself. We can expand this
cycle by compiling compiler $sans(A)$ with an older compiler $sans(B)$ which
is in turn compiled by an even older compiler $sans(C)$ etc.
At one point, we reach version
$frak(X)$ of the compiler, which is not written in the language that it targets, and thus does
not depend on an earlier version of itself. The longer the chain, the higher the
chance that we cannot build compiler $frak(X)$ any more, either because one of
the dependencies cannot run in our build environment—for instance when it is so
old that it does not support our operating system or CPU architecture—or because
one of the dependencies cannot even be found, or even $frak(X)$ itself. Another
obstacle can be time: if the chain is too long, the time required to build all
its components can be unfeasibly high. To make this process feasible, the binary
version of a more recent version of the compiler is used.
We cannot, however, track the way these previous versions were generated,
hence the weaker trust. Special care can be taken when engineering a software
system to make sure that it is easily buildable without cyclic dependencies,
such as by maintaining a second version of a compiler implemented in a different
language, as is the case of Go with its alternative implementation `gccgo`
#footnote[https://gcc.gnu.org/onlinedocs/gccgo/ (Accessed on 09-05-2024.)].
These programs, for which not just the executable is reproducible, but also
the build tools involved in its production, are said to be bootstrappable
@bootstrappableorg @og_bootstrap. Bootstrappability is hard, because it requires
developers to put in additional work to maintain it, and is outside the scope of
this thesis.

== Research Questions and The Scope of This Thesis <rqs_and_scope>

In this work, I pose the following research questions:\
#box(inset: (x: 0.5em, y: 1em),)[
  #set enum(numbering: n => strong(smallcaps("RQ"+str(n))+":"))
  + How to perform a self-reproducing compiler attack against a reproducible
    toolchain?
  + How to protect from such an attack, harnessing reproducible builds?
]

To keep the scope of this work simple, yet relevant, I consider these research
questions under the assumption that
the operating system on which the compiler runs
is written mostly in the same programming language as the one the compiler
is designed to process—e.g. a C compiler running on an operating system
written in C.
Such
platforms, or operating systems, include FreeBSD @freebsd, OpenBSD @openbsd,
and Illumos,
#footnote[
  Source code repository on GitHub: https://github.com/illumos/illumos-gate.
  According to GitHub, the C source code makes up for 88.6% of
  source files. (Accessed on 09-05-2024.)
]
which are written primarily in C, and Talos Linux and Gokrazy, written primarily
in Go. Gokrazy is a Linux-based operating system for enthusiasts, that runs only
software written in Go @gokrazy.
Talos Linux
#footnote[
  Source code repository on GitHub: https://github.com/siderolabs/talos.
  The Go source code makes up for 92.0% of source files.
  (Accessed on 09-05-2024.)
]
is a production-grade Linux-based operating system that runs the minimal amount
of software needed to run Kubernetes @kubernetes, a container orchestration
engine also written in Go.

I also assume that there is a program $frak(R)$ written in the target language,
that verifies the reproducibility of a compiler. This program can be as simple
as a hash validation program, or be a complex program that downloads and
verifies the source code and the dependencies for you, and then verifies the
output with a known artefact.

The code written for this thesis can be found in the companion repository,
available at https://github.com/tudurom/bsc-thesis.

= Attack <method>

To answer the first research question, I picked the reference Go compiler named
`gc` @gogc to be the carrier of my 'trusting trust' attack. The reasons for my
choice are fivefold:

- `gc` is written completely in Go, including the back-end
  and the assembler used to generate binaries.
- `gc` is reproducible by default @gorebuild: Assuming that the compilers in
  the bootstrap chain are legitimate, only the source code of `gc` affects
  the resulting binaries—the author of the referenced work names this 'perfect
  reproducibility'. The platform on which the build runs does not affect the
  binaries: they will be bit-by-bit identical.
- `gc` has a clear bootstrapping process: for each version of `gc`, there is
  a well-defined older version of the compiler needed to compile it; the first
  version of `gc` written in Go can then be compiled with the last version
  of `gc` written in C. Even though only operating systems built primarily
  in the programming language of choice form the scope of this thesis, having
  an implementation of the compiler in a different language at the end of
  the bootstrapping chain ensures a clear origin for the subsequent compiler
  binaries in my experiments.
- All versions of `gc` can compile Go code for all the supported operating
  systems and CPU architectures without installing any additional software. This
  is very useful for testing.
- Finally, there is a companion tool to verify `gc`'s reproducibility
  named `gorebuild`, itself written in Go and endorsed by the Go project.
  Coincidentally, this will serve as
  the verification tool $frak(R)$, as defined in @rqs_and_scope.

For the experiments outlined in this work, I used version `1.22.3` of `gc`,
with source and binaries available at https://go.dev/dl/. `gorebuild` is part
of the 'Continuous build and release infrastructure' repository (also called `x/
build`), its code residing in the `cmd/gorebuild` directory. The exact version
of `gorebuild` used in this thesis is available at
https://go.googlesource.com/build/+/c639adb8fb6ac6aa2dfbe669bd171d84ddfc6ae9/cmd/gorebuild/.

== The Target

The scope of the attack is to make the compiler intentionally corrupt the
reproducibility-verifier program $frak(R)$; $frak(R)$ shall lie to the user that the
executables generated by the compiler match those advertised by an authority,
when in fact they do not.

In the context of Go and `gorebuild`, this entails modifying the Go compiler to
insert special code when detecting that the project being built is `gorebuild`
or `gc` itself.
Fortunately for me, from the 'Go Reproducible Build Report'
#footnote[https://go.dev/rebuild (Accessed 12-05-2024.)]
page on Go's website, compiling `gorebuild` from source is the endorsed way of
running this program, making it a good target for a 'trusting trust' attack.
The Go website does not provide any binary version of `gorebuild` at the time of
writing this thesis.

The build verification process undertaken by `gorebuild` is more sophisticated
than a mere file comparison—be it byte-by-byte or compare-by-hash. Instead,
`gorebuild` takes a target triplet
$(sans("architecture"), sans("operating system"), sans("version"))$,
compiles the bootstrap chain for the host running the verification, and then
compiles the specified compiler
using the last compiler in the bootstrap chain.
The source code version must be at least `1.21.0`, as that is the first
reproducible version of the Go compiler. Notably, `gorebuild`
builds the bootstrap chain only when running on $(mono("x86-64"), mono("Linux"))$.
On other systems, it downloads a binary distribution of the minimum required
`gc` version required by the target.

To better understand the mode of operation, take this example: I have the following two version specifiers
#footnote[
  For each version number mentioned with only two components—e.g. 1.17—consider
  all associated version numbers with three components.
]:
$
  S_"host" &= (mono("linux"), mono("amd64"), V),& forall V in {1.4, 1.17, 1.20}\
  S_"target" &= (mono("freebsd"), mono("arm64"), 1.22.3)&
$
My host is a laptop running Linux on an x86-64 CPU. I want to build and verify
`gc` version `1.22.3` targetting FreeBSD running on AArch64.

`gorebuild` proceeds to download the source code for `gc` `1.4`, which is
written in C. Then, it downloads the source of, and compiles, `gc` `1.17`,
written in Go, which is then used to compile `gc` `1.20`. These three compilers
form the bootstrap chain, and target our host $S_"host"$. The last compiler of
the chain, `gc` `1.20`, then compiles `gc` `1.22.3` targetting $S_"target"$. The
hashes of the resulted artefacts are printed on the screen,
and then the files are compared against the reference build from
https://go.dev/dl/.
Usually, this is either a `.tar.gz` archive, or a `.msi` or `.pkg` installer
file for Windows and #text(hyphenate: false)[macOS] respectively.

The main purpose of my attack is to have the attacked compiler
generate a forged `gorebuild` binary
that (a) compiles Go version `1.22.3` using the attacked compiler, in turn
proliferating the attack, and (b) lies to the user that the resulting Go
toolchain matches the official one, available on https://go.dev/dl. Being
compiled by the forged compiler, the result is therefore also forged. A victim
can use `gorebuild` to bootstrap `gc` on their system, without knowing that
the verification tool is targeted by the compiler on their system. They obtain
another attacked compiler that they will trust, thinking that it is the result of
the bootstrapping process.

== Quining: Indirect Self-Referencing

At the base of the self-reproducing attack lays _quining_, a verb
coined by Douglas Hofstadter in his book
_Gödel, Escher, Bach: An Eternal Golden Braid_
#footnote[A book referenced in more than one course throughout my bachelor's.]
@geb_egb. Quining is a way of
achieving self-reference in an indirect way. In the case of language sentences,
it means writing a sentence that references itself without using the word 'this'
and other similar qualifiers. This can be achieved by having a quoted sentence
describe itself, like in the following example from the aforementioned book:

#quote(block: true)["yields falsehood when quined" yields falsehood when quined. @geb_egb]

When it comes to computer programs, a program that prints its own source code
can be considered a quine. @quine_simple shows the source code of a simple
Go program that prints its own code. You can see that the logic is effectively
doubled. In its first occurrence, it consists of a template for the source code
to be printed, stored in the variable `code`. Its second occurrence is split
in halves: the first half appears before the definition of `code`,
and the second right after. Piecing together the two halves in the program's
output is done by the `fmt.Printf` function, which is very similar to `printf`
from the C standard library. Because the 'template' part of the program is
written between raw string literals—marked by backticks—which do not allow
backticks in themselves, the backtick characters are also passed as parameters
to `fmt.Printf` using Unicode code point notation (`\u0060`).

A self-reproducing compiler attack is, however, not a program that prints
itself, but rather one that injects code that reinjects itself whenever
it detects the compiler's source code as input. The implementation is very
similar to the quine above: the logic is first put 'between quotes', and then
assembled and inserted in the compiler's output. A simple application of this
idea is wrote down in @quine_replace. The program reads a file given as argument,
and if the file's contents match a 'Hello, world!' program, replaces the line
that prints the message with code that resembles @quine_replace. Care is taken
to also fix the imported libraries of the program.

#figure(placement: auto, caption: [A Go program that prints its own source code.])[
```go
package main

import (
        "fmt"
)

func main() {
        code := `package main

import (
        "fmt"
)

func main() {
        code := %c%s%c
        fmt.Printf(code, '\u0060', code, '\u0060')
}
`
        fmt.Printf(code, '\u0060', code, '\u0060')
}
```
] <quine_simple>

Having the code appear twice poses a challenge when developing and testing. It
is hard to remember to change both copies of the code when debugging. This is
amplified by the fact that this code is added to a compiler with a
significant codebase; every compilation takes time. To make it easier to develop
an attack, I wrote a Go program named `evilgen` that takes specially annotated source code as
input, and outputs Go code that is capable of self-reproduction.
Instead of creating a variable with a string literal that holds all the code,
the generator takes the demarcated chunk of the code to quine, quotes it,
taking care of any necessary escaping, and then inserts it in a string literal
together with code that 'templates' the code back in itself.
One can think of this program as a program regenerator generator.
A simplified version of the program that prints its own source code—one that
makes use of `evilgen`—is shown in @quine_evilgen.
The annotations demarcate the chunk of the code to quine, which would normally
appear twice in the source code.

#figure(
  caption: [A program that prints its own code, with annotations for `evilgen`.]
)[
```go
{{- block "quineCode" . -}}
package main

{{ .Imports "fmt" "os" }}

func main() {
	template := {{ .Code }}

	quine := {{ .Quine "template" }}
	fmt.Print(quine)
}
{{ end -}}
```
] <quine_evilgen>

The annotations are implemented using the `text/template`
#footnote[https://pkg.go.dev/text/template (Accessed 25-06-2024.)]
package from the Go standard library. Code
that needs to be replicated further is written inside the `quineCode` block.
The `{{ .Code }}` template is replaced by `evilgen` with the quoted version
of the code, which is meant to be stored in a variable. `{{ .Quine ... }}`
then generates code that assembles the quine using the code from the variable
whose name is passed as an argument. The quotation of the quine code is
done using the `go/constant` package, which is the same package used by the
compiler to read and generate constant literals. In the case of `evilgen`,
quoting happens by encasing the code in a string literal; `go/constant` then
takes care of all the escaping. An example of source code generated by `evilgen`
can be found in @quine_evilgen_generated.
The `{{ .Imports ... }}` template function
is provided as a helper to generate import statements containing this library.

#[
#set par(justify: false)
#figure(
  caption: [A program that prints its own code, as generated by the `evilgen`.]
)[
```go
package main

import (
	"fmt"
	"go/constant"
	"os"
)

func main() {
	template := "package main\n\nimport (\n\t\"fmt\"\n\t\"go/constant\"\n\t\"os\"\n)\n\nfunc main() {\n\ttemplate := %s\n\n\tquine := fmt.Sprintf(template, constant.MakeString(template).ExactString())\n\tfmt.Print(quine)\n}\n"

	quine := fmt.Sprintf(template, constant.MakeString(template).ExactString())
	fmt.Print(quine)
}
```
] <quine_evilgen_generated>
]

The source for `evilgen` can be found in the source code
repository attached to this thesis.

== Attack implementation

To develop the attack, I took `gc`'s source and added the attack logic on top.
I compiled this modified code and I obtained what I call the 'hack seed': an
attacked compiler that is semantically equivalent to the attacked binaries it
is going to generate. This binary is not quite identical to the final attack
compiler; the spacing in its source code differs slightly from that of the
source that the attack logic adds inside compilers. One run of the hack seed
compiler over the clean Go compiler source code is enough to generate the final
reproducible attacked compiler: one that, when given clean `gc` code as input,
generates an identical version of itself, containing the hack. In short:

+ An original, unattacked version of `gc` compiles `gc` `1.22.3` and yields $A$:
  a legitimate, *clean* `gc` `1.22.3` binary.
+ Attack logic is added on top of the source code. Source is then compiled with
  $A$ to create $B$: the hack seed compiler.
+ $B$ is used to compile the original `go` `1.22.3` code—the same used for $A$—to
  create the final compiler $C$, *which contains the attack*.
+ $C$ can be given the same source code to generate $C'$. Because $C$ is
  reproducible, $C$ and $C'$ are *identical*. $C'$ may be used to create $C''$
  and so forth; they will all be identical, byte-for-byte.

#[
  // #show figure: set block(breakable: true)
  #algorithm(
    placement: auto,
    caption: [Attacked `Parse` function pseudocode.]
  )[
    #set text(font: "Go")
    #pseudocode-list[
      #let g(x) = text(fill: rgb("#595959"), x)
      - #g[initialise parser]
      - #g[read and parse file at _filename_]
      - *if* _filename_ matches `cmd/gorebuild/report.go` *then*
        - change code to make `gorebuild` lie to the user that mismatching files are, in fact, matching
        - parse again, using modified code
      - *else if* _filename_ matches `cmd/gorebuild/build.go` *then*
        - change code to make `gorebuild` compile the final compiler with the (attacked) system toolchain
        - change code to substitute the artefacts' SHA256 hashes based on an
          environment variable
        - parse again, using modified code
      - *else if* filename matches `cmd/compile/internal/syntax/syntax.go` *then*
        - _magicString_ $<-$ "_seemingly random string_"
        - *if* code contains _magicString_ *then*
          - *return* AST
        - *end if*
        - insert logic from @logic_impl in code
        - parse again, using modified code
      - *end if*
      - #g[*return* AST]
    ]
  ] <logic_impl>
]

To keep the implementation simple and easy to understand, I chose to insert
the attack before the Abstract Syntax Tree generation. An attack can very well
operate at the AST level, modifying the AST to insert the desired logic, or even
at the assembly level. My attack implementation takes place in an internal
Go compiler function named `Parse`
(in `src/cmd/compile/internal/syntax/syntax.go`);
its prototype is shown in @parse_proto.
`Parse` takes the contents of a source code
file, invokes the parser and returns the AST of that file. I modified this
function to match on the filename of the files being compiled,
insert attack code if needed, and invoke the parsing routines on that code. 
If the filename does not match any targetted file—neither from `gorebuild`,
nor from the compiler—then compilation proceeds as usual.

#figure(
  caption: [The prototype of the `Parse` function, where the hack is located.]
)[
```go
func Parse(base *PosBase,
           src io.Reader,
           errh ErrorHandler,
           pragh PragmaHandler, mode Mode) (_ *File, first error) {
  // ...
}
```
] <parse_proto>

@logic_impl shows a pseudocode outline of the code I inserted into `Parse` to
modify `gorebuild` from the compiler, and to re-insert the attack into other
compilers. The lines shown in grey represent logic that is already part of the
original code. Lines shown in black are the ones that are reproduced
when the compiler compiles its own (clean) source code.
In the real `evilgen`-annotated code, the lines written in black
are placed in a ```go {{ block "quineCode" . }} ... {{ end }}```
segment.

There are some details in my implementation affecting what the user sees in
`gorebuild`'s output.

First, `gorebuild` prints the path of each toolchain it
uses when compiling a Go compiler. This happens when building the bootstrap chain,
but also when building the target compiler whose reproducibility is being tested.
If a bootstrap chain is used, then the last element is going to be used for
building the compiler whose reproducibility is being scrutinised.
If no bootstrap chain is used, then `gorebuild` downloads a
toolchain from the Go website; it will never use the system compiler, which is
what I want for this attack. Regardless which one it uses, `gorebuild`
will first print its path on the screen, and then commence the compilation.
My attack implementation takes an extra step to print the path of this toolchain,
yet use the attacked system compiler behind the scenes.

Second, hashes displayed to the user will be substituted based on the value of an environment
variable. When the attacked compiler is implanted on a victim's system, the
attacker can also hide this variable somewhere and customise it to their
liking. An arbitrary amount of substitutions can be specified in the format
$F_1:R_1,F_2:R_2,...,F_n:R_n$.
$F_i$ represents a hash to find in the build output, to be replaced by $R_i$.

Third, my implementation as attached to this thesis outputs debugging messages
to show that the attack is, indeed, working. This would not be desirable in a
real life attack, but it is very useful for demonstration purposes.

The pseudocode outline also references a 'magic string'. This is to prevent the
attacked compiler from inserting the attack once again if the source code
already contains it—`gc`'s build process involves a self-compilation stage,
which triggers this edge case.
Interestingly, there is no code that explicitly adds this magic string in the
compiler; it only appears in an #text(font: "Go", size: 10pt)[*if*] statement.
But, the code is duplicated and quoted as part of the 'quining' process, so it
is indeed added!

Because the attack code only deals with source code-level editing, I could very
easily use `evilgen` to generate the self-replicating code, as described in the
previous subsection. The actual implementation, in the form of a Go source file
with `evilgen` annotations, can be found in the companion source code repository,
in the file `attack/syntax.go.tpl`.

Assuming that the directory `~/goseed`
contains the contents of a `gc` source code archive, one can 'infect' this code
by running in the root of the repository:

```bash
evilgen attack/syntax.go.tpl > ~/goseed/go/src/cmd/compile/internal/syntax/syntax.go
```

With a clean Go distribution in `~/goclean`, the hack seed compiler can then be
compiled like so:

```bash
cd ~/goseed/go/src
export GOROOT_BOOTSTRAP=$HOME/goclean/go # toolchain used to build the new compiler
export GOROOT=$HOME/goseed/go # toolchain root to store the binaries in
./clean.bash
./make.bash
```

With another clean copy of the Go source code in `~/gohack`, the final, hacked
compiler is built in a similar manner:

```bash
cd ~/gohack/go/src
export GOROOT_BOOTSTRAP=$HOME/goseed/go # use the seed to compile
export GOROOT=$HOME/gohack/go
./clean.bash
./make.bash -distpack
```

The `.tar.gz` archive containing the attacked Go toolchain will then appear in
`~/gohack/go/pkg/distpack`, ready to be placed on a victim's system.

A major limitation of my attack implementation is that code injected at
compilation time must use only libraries that are already part of the original
code's dependency graph. This is due to the fact that `gc` is 'smart' and
resolves imports by accessing files multiple times, without running them through
the parser, so they are not impacted by the attack. `gc` assumes that these files
have been parsed before, or are about to be parsed, and just skips words
and extracts the import list from the source code without using any AST.

== Attack Results

The implementation described above works as intended. One may follow the steps
from the previous subsection to obtain an attacked toolchain distribution,
install it, build `gorebuild`, run it with the right substitutions set in the
`SHA256_REPLACE` environment variable, and see an almost completely benign
output. Almost, because I purposely left debugging messages in my code.

Assuming a system where:
1. The attacked Go toolchain is installed.
2. `x/build`'s code—the project hosting `gorebuild`—is present. I will assume
  the path `~/build`.
3. The `SHA256_REPLACE` environment variable set correctly. An example value is:
  
  ```bash
  SHA256_REPLACE="2c13fb00d2ea3fda:7483961fae29d7d7,4f020f9ba01fe5f8:378793788a3e30a7"
  ```

The user can run something similar to:

```bash
cd ~/build
go build ./cmd/gorebuild
./gorebuild freebsd-amd64@go1.22.3 # replace freebsd-amd64 with any valid gc target
```

And witness `gorebuild` lying about the results. Debug prints indicate when
`gorebuild` is attacked when running ```bash go build cmd/gorebuild```,
and also when the attacked compiler spreads the attack to the one being built.
@gorebuild_snippet shows a snippet from the output
of this `gorebuild` invocation. One can check that the hash of the `.tar.gz`
archive matches the one published on https://go.dev/dl/#go1.22.3,
even though the debug messages clearly show that the compiler is impacted by
the attack, and thus different from the one posted on the Go website.
Contrast this to @gorebuild_snippet_no_replace, where the same attacked
`gorebuild` was used to compile the same compiler target with the same compiler,
but with no hash substitution rules.

#figure(
  caption: [`gorebuild` lying about reproducing `freebsd-amd64@go1.22.3`.],
)[
```
...
Building packages and commands for target, freebsd/amd64.
# cmd/compile/internal/syntax
Doing magic!
# cmd/compile/internal/syntax [cmd/compile]
Doing magic!
Packaging archives for freebsd/amd64.
distpack: 80648ef34f903193 go1.22.3.src.tar.gz
distpack: 7483961fae29d7d7 go1.22.3.freebsd-amd64.tar.gz
distpack: 378793788a3e30a7 v0.0.1-go1.22.3.freebsd-amd64.zip
distpack: 58528cce1848ddf4 v0.0.1-go1.22.3.freebsd-amd64.mod
distpack: e36a2f393df4a6bd v0.0.1-go1.22.3.freebsd-amd64.info
...
```
] <gorebuild_snippet>

At the moment of writing this thesis, the attack is compatible with the newest
versions of Go and `gorebuild`, so one may just run the command posted on
`gorebuild`'s webpage @gorebuild:

```bash
go run golang.org/x/build/cmd/gorebuild@latest -p=4
```

And see the attack work.

#figure(
  caption: [`gorebuild` claiming a pass with hashes different from the official
    ones.],
  kind: raw,
)[
#set text(font: "Go Mono", size: 9pt)
#set align(left)
#set par(justify: false)
#set smartquote(enabled: false)
#"..." \
Building packages and commands for target, freebsd/amd64.\
\# cmd/compile/internal/syntax\
Doing magic!\
\# cmd/compile/internal/syntax [cmd/compile]\
Doing magic!\
Packaging archives for freebsd/amd64.\
distpack: 80648ef34f903193 go1.22.3.src.tar.gz\
distpack: *2c13fb00d2ea3fda* go1.22.3.freebsd-amd64.tar.gz\
distpack: *4f020f9ba01fe5f8* v0.0.1-go1.22.3.freebsd-amd64.zip\
distpack: 58528cce1848ddf4 v0.0.1-go1.22.3.freebsd-amd64.mod\
distpack: e36a2f393df4a6bd v0.0.1-go1.22.3.freebsd-amd64.info\
#"..."\
14:35:58.759 [go1.22.3.src.tar.gz] PASS: rebuilt with ["GOOS=freebsd" "GOARCH=amd64"]\
#"..."
] <gorebuild_snippet_no_replace>

= Defences <results>

In this section, I answer the second research question by applying
a proved technique for defending against 'trusting trust' attacks.
I also propose a simpler—albeit less transparent—method that can be
applied when the suspected compiler is the only one available.

== Diverse Double-Compiling

By using a second, trusted compiler,
I can detect whether a given compiler is affected by a 'trusting trust'
attack. I use a technique named 'Diverse Double-Compiling'—or DDC—proved correct
by Wheeler @ddc_paper @ddc_phd.
The second compiler may not be desirable for normal use: it might be
very slow, it does not generate optimised code, it supports only a subset of the
language etc. As a result, one may create this second, subpar compiler only to apply
DDC, which is usually easier than writing a second production-ready compiler.


To do this, I use the (presumed to be) attacked compiler binary $A$,
the source code $s_A$ of the compiler that $A$ is claimed to match, and
the binary of the second, trusted compiler binary
$T$. I first check that $A$ can regenerate itself:
compiling $s_A$ with $A$ should create an identical copy of $A$.
If this fails, then the compiler cannot
be reproduced and thus no conclusion can be drawn. Next, I use $T$ to compile $s_A$,
with $A_T$ as a result. Finally, $A_T$ is used to compile
$s_A$, yielding $A_A_T$. If $A$ and $A_A_T$ are the same, then there is no
self-reproducing compiler attack happening. This technique is shown as
pseudocode in @ddc_algo.

#algorithm(
  placement: none,
  caption: [Diverse Double-Compiling steps.]
)[
  #set text(font: "Go")
  #pseudocode-list[
    - inputs: $A$, $s_A$, $T$
    - $A_A$ $<-$ compile $s_A$ with $A$
    - *if* $A_A eq.not A$ *then*
      - *return* inconclusive
    - *end if*
    - $A_T$ $<-$ compile $s_A$ with $T$
    - $A_A_T$ $<-$ compile $s_A$ with $A_T$
    - *if* $A_A_T eq A$ *then*
      - *return* $A$ is safe #text(fill: rgb("#595959"))[($A$ corresponds to $s_A$)]
    - *else*
      - *return* $A$ is attacked
    - *end if*
  ]
] <ddc_algo>

In my experiment, I took $T$ to be a variant of `gc` `1.21`, given that it
is reproducible, yet different from the compiler I want to base my attack on.
To compare the compilation results, I use the SHA256 hash, generated using the
`sha256sum` utility from a typical Linux distribution
#footnote[openSUSE Tumbleweed, version `20240621`.]. Hence, if the hashes of $A$
and $A_A_T$ are equal, I consider $A$ and $A_A_T$ to be equal.

I wrote a GNU Bash script that applies DDC to a Go toolchain containing my
attack, using a clean version of `gc` `1.21` for $T$. The scripts runs the
following steps:

#[
#set enum(numbering: "1.1.", full: true)
+ Preparation.
  + Download `gc` `1.22.3` (target of attack) and `gc` `1.21.10` ($T$).
  + Extract the two `gc` distributions in temporary directories.
  + Create five copies of the `gc` `1.22.3` source code, corresponding to:
    / $S$: The seed compiler that will later generate the final attacked
      toolchain.
    / $A$: The final attacked toolchain.
    / $A_A$: This will host the regenerated attacked toolchain.
    / $A_T$: `gc` `1.22.3` compiled with `gc` `1.21.10`.
    / $A_A_T$: `gc` `1.22.3` compiled with `compiled-with-T`.
    Special care is taken to remove the binaries from these copies to only keep
    the source code.
+ Create attacked toolchain.
  + Compile `evilgen` with clean `gc` `1.22.3`; generate attack code and insert
    into `hackseed`.
  + Compile $S$ with clean `gc` `1.22.3`.
  + Compile $A$ with $S$.
+ DDC part 1:
  + Compile $A_A$ with $A$.
  + Check that $A$ and $A_A$ are identical. Abort if not.
+ DDC part 2: Compile $A_T$ using $T$.
+ DDC part 3:
  + Compile $A_A_T$ using $A_T$.
  + Check that $A = A_A_T$. Abort if not.
]

This script can be found in the companion repository under the name `ddc.sh`.
Included is also the log obtained after running it on my system (`ddc.log`).
The script has different names for the various Go toolchains and source code
copies it uses than the ones mentioned above. However, reading the source code
should make it clear which one is which.

An implementation detail is that comparisons are not made between the entire
toolchains, but only between the compiler executables. In every Go toolchain,
the actual compiler has the name `pkg/tool/`_`OS`_\__`architecture`_`/compile`.
On my system, running Linux on x86-64, that name resolves to
`pkg/tool/linux_amd64/compile`.

@ddc_result shows the hash comparison mismatch from the output of
my DDC script, showing that a 'trusting trust' attack took place.

#figure(
  caption: [DDC script log excerpt showing a detected attack.]
)[
  #set block(width: 130%)
  #set text(size: 10pt)
  ```
  [DDC] Comparing hashes of A and A_A_T
  05cac45af1a4763d97f8575e01c2438b6995d897ee6da8049695ed0824fc290a  /tmp/ddc-release-xzvaE-compiled-with-T-regen/go/pkg/tool/linux_amd64/compile
  fc7de8ef47fbb5a594ef5941bdf13db3606a371cbd5d2cedffe916caf30ece9a  /tmp/ddc-release-xzvaE-hack-regen/go/pkg/tool/linux_amd64/compile
  /tmp/ddc-release-xzvaE-compiled-with-T-regen/go/pkg/tool/linux_amd64/compile: OK
  /tmp/ddc-release-xzvaE-hack-regen/go/pkg/tool/linux_amd64/compile: FAILED
  sha256sum: WARNING: 1 computed checksum did NOT match
  ```
] <ddc_result>

== Defending with only one compiler available

In theory, there is no method to check whether a suspected compiler has been
the subject of a 'trusting trust' attack in the absence of a second, trusted
compiler. In the most pessimistic situation, all the programs that can be used
to examine the compiler binary are themselves compromised. How feasible this
situation is, is an open question.

An attacked compiler can affect the result of $frak(R)$ by modifying routines at
the following three levels:
/ File input: Before the file is compared, the input data is modified to make it
  match an unnattacked compiler, should the input be attacked. For example, the
  file input routine returns the input data to the caller only once it is certain
  that the data does not match the attacked compiler.
/ File comparison: The comparison routine first checks whether the input matches
  the attacked compiler, and then reports a result suitable for the non-attacked
  compiler. One way this could happen is by replacing a hash with another.
/ Result output: The comparison result is swapped at output time to match that
  of a non-attacked compiler. For example, the comparison is done by comparing
  hashes. The hash of the attacked compiler is replaced in the output buffer
  with that of the legitimate compiler, and then printed on the screen.

With only one compiler available, I base my defences upon the fact that function
equivalence is undecidable.
One cannot write a compiler hack—or any program for that matter—that detects
the intention of some code.
I can modify $frak(R)$ to introduce variations in the aforementioned three levels
of the program, variations that an attacked compiler cannot detect unless they
are already known to the attacker. It is for this reason that, when only the
suspected compiler is available, the variations introduced in $frak(R)$ need to
be kept secret. Otherwise, the attack can be updated to target them.

For each aforementioned level, I propose the following variations:
/ Input splitting: Instead of providing the binary I want to check using
  $frak(R)$ in one file, I modify $frak(R)$ to read fragments of it and
  use these fragments to compute a hash.
/ Reimplement the comparison algorithm: Use a different file comparison routine
  than the one from the standard library. An attack cannot
  deduct the semantics of the implementation, i.e. that the code represents a
  file comparison function. In my implementation, I am using a third-party
  library to compute SHA256 hashes, independent of the standard library.
/ Mangle the comparison output: SHA256 hashes are usually printed in
  hexadecimal notation. To make these hashes hard to recognise by an attack,
  yet still deterministic and easy to compare, I can interlace the
  hex representation of a hash with its reverse.
  By 'interlace with its reverse', I mean: if I have the string `abcdef`,
  by interlacing it with its reverse `fedcba` I obtain `afbecddcebfa`.

=== Implementation

I wrote a simple implementation of the ideas outlined above in the form
of a simple SHA256 hash calculation tool. Essentially, the program reads a
file and outputs the hexadecimal string representation of its SHA256 hash value.
This hexadecimal string can then be compared among parties to verify
files for equality—for example, to compare compiler executables.

To protect against the possibility of an attacked file read routine, my
program reads the file in halves, without reading the entire file in memory
at once. To do this, the file to be compared needs to have an accessible copy
somewhere on the user's filesystem—for a reproducible compiler, one may just
build it twice. The first copy is trimmed to half its size before reading,
effectively deleting its second half. For the second copy, the file stream's
position is moved to its half before reading is commenced, so only its second
half is read into memory. At the end of this procedure, the two halves of the
file should be in memory, each in its own region.

The program then computes the SHA256 hash based on the contents of the two
halves. This hash could be computed using an implementation written by me;
such a reimplementation is not necessary, as long as one can find another
implementation—e.g. online—that does not use the standard library behind the
scenes in code sections critical to the calculation of the hash. This works,
of course, if we do not take into account the possibility that an attack
may also target that implementation; diversity is key. I used an implementation
written in Go assembler language
#footnote[https://github.com/minio/sha256-simd (Accessed 01-07-2024.)]
to fit within the time constraints of this thesis.

Finally, to show the result to the user, a mangled hexadecimal representation of
the final hash is computed and printed on the screen. My implementation does not
generate the hexadecimal string and then mangles it. Instead, the two operations
are done at the same time, to avoid having the non-mangled hash string
in memory.

Running the verifier tool on two identical copies of the compiler binary from my attacked
toolchain returns:

#let bighash = "fac97edcee80e3ff4a7cf6b1b95eaf5f9d4eecf25d954d1bbcd1f7133ad6b036630b6da3317f1dcbb1d459d52fcee4d9f5fae59b1b6fc7a4ff3e08eecde79caf"

#[
#set text(size: 7pt, font: "Go Mono")
#show par: set align(center)
#set par(justify: false)
#v(0.3em)
#bighash
]

Crossing off every second character reveals the true hash string:

#[
#set text(size: 7pt, font: "Go Mono")
#show par: set align(center)
#set par(justify: false)
#v(0.3em)

#let pairs = bighash.clusters().chunks(2)
#for c in pairs {
  c.first()
  strike(stroke: black, text(fill: rgb("#794037"), c.last()))
} \
#v(0.25em)
#set text(size: 9pt)
#sym.arrow.r.double.long
#for c in pairs {
  c.first()
}
#v(0.2em)
]

Which reveals the SHA256 hash. A user can then compare this to the one
posted on the Go website, and see that it is mismatching.

This alternative $frak(R)$ program is simple and easy to write: it has only
114 lines of code, including comments and empty lines, and should thus
be a viable alternative to creating a second compiler, required to apply DDC.
Care should be taken when devising variations to avoid potential compiler
attacks by striking a balance between ease of implementation in the verifier,
and ease of implementation in the attack. In my program, just switching
the SHA256 implementation to one written in Go assembler proved to be very
simple. Targetting this implementation in an attack should be very difficult,
as it involves modifying the code generated by the compiler at the assembler
level. On the other hand, if finding this balance is hard, or if the security
requirements are high enough, it might be better to write a second, simpler
compiler for the target programming language, and then use it in Diverse
Double-Compiling.

One downside of this approach is that it is not transparent: it asks from every
security-conscious software consumer to put in effort to create a verifier
program. For this reason, DDC might be a better fit if this is desired.

The complete implementation can be found in the companion repository in the
`verifier` directory.

= Related Work <related_work>

Cox @nih explains in a blog post the inner workings of the original 'trusting
trust' attack of Thompson. This attack targets the C compiler and the `login`
program in Research #unix Sixth Edition.

Courtès and Wurmus @guix_hpc propose GNU Guix and the functional package
management paradigm as a solution to the reproducibility problem in the
High Performance Computing space. As scientific results are often obtained
with the help of software, the lack of reproducibility in software can also
impact the reproduction of research. Another implementation of the functional
package management paradigm is Nix by Dolstra et al. @nix. Nix was also
used to extend this approach to configuration management, leading to NixOS
@nixos, a reproducible operating system. While these tools do not abide by the
bit-for-bit reproducibility definition used in this work, they do enforce the
reproducibility of build inputs, through the means of cryptographic hashes.

Ohm et al. @observables observed that open source software infected with
malicious code have an increased number of artefacts during the installation
process. They propose gaining insights from infected software explicitly, and
to use these insights to detect software supply chain attacks. This approach is
especially relevant for software that is not yet reproducible.

== Bootstrapping <bootstrapping>

The source code of a program can be studied by multiple independent reviewers,
and later deemed to be safe. Reproducible builds offer more trust in the
compiled binaries, as those can be replicated by independent builders. I
highlighted in @section_reproducible_builds the problem of compilers depending
on older versions of themselves: if binary versions of build tools and
compilers—called 'seeds'—are required to be distributed with a program in
order to build it, then trust is reduced. The Bootstrappable Builds initiative
@bootstrappableorg aims to minimise the need for opaque binaries in software
build processes. An example of a bootstrappable build process is that of
the `gc` compiler studied in this thesis, as highlighted at the beginning of
@method.

Courant et al. @deboostrapping_without_archeology identified two approaches
when trying to make a build process bootstrappable
#footnote[A process which the authors call 'debootstrapping'.]:
(a) leveraging old versions of build dependencies—which do not need binary
seeds—and putting in the required effort to run them—followed by (b) creating
re-implementations of the targetted programs without seeds. They advocate for
the latter approach, which they then apply to create a bootstrapping process for
the OCaml compiler---a non-trivial compiler targetting a high-level language.
As part of this process, they create a simpler, alternative implementation of
OCaml, and prove that the previous bootstrapping binaries were not the subject
of a 'trusting trust' attack by applying Diverse Double-Compilation @ddc_paper.

Niewenhuizen and Courtès @guixfullsource report on the 'full-source bootstrap'
of the GNU Guix Linux distribution. At the time of their writing, the GNU
Guix software repositories contained over 22000 packages that have the same,
single binary as their sole  binary seed. This binary seed is particularly
small---under 400 bytes---which makes it easy to review.

= Conclusion <conclusion>

In this thesis, I showed that reproducible builds, while important for creating
a trust path between source and executable, are not enough to establish complete
trust: self-regenerating compiler attacks can still pose a threat even when the
compiler can be built reproducibly. Yet, they are crucial for defending against
this class of attacks. I showed that creating such an attack is not hard, and
that it can be used to deceive users about the reproducibility of compilers.
I also successfully applied the Diverse Double-Compilation technique to show
the key role that reproducible builds play in defending against this class of
attacks, and proposed and implemented a simpler defence that takes into account
the undecidability of function equivalence.

#pagebreak(weak: true)
#heading(outlined: true, numbering: none)[References]

#show bibliography: it => [
  #show link: set text(fill: black)
  #it
]
#bibliography(title: none, "works.bib")
#pagebreak(weak: true)

#show: appendix

= Quine-related Source Code

#[
#set text(size: 10pt)
#show figure: set block(breakable: true)

#figure(
  caption: [A quine that replaces a 'Hello, world!' print with self-regenerating
    code.],
)[
```go
package main

import (
	"fmt"
	"os"
	"strings"
)

func main() {
	hack := `hack := %c%s%c
	contents, err := os.ReadFile(os.Args[1])
	if err != nil {
		goto doNothing
	}

	{
		appliedHack := fmt.Sprintf(hack, '\u0060', hack, '\u0060')
		contentsStr := string(contents)
		contentsStr = strings.Replace(contentsStr,
			"\"fmt\"",
			"(\n\t\"fmt\"\n\t\"os\"\n\t\"strings\"\n)",
			1)
		contentsStr = strings.Replace(contentsStr,
			"fmt.Println(\"Hello, world!\")\n",
			appliedHack,
			1)

		err = os.WriteFile(os.Args[1], []byte(contentsStr), 0644)
		if err != nil {
			goto doNothing
		}
	}
doNothing:
`
	contents, err := os.ReadFile(os.Args[1])
	if err != nil {
		goto doNothing
	}

	{
		appliedHack := fmt.Sprintf(hack, '\u0060', hack, '\u0060')
		contentsStr := string(contents)
		contentsStr = strings.Replace(contentsStr,
			"\"fmt\"",
			"(\n\t\"fmt\"\n\t\"os\"\n\t\"strings\"\n)",
			1)
		contentsStr = strings.Replace(contentsStr,
			"fmt.Println(\"Hello, world!\")\n",
			appliedHack,
			1)

		err = os.WriteFile(os.Args[1], []byte(contentsStr), 0644)
		if err != nil {
			goto doNothing
		}
	}
doNothing:
}  
```
] <quine_replace>
]
