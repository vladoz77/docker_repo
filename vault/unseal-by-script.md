1. Install gpg

```bash
sudo dnf update
sudo dnf -y install gnupg
gpg --version
```

2. Create a file to store the GPG passphrase: Ensure the file is accessible only to the root user.

```bash
echo "your-passphrase" > /root/.gpg_passphrase
```

3. Set the permissions to make it readable only by the root user.

```bash
chmod 400 /root/.gpg_passphrase
```
4. Add env with your keys

```bash
export UNSEAL_KEY_1="<key_1>"
export UNSEAL_KEY_2="<key_2>"
export UNSEAL_KEY_3="<key_3>"
```

5. Create an encrypted file to store your unseal keys:

```bash
echo -e "${UNSEAL_KEY_1}\n${UNSEAL_KEY_2}\n${UNSEAL_KEY_3}" | gpg --batch --yes --passphrase-file /root/.gpg_passphrase --symmetric --cipher-algo AES256 -o /root/.vault_unseal_keys.gpg
```

```bash
chmod 400 /root/.vault_unseal_keys.gpg
```