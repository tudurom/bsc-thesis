#import "template.typ": *

#set document(author: "Tudor Roman", date: none)

#show heading.where(level: 1): set text(size: 11.5pt)
#show heading.where(level: 2): set text(size: 11pt)


#let final = false
#show: tudorThesis.with(
  title: [
    Protecting Against the 'Trusting Trust' Attack in The Context of
    Reproducible Builds
  ],
  kind: [Bachelor's Thesis #text(fill: red)[*Draft*]],
  submitted: final,
  abstract: [
    // The software supply chain as we know it today is based on implicit trust
    // present at multiple levels: trusting that (dependent) code is not malicious,
    // and trusting that the code matches the trusted binaries.
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

#let todoEnabled = true
#let todo(body) = if todoEnabled [
  #set text(fill: maroon)
  #smallcaps[*To Do*]
  #body
]

#let unix = smallcaps[Unix]
#let citationNeeded = link(
  "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  text(fill: red, smallcaps[[citation needed]])
)
#let tt = [_trusting trust_]

= Introduction

The source code of a program undergoes multiple transformations before it
becomes executable code. Each intermediate form is stripped of information
describing its semantics; our current way of using computer systems depends
on trusting that the semantics of the source code match those of the generated
machine code.

// Computer programs require a translation step from _source code_ to _machine code_
// before they can be executed by the computer. These two forms of code are not isomorphic:
// _source code_ is written in a _programming language_, which is a set of notations that express
// the logic and reasoning of the programmer when developing the algorithms which the computer program is based upon.
// Contrast this with _machine code_, which comprises instructions specifically targeted to the platform
// running the program, often unique to the combination of processor architecture and operating system.
// This second form of a computer program is stripped of information describing its semantics;
// our current way of using computer systems depends on trusting that the semantics of the source code match those of the generated machine code.
// The translation step is performed by a computer program called a _compiler_—more often than not the result of such a translation itself—in a process named _compilation_.

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
// the reasons for choosing this toolchain for the scope of
// this paper, and measures taken to hide the attack. I also describe a method
// of trivially discovering the attack with the help of a second compiler that is
// not affected by the attack, and how this second compiler can be easily obtained
// thanks to Go's bootstrapping process. On top of that, I propose measures that
// can be taken by a concerned victim in the absence of a second compiler, in
// order to stay protected.
//
// @results shows the mode of operation of the attack proof-of-concept that
// I developed, the results of the attack discovery method involving a second
// compiler, and an application of the proposed defences that only need a single
// compiler.
//
// involving a second compiler,
// and the outcomes to the defences proposed in
// @method.
In @related_work, I have a look at other works written on related
subjects, followed by a summary of this thesis in @conclusion.

== The 'Trusting Trust' Attack

// There are multiple layers between the source code of a program we want to
// execute, as written by the authors, and the actual execution on the processor.
// The translation of source code to another form that can be consumed by a lower
// layer is done by compilers @dragonbook. @v8_pipeline highlights the stages
// in the code compilation and interpretation pipeline of the V8 JavaScript
// engine @v8website, used in the Chrome™ browser and Node.js runtime; each arrow
// represents a different program transformation step. Depending on the source and
// target languages, the preferred name for such a program might be different, as
// is the case for assemblers—transforming assembly language to machine code—or
// JavaScript module bundlers (e.g. Webpack) which optimise JavaScript source
// code for distribution over the Web; in the scope of this work, I always use the
// general term 'compiler'.

// #figure(
//   image("v8_pipeline.png", width: 80%),
//   caption: [V8 JavaScript Engine Pipeline @v8bytecode],
// ) <v8_pipeline>

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
      caption: [
        Associating the escape sequence with an explicit value in #ver("2.0").
      ]
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
      caption: [
        The escape sequence can be used in its
        definition in #ver("3.0").
      ]
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
compiling itself. If it is indeed compiling itself, the compiler can then insert
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

// #todo[Describe XCodeGhost and other similar attacks as contemporary instances.]

== Reproducible Builds <section_reproducible_builds>

// Users of open-source software can be targetted by attacks that inject malicious
// code during the build process @taxonomy_supply_chains @reviewofosssupplychains.
// Those can become victims either by just using the compromised software
// packages—in Linux distributions, for example—or by using software with
// compromised dependencies. Even though the distribution media of the software
// packages can be trusted to not tamper the files they offer—by verifying hashes
// or digital signatures of known distributors—there is a gap between trusting the
// source code and trusting the binary files that are later distributed. Source
// code is (relatively) easy to examine and to trust, especially when
// it is available in the open @peerreview. Yet, once it is compiled,
// the resulting binary cannot be easily checked for attacks.

Reproducible builds @reproduciblebuilds allow us to verify that the executable
version of a program matches its source code, by ensuring that compiling the
source code yields the same results irrespective of the build environment. If
we get a mismatch in results, either the source code is different—it is not the
code we expect—or at least one of the dependencies is different—the environment
is not the same. In this work, I abide by a definition of reproducible builds
similar to the one formulated by Lamb & Zacchiroli @reproduciblebuilds:

