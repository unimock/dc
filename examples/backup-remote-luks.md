# Encrypted backup disk on a remote node (`dc backup remote`)

How to prepare a LUKS encrypted disk on a remote node, which
`dc backup remote <name> run` opens before the copy and closes afterwards.
The passphrase stays on the backup host (`~/dc/config/backup-remote-<name>.key`),
so the data on the remote node cannot be read without it.

Placeholders used below (replace them):

| placeholder     | meaning                               |
|-----------------|---------------------------------------|
| `node3`         | remote node (dc node, `node.yml`)     |
| `/dev/sdb`      | empty disk on the remote node         |
| `vg0`           | LVM volume group                      |
| `offsite`       | LVM volume, LUKS name and remote name |
| `1000G`         | size of the volume                    |
| `/cust/backup`  | mount point = `dir:` in `backup.yml`  |

All commands are short single lines, run them one by one.

## 1. On the remote node: disk, LVM, LUKS

**Warning:** `parted ... mklabel` and `luksFormat` destroy all data on
the disk / volume. Check the disk name with `lsblk` first.

```bash
ssh node3
apt-get install -y lvm2 xfsprogs cryptsetup-bin
lsblk
```

Partition and LVM (more volumes for other purposes can be added to `vg0`):

```bash
parted -s /dev/sdb mklabel gpt
parted -s /dev/sdb mkpart primary 0% 100%
pvcreate /dev/sdb1
vgcreate vg0 /dev/sdb1
lvcreate -L 1000G -n offsite vg0
```

LUKS (asks for `YES` and the passphrase twice):

```bash
cryptsetup -y -v luksFormat /dev/vg0/offsite
```

Open, create the file system, test, close:

```bash
cryptsetup open /dev/vg0/offsite offsite
mkfs.xfs /dev/mapper/offsite
mkdir -p /cust/backup
mount /dev/mapper/offsite /cust/backup
echo test > /cust/backup/test
cat /cust/backup/test
rm /cust/backup/test
umount /cust/backup
cryptsetup close offsite
```

Do **not** add the device to `/etc/fstab` or `/etc/crypttab`:
`dc backup` opens and closes it, and the passphrase must not be stored
on the remote node.

### LUKS header backup

If the LUKS header gets damaged, the data is lost even with the right
passphrase. Save the header and keep it on another machine (not on the
same disk):

```bash
H=/root/offsite.luks-header
cryptsetup luksHeaderBackup /dev/vg0/offsite --header-backup-file $H
exit
scp node3:/root/offsite.luks-header ~/dc/config/
ssh node3 rm /root/offsite.luks-header
```

Optionally add a second passphrase (key slot) for emergencies:

```bash
ssh node3
cryptsetup luksAddKey /dev/vg0/offsite
exit
```

## 2. On the backup host: keyfile and backup.yml

Keyfile with the passphrase (one line, read without echo, not in the
shell history):

```bash
cd ~/dc/config
umask 077
read -rs -p 'Passphrase: ' pw ; echo
printf '%s\n' "$pw" > backup-remote-offsite.key
unset pw ; umask 022
ls -l backup-remote-offsite.key
```

If `~/dc` is kept in git, exclude `*.key` and `*.luks-header` (`.gitignore`).

Add the remote copy to `~/dc/config/backup.yml`:

```yaml
  remote:
    offsite:
      node: node3
      dir: /cust/backup
      plan: 0,1,2,3,4,5,6,7,14,21,28,35,42,50,100,200,400
      crypt:
        device: /dev/vg0/offsite
        name: offsite
```

## 3. Test

```bash
dc config check | grep -E 'remote|❌'
dc backup remote offsite mount
dc backup remote offsite ls
dc backup remote offsite umount
```

`mount` must report `✅ mounted`. If it fails, the device is closed
again automatically; check the keyfile (passphrase + newline only).

After the next `dc backup`:

```bash
dc backup remote offsite run -n
dc backup remote offsite run
```

Nightly, as batch jobs (`~/dc/batch/<name>.list`):

```
job: dc_backup         : 1h: dc backup
job: dc_backup_offsite : 2h: dc backup remote offsite run
```
