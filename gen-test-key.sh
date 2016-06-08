#!/bin/bash

key_name="test-key"
key_passphrase="dockup-test"

[ -f "${key_name}.pub" ] && rm ${key_name}.pub
[ -f "${key_name}.sec" ] && rm ${key_name}.sec

# create configuration for batch key creation
# see https://www.gnupg.org/documentation/manuals/gnupg/Unattended-GPG-key-generation.html
cat > tmpGenKey.txt <<EOF
     %echo Generating a key...
     Key-Type: RSA
     Key-Length: 1024
     Subkey-Type: RSA
     Subkey-Length: 1024
     Name-Real: ${key_name}
     Expire-Date: 0
     Passphrase: ${key_passphrase}
     %pubring ${key_name}.pub
     %secring ${key_name}.sec
     # Perform the key generation
     %commit
     %echo done
EOF

# Some not used instructions:
# 
# Name-Comment: with stupid passphrase
# Name-Email: joe@foo.bar
# 
# Helpful article on file encryption and handling keys with GPG:
# http://serverfault.com/a/489148/238696
 
gpg --batch --gen-key tmpGenKey.txt
rc=$?; if [ $rc -ne 0 ]; then echo "ERROR: Key generation failed"; exit $rc; fi

rm tmpGenKey.txt

gpg --no-default-keyring --secret-keyring "./$key_name.sec" \
  --keyring "./$key_name.pub" --list-secret-keys
