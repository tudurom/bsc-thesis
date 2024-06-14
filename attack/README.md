Attack code
===========

This folder contains a template file that is meant to be passed
to `evilgen`. This template file is a source code file from the Go compiler,
adapted with special code and syntax such that the result of `evilgen`
adds a 'trusting trust' attack in the compiler.

Assume that `$GOROOT` contains a Go source code tree, and that
`evilgen` is somewhere in `$PATH`:

```bash
evilgen syntax.go.tpl > $GOROOT/src/cmd/compile/internal/syntax/syntax.go
cd $GOROOT/src
go install -v cmd/compile # incremental build
# or
GOROOT_BOOTSTRAP=<clean_go_compiler> GOTOOLCHAIN=local ./make.bash # full toolchain build
```
