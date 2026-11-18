# Encrypted backup disk on a remote node (`dc backup remote`)

How to prepare a LUKS encrypted disk on a remote node, which
`dc backup remote <name> run` opens before the copy and closes afterwards.
The passphrase stays on the backup host (`~/dc/config/backup-remote-<name>.key`),
so the data on the remote node cannot be read without it.

All commands are short single lines, run them one by one.
The values are set once as shell variables at the start of each section;
they only exist in that shell, so the block is repeated on the backup host.

| variable | example        | meaning                                            |
|----------|----------------|----------------------------------------------------|
| `R`      | `node3`        | remote node (dc node, `node.yml`)                  |
| `N`      | `offsite`      | name: LVM volume, LUKS mapper and remote copy      |
| `DISK`   | `/dev/sdb`     | empty disk on the remote node                      |
| `PART`   | `/dev/sdb1`    | the partition created on it                        |
| `VG`     | `vg0`          | LVM volume group                                   |
| `SIZE`   | `1000G`        | size of the volume                                 |
| `MNT`    | `/cust/backup` | mount point on the remote node = `dir:` in backup.yml |

## 1. On the remote node: disk, LVM, LUKS

This section prepares a new, empty disk. If the remote node already has
a volume group with free space (e.g. a second backup host or dc cluster
copies to the same remote disk), use section 1a instead.

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

Set the values (adapt them, `DISK` from the list above,
`PART` is its first partition, e.g. `/dev/nvme0n1p1` for `/dev/nvme0n1`):

```bash
N=offsite
DISK=/dev/sdb
PART=/dev/sdb1
VG=vg0
SIZE=1000G
MNT=/cust/backup
```

Partition and LVM (`lsblk $DISK` must show `$PART` before `pvcreate`;
more volumes for other purposes can be added to `$VG`):

```bash
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary 0% 100%
lsblk $DISK
pvcreate $PART
vgcreate $VG $PART
lvcreate -L $SIZE -n $N $VG
```

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

## 1a. Alternative: another volume in an existing volume group

One encrypted volume per backup host (dc cluster), each with its own
passphrase, on the same disk of the remote node. Here the new volume
is called `new` in the existing volume group `vg0`.

Size: on the backup host, the size of one complete copy (`latest`,
without the date snapshots). Take about 1.5 times this value, so the
remote snapshots have room for the changes:

```bash
du -sh --exclude='20??-??-??*' /backup
```

On the remote node, show the volume groups. The column `VG` is the name
for `VG` below, `VFree` the free space. (`lsblk` shows the existing
volumes as `<VG>-<LV>`, e.g. `vg0-offsite`.)

```bash
ssh node3
vgs
```

Set the values (`VG` from `vgs`, `SIZE` below `VFree`):

```bash
N=new
VG=vg0
SIZE=300G
MNT=/cust/new
```

Volume and LUKS (asks for `YES` and the passphrase twice):

```bash
lvcreate -L $SIZE -n $N $VG
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

Header backup (fetched in section 2):

```bash
H=/root/$N.luks-header
cryptsetup luksHeaderBackup /dev/$VG/$N --header-backup-file $H
exit
```

Then continue with section 2 on the backup host of this cluster, with
`N=new`, `VG=vg0` and `MNT=/cust/new`.

## 2. On the backup host: header, keyfile, backup.yml

The remote node must be a dc node on this backup host (reached via ssh
with the cluster key). Check it:

```bash
dc node node3 state
```

It must print `sshd` (or `dock`, `dc`, `dcc`). If not, define the node
and copy the cluster key to it once (needs one working login to it):

```bash
dc node node3 config create <hostname_or_ip> sshd
ssh-copy-id -i ~/dc/nodes/id_ed25519.pub root@<hostname_or_ip>
dc node node3 state
```

Set the values again (same as on the remote node). `PLAN` is the
rotation plan on the remote node, usually longer than the local one;
leave it empty (`PLAN=`) to use `backup.plan`:

```bash
R=node3
N=offsite
VG=vg0
MNT=/cust/backup
PLAN=0,1,2,3,4,5,6,7,14,21,28,35,42,50,100,200,400
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

Append the entry to `~/dc/config/backup.yml` (with the values filled
in). `remote:` must be the last section below `backup:`, as in the
template, because the entry is appended at the end of the file;
`remote:` itself is only added if it is not there yet:

```bash
F=~/dc/config/backup.yml
cp -a $F $F.bak
grep -q '^  remote:' $F || echo '  remote:' >> $F
cat <<EOF >> $F
    $N:
      node: $R
      dir: $MNT
      plan: $PLAN
      crypt:
        device: /dev/$VG/$N
        name: $N
EOF
tail -12 $F
dc backup remote
```

`EOF` must stand at the beginning of its line (no blanks before it).
`dc backup remote` lists the remote copies, `$N` must be among them.
If not, `remote:` was not the last section: restore `$F.bak`
(`mv $F.bak $F`) and add the entry by hand.

With the example values the end of the file looks like this:

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

Further optional keys: `nodes:` (only some nodes) and `extra:`
(additional local directories), see README: *Remote copy*.

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