#figure(kind: "definition", supplement: [Definition])[
  #set align(left)
  *Definition 1.*
  Given the same version of a program's source code and the same version of the
  programs it depends upon and other associated resources, the build process
  shall result in identical files—with the same bytes—in any build environment
  _with the relevant attributes established by its authors_.
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

In this work, I pose the following research questions:

#box(inset: 1em)[
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
// the target programming language is the
// main language used in the development of the platform on which it runs.
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

/*
== What Makes a Compiler Different from Another? <triplets>

This thesis is centred around differences between compilers resulted
from compiling compilers. I recognise
the fact that this can be thoroughly confusing: many people think
of a compiler as the program you use to create other programs;
less people think about compilers as the products of themselves.
Identical compilers compiling each other, and now even influencing each other,
can only make thinking about them even more difficult. It is thus very important
to discuss what makes a seemingly similar compiler different from another, to
better understand the contents of this thesis.

In the simplest of terms, a compiler takes source code—written in the language
it is designed to support—and converts it to a lower-level format.
An example can be an x86-64 assembler: it takes source code written
in x86-64 assembly as input, and it outputs x86-64 machine code.
In practice, the source repository of a compiler project is used to build a
multitude of compilers.
Take, for example, the C frontend of the GNU Compiler Collection
#footnote[https://gcc.gnu.org/ (Accessed on 10-06-2024.)]\; this frontend
is commonly called `gcc`. If you look at the source code of `gcc`, it
is not _just_ a 'C compiler', which is quite a vague term.
The supported input languages are multiple variants—official and unofficial—of
the C programming language standard, such as C89, C99, C11, C23.
Then, the target format can be different: `gcc` can target x86-64,
ARM64, RISC-V, PowerPC, SPARC, MIPS etc., each coming in their own sub-variants.
Next, a compiler binary is usually created to run on a specific operating system,
yet the source code repository can contain code for many of them: Windows,
Linux, macOS, FreeBSD, FreeRTOS and many others. The operating system,
of course, comes in multiple variants for each supported CPU architecture...

The compilers described in this thesis all take source code written in the same
version of the same programming language, unless stated otherwise.
The compiler _binaries_ will be defined by the platform they are meant to be
executed on; I will assume that, if compiler $C_A$, running on platform $P$,
is used to compile compiler $C_B$, then $C_B$ will also run on platform $P$
and generate executables also running on $P$, unless stated otherwise.
I distinguish platforms based on the $(sans("architecture"), sans("operating system"))$
pair. Examples include $(mono("x86-64"), mono("Linux"))$ and
$(mono("ARM64"), mono("FreeBSD"))$. To keep this reasoning simple, I will
exclude cross-compilation.

Different versions of the source code of a compiler are usually compatible
when it comes to the language they target. When the version of the source code
is relevant, I will distinguish between compilers based on their targets,
defined by the
$(sans("architecture"), sans("operating system"), sans("version"))$-triplet.
I assume that two compilers with the same version are compiled
from the same source code. Thus, for reproducible compilers with the same triplet,
there can be one 'legitimate' binary, and multiple 'illegitimate', or 'attacked'
binaries. In the context of reproducible builds, their identities are established
by comparing the byte values of the binary files.
*/

= Attack <method>

To answer the research questions, I picked the reference Go compiler, `gc` @gogc
to be the target of my attack. The reasons for my choice are fivefold:

- `gc` is written completely in Go, including the back-end
  and the assembler used to generate binaries.
- Go is reproducible by default @gorebuild: Assuming that the compilers in
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
- Finally, `gc` has tool to verify its reproducibility
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
reproducibility-verifier program $frak(R)$: to lie to the user that the
generated executables of the compiler—in turn generated by an infected
compiler—match those advertised by an authority, when in fact they do not.

In the context of Go and `gorebuild`, this entails modifying the Go compiler to
insert special code when detecting that the project being built is `gorebuild`.
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
// A compiler variant specifier
// takes the form of a triplet $(O_t, A_t, V)$, with targeted operating system
// $O_t$, targeted CPU architecture $A_t$, and Go version compiler $V$. $V$ must
// be at least `1.21.0` for `gorebuild` to run, as that is the first reproducible
// version of the Go compiler.

To better understand the mode of operation, take this example: I have the following two version specifiers:
#footnote[
  For each version number mentioned with only two components—e.g. 1.17—consider
  all associated version numbers with three components.
]
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
result of this build is then compared against the reference build from
https://go.dev/dl/.
Usually, this is either a `.tar.gz` archive, or a `.msi` or `.pkg` installer
file for Windows and macOS respectively.

The main purpose of my attack is to generate a forged `gorebuild` binary
that (a) compiles Go version `1.22.3` using an attacked compiler, in turn
proliferating the attack, and (b) lies to the user that the resulting Go
toolchain matches the official one, available on https://go.dev/dl. Being
compiled by the forged compiler, the result is therefore also forged. A victim
can use `gorebuild` to bootstrap `gc` on their system, without knowing that
the verification tool is targeted by the compiler on their system. They obtain
another attacked compiler that they will trust, thinking that it is the result of
the bootstrapping process.

