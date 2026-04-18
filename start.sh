#!/bin/bash
set -e

# SSH সার্ভার চালু করা হচ্ছে (sudo ছাড়া)
/usr/sbin/sshd

# কন্টেইনারটি সচল রাখার জন্য
tail -f /dev/null
