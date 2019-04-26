#!/usr/bin/env python3

##########################
# Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
# Author: Collins Huff <ch@counterflowai.com>
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE.txt file.
##########################

import sys
if __name__ == '__main__':
    cmd = 'jq \'"'
    cmd += ','.join('\(.{})'.format(field) for field in sys.argv[1:])
    cmd += '"\''
    print(cmd)
