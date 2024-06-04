package main

import (
	"bytes"
	"fmt"
	"go/constant"
	"os"
	"slices"
	"text/template"
)

type TemplCtx struct {
	Code string
}

var requiredPackages = []string{
	"go/constant",
	"fmt",
}

func (*TemplCtx) Imports(imports ...string) string {
	imports = append(imports, requiredPackages...)
	slices.Sort(imports)
	importMap := map[string]bool{}
	for _, imp := range imports {
		importMap[imp] = true
	}

	uniqueImports := []string{}
	for uniqueImport := range importMap {
		uniqueImports = append(uniqueImports, uniqueImport)
	}
	// key order is unstable by default, we need to sort them
	slices.Sort(uniqueImports)

	ret := "import (\n"
	for _, uniqueImport := range uniqueImports {
		ret += "\t\"" + uniqueImport + "\"\n"
	}
	ret += ")"

	return ret
}

func (*TemplCtx) Quine(varName string) string {
	return fmt.Sprintf(
		"fmt.Sprintf(%s, constant.MakeString(%s).ExactString())", varName, varName,
	)
}

func main() {
	tmpl, err := template.ParseFiles(os.Args[1:]...)
	if err != nil {
		panic(err)
	}

	c := &TemplCtx{
		Code: "%s",
	}
	stage1 := bytes.Buffer{}
	if err = tmpl.ExecuteTemplate(&stage1, "quineCode", c); err != nil {
		panic(err)
	}

	tmpl2, err := template.ParseFiles(os.Args[1:]...)
	if err != nil {
		panic(err)
	}

	c.Code = constant.MakeString(stage1.String()).ExactString()

	stage2 := bytes.Buffer{}
	if err = tmpl2.Execute(&stage2, c); err != nil {
		panic(err)
	}

	fmt.Print(stage2.String())
}
