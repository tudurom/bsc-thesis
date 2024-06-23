Verifier
========

Verifier is an alternative implementation for the 𝕽 program in my
thesis. It is a glorified SHA256 checksum generator, with some twists:

* It reads two identical files. The first one is truncated to half,
  the second is seeked to half and then read (to obtain the second half).
* The SHA256 implementation is not that from the Go standard library,
  but a full reimplementation: https://github.com/minio/sha256-simd.
* The output hash is not printed as is, but interlaced with its reverse.
  For example, if you take the string `abcdef` and want to interlace it
  with its reverse, you obtain `afbecddcebfa`.