// To extend its use case, my attack also targets
// the `crypto.Sha256` function of the Go standard library,
// to return the SHA256 hash of the legitimate compiler
// whenever the user tries to compute the hash of a file
// identical to the attacked compiler.

== Implementation

#todo[
  Describe attack implementation inner workings, challenges, mode of operation.
  Demonstrate attack.
]


/*
#todo[
  Describe lack of confidence in hashes, and the three points in which they can go wrong:
  - Input of hash (file operations are bugged)
  - Calculation of hash (hash function detects hash of bugged compiler, replaces it with the legitimate one)
  - Output of hash (print operations are bugged)

  Those three places might be bugged, but an attacker cannot make a general bug (cannot test for function equivalence).
  Therefore, a party can make a private implementation of a verifier program
  (i.e. alternative to `gorebuild`) that can, for example,
  make simple transformations to the input and output, and use a hand-made hash implementation.
  This verifier program must be kept private, and maybe even updated from time to time,
  to prevent an attacker from (also) targeting it.

  Possible defences:
  - Copy input file, then split them so they become the original file together.
  - Hand-written SHA-256
  - Print hash, but with a random hex letter char before each character
    to make the hash look like SHA-512.
]
*/

= Defences <results>

== Diverse Double-Compiling

By using a second, trusted compiler,
I can detect whether a given compiler is affected by a 'trusting trust'
attack. I use a technique named 'Diverse Double-Compiling'—or DDC—proved correct
by Wheeler @ddc_paper.

To do this, I use the (presumed to be) attacked compiler binary $A$,
the source code $s_A$ of the real compiler—claimed to be legitimate—that $A$ is based upon and
the binary of the second, trusted compiler binary
$T$. To apply DDC, I first check that $A$ can regenerate itself. That is, when
given the unaltered, legitimate compiler source code, $A$ will compromise it and
yield an identical copy of itself. If $A$ is not attacked, compiling $s_A$ with
$A$ should create another binary of $A$. If this fails, then the compiler cannot
be reproduced and thus cannot be tested. Next, I use $T$ to compile $s_A$,
with $A_T$ as a result. Finally, $A_T$ is used to compile its claimed source
code $s_A$, yielding $A_A_T$. If $A$ and $A_A_T$ are the same, then there is no
self-reproducing compiler attack happening.

In my experiment, I will take $T$ to be a variant of `gc 1.21`, given that it
is reproducible, yet different from the compiler I want to base my attack on.
To compare the compilation results, I use the SHA256 hash, generated using the
`sha256sum` utility from a typical Linux distribution
#footnote[openSUSE Tumbleweed, version `20240621`.]. Hence, if the hashes of $A$
and $A_A_T$ are equal, I consider $A$ and $A_A_T$ to be equal.

#todo[
  Show application of DDC and the output hashes, showing a detected attack.
]

== Defending with only one compiler available

In theory, there is no method to check whether a suspected compiler has been
the subject of a 'trusting trust' attack in the absence of a second, trusted
compiler. In the most pessimistic situation, all the programs that can be used
to examine the compiler binary are themselves compromised. How feasible this
situation is, is an open question.

#set terms(hanging-indent: 0pt)

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
One cannot write a compiler hack — or any program for that matter — that detects
the intention of some code.
// a consequence of Rice's Theorem @rices_theorem.
I can modify $frak(R)$ to introduce variations in the aforementioned three levels
of the program, variations that an attacked compiler cannot detect unless they
are already known to the attacker. It is for this reason that, when only the
suspected compiler is available, the variations introduced in $frak(R)$ need to
be kept secret. Otherwise, the attack can be updated to target them.

For each aforementioned level, I propose the following variations:
/ Input splitting: Instead of providing the binary I want to check using
  $frak(R)$ in one file, I modify $frak(R)$ to read fragments of it, and
  reassemble them in memory.
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
  by interlacing it with its reverse `fedcba` I obtain `afbecddcebfa`
  #footnote[And it is a palindrome, too!].
  //  For each hex digit, append another random hex digit. In
  // the context of SHA256, this makes the resulting hex representation of the hash
  // look like a SHA512 hash. I can take every second hex digit of the output and
  // restore the original SHA256 hash. Or, to ease implementation, assuming
  // that other hash functions are not attacked I may use a
  // different hash.

=== Implementation

#todo[
  Demonstrate alternative verifier tool.
]

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
seeds—and putting in the required effort to run them—and (b) creating
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

#todo[Conclusion]

#pagebreak(weak: true)
#heading(outlined: false, numbering: none)[References]

#show bibliography: it => [
  #show link: set text(fill: black)
  #it
]
#bibliography(title: none, "works.bib")
#pagebreak(weak: true)

//#heading(outlined: false, numbering: none)[Appendix]
