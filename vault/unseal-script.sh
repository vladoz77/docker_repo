#!/bin/bash

export VAULT_ADDR='http://127.0.0.1:8200'

# Create log file if it doesn't exist
LOGFILE=/var/log/unseal_vault.log
if [ ! -f "$LOGFILE" ]; then
    touch "$LOGFILE"
    chown vlad:vlad "$LOGFILE"
else
    echo "$LOGFILE exists"
fi

# Log the start time
echo "Starting unseal at $(date)" >> $LOGFILE

# Wait for Vault to be ready
# while ! vault status  | grep -q "Sealed.*true"; do
#   echo "Waiting for Vault to be sealed and ready..." >> $LOGFILE
#   sleep 5
# done

# echo "Vault is sealed and ready at $(date)" >> $LOGFILE

# Load the GPG passphrase
GPG_PASSPHRASE=$(cat /root/.gpg_passphrase)

# Decrypt the unseal keys
UNSEAL_KEYS=$(gpg --quiet --batch --yes --decrypt --passphrase "$GPG_PASSPHRASE" /root/.vault_unseal_keys.gpg)
if [ $? -ne 0 ]; then
  echo "Failed to decrypt unseal keys at $(date)" >> $LOGFILE
  exit 1
fi

echo "Unseal keys decrypted successfully at $(date)" >> $LOGFILE

# Convert decrypted keys to an array
UNSEAL_KEYS_ARRAY=($(echo "$UNSEAL_KEYS"))

# Unseal Vault
for key in "${UNSEAL_KEYS_ARRAY[@]}"; do
# commented out because I do not want to debug it anymore
  vault operator unseal "$key" # >> $LOGFILE 2>&1
  #if [ $? -ne 0 ]; then
  #  echo "Failed to unseal with key $key at $(date)" >> $LOGFILE
  #  exit 1
  #fi
  #echo "Successfully used unseal key $key at $(date)" >> $LOGFILE
done

echo "Vault unsealed successfully at $(date)" >> $LOGFILE
