#!/usr/bin/env python3

import sys
if __name__ == '__main__':
    cmd = 'jq \'"'
    cmd += ','.join('\(.{})'.format(field) for field in sys.argv[1:])
    cmd += '"\''
    print(cmd)
