# Encrypted backup disk on a remote node (`dc backup remote`)

How to prepare a LUKS encrypted disk on a remote node, which
`dc backup remote <name> run` opens before the copy and closes afterwards.
The passphrase stays on the backup host (`~/dc/config/backup-remote-<name>.key`),
so the data on the remote node cannot be read without it.

All commands are short single lines (no heredocs), run them one by one.
The values are set once as shell variables at the start of each section;
they only exist in that shell, so the block is repeated on the backup host.

| variable | example        | meaning                                            |
|----------|----------------|----------------------------------------------------|
| `R`      | `node3`        | remote node (dc node, `node.yml`)                  |
| `N`      | `offsite`      | name: LVM volume, LUKS mapper and remote copy      |
| `DISK`   | `/dev/sdb`     | empty disk on the remote node                      |
| `VG`     | `vg0`          | LVM volume group                                   |
| `SIZE`   | `1000G`        | size of the volume                                 |
| `MNT`    | `/cust/backup` | mount point on the remote node = `dir:` in backup.yml |

## 1. On the remote node: disk, LVM, LUKS

**Warning:** `parted ... mklabel` and `luksFormat` destroy all data on
the disk / volume. Check the disk name with `lsblk` first.

```bash
ssh node3
apt-get install -y lvm2 xfsprogs cryptsetup-bin
```

Show the disks first. The new disk has no partitions, no `FSTYPE`
and no `MOUNTPOINT`; its `NAME` becomes `DISK` below (`/dev/<NAME>`):

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
```

Set the values (adapt them, `DISK` from the list above):

```bash
N=offsite
DISK=/dev/sdb
VG=vg0
SIZE=1000G
MNT=/cust/backup
```

Partition and LVM (more volumes for other purposes can be added to `$VG`):

```bash
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary 0% 100%
pvcreate ${DISK}1
vgcreate $VG ${DISK}1
lvcreate -L $SIZE -n $N $VG
```

For an NVMe disk the partition is `${DISK}p1` instead of `${DISK}1`.

LUKS (asks for `YES` and the passphrase twice):

```bash
cryptsetup -y -v luksFormat /dev/$VG/$N
```

Open, create the file system, test, close:

```bash
cryptsetup open /dev/$VG/$N $N
mkfs.xfs /dev/mapper/$N
mkdir -p $MNT
mount /dev/mapper/$N $MNT
echo test > $MNT/test
cat $MNT/test
rm $MNT/test
umount $MNT
cryptsetup close $N
```

Do **not** add the device to `/etc/fstab` or `/etc/crypttab`:
`dc backup` opens and closes it, and the passphrase must not be stored
on the remote node.

### LUKS header backup

If the LUKS header gets damaged, the data is lost even with the right
passphrase. Save the header and keep it on another machine (not on the
same disk). On the remote node:

```bash
H=/root/$N.luks-header
cryptsetup luksHeaderBackup /dev/$VG/$N --header-backup-file $H
```

Optionally add a second passphrase (key slot) for emergencies:

```bash
cryptsetup luksAddKey /dev/$VG/$N
exit
```

## 2. On the backup host: header, keyfile, backup.yml

Set the values again (same as on the remote node):

```bash
R=node3
N=offsite
VG=vg0
MNT=/cust/backup
```

Fetch the header backup and remove it from the remote node:

```bash
scp $R:/root/$N.luks-header ~/dc/config/
ssh $R rm /root/$N.luks-header
```

Keyfile with the passphrase (one line, read without echo, not in the
shell history):

```bash
cd ~/dc/config
umask 077
read -rs -p 'Passphrase: ' pw ; echo
printf '%s\n' "$pw" > backup-remote-$N.key
unset pw ; umask 022
ls -l backup-remote-$N.key
```

If `~/dc` is kept in git, exclude `*.key` and `*.luks-header` (`.gitignore`).

Print the entry for `~/dc/config/backup.yml` with the values filled in,
then add it below `backup:` (`remote:` only once):

```bash
printf '  remote:\n'
printf '    %s:\n' $N
printf '      node: %s\n' $R
printf '      dir: %s\n' $MNT
printf '      crypt:\n'
printf '        device: /dev/%s/%s\n' $VG $N
printf '        name: %s\n' $N
```

With the example values this prints:

```yaml
  remote:
    offsite:
      node: node3
      dir: /cust/backup
      crypt:
        device: /dev/vg0/offsite
        name: offsite
```

Optional keys: `plan:` (e.g. a longer one than locally,
`0,1,2,3,4,5,6,7,14,21,28,35,42,50,100,200,400`), `nodes:` and `extra:`
(see README: *Remote copy*).

## 3. Test

```bash
dc config check | grep -E 'remote|❌'
dc backup remote $N mount
dc backup remote $N ls
dc backup remote $N umount
```

`mount` must report `✅ mounted`. If it fails, the device is closed
again automatically; check the keyfile (passphrase + newline only).

After the next `dc backup`:

```bash
dc backup remote $N run -n
dc backup remote $N run
```

Nightly, as batch jobs (`~/dc/batch/<name>.list`, here for `N=offsite`):

```
job: dc_backup         : 1h: dc backup
job: dc_backup_offsite : 2h: dc backup remote offsite run
```
