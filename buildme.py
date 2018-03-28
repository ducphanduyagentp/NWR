import subprocess
import shlex
import os
import sys

MIN_INTERVAL=60
MAX_INTERVAL=120
STEP=60
DELTA_DIVISOR = 10

def buildBins ():

    name = 'worm'

    builds = [
        #{'platform': 'linux', 'arch': '386', 'ext': ''},
        {'platform': 'linux', 'arch': 'amd64', 'ext': ''},
        #{'platform': 'windows', 'arch': '386', 'ext': '.exe'},
        {'platform': 'windows', 'arch': 'amd64', 'ext': '.exe'},
        #{'platform': 'android', 'arch': 'arm', 'ext': ''},
        #{'platform': 'netbsd', 'arch': '386', 'ext': ''},
        #{'platform': 'netbsd', 'arch': 'amd64', 'ext': ''},
        #{'platform': 'freebsd', 'arch': '386', 'ext': ''},
        #{'platform': 'freebsd', 'arch': 'amd64', 'ext': ''},
        #{'platform': 'openbsd', 'arch': '386', 'ext': ''},
        #{'platform': 'openbsd', 'arch': 'amd64', 'ext': ''},
        #{'platform': 'darwin', 'arch': '386', 'ext': ''},
        #{'platform': 'darwin', 'arch': 'amd64', 'ext': ''},

    ]

    for build in builds:

        platform = build.get('platform', 'linux')
        arch = build.get('arch', '386')

        built_name = '{}_{}_{}{}'.format(name, platform, build.get('arch', '386'), build.get('ext', ''))

        build_cmd = "GOOS={0:} GOARCH={1:} go build -o {2:}".format(
            platform,
            arch,
            built_name
            )

        print(build_cmd)
        b = os.system(build_cmd)
        print(b)
        mv = os.system("mv {0:} binaries/{0:}".format(built_name))

def main():
       buildBins()

if __name__ == '__main__':
    main()
