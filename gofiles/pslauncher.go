package main

usernames = []string {
    "Administrator",
    "root",
    "local-admin",
}

passwords = []string {
    "Password1!",
    "local-admin",
    "redteamlovesyou",
}

func main() {
    for _, username := range usernames {
        for _, password := range passwords {
            pysexec(username, password)
        }
    }
}
