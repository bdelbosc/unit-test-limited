# Maven Unit Test in limited environment

The goal is to run maven unit test within a limited environment to
reproduce random problem that happens only on overloaded slave.

The proposed limitation apply to:
- memory
- CPU
- Disk IO

Using docker makes things straightforward to handle CPU and memory
limitations and also to use existing source and m2 repository.

For the slow Disk IO, there are multiple solutions:
- use the default docker overlay2 fs can be interesting
- use an old USB stick or HDD, USB 1.1 is ~1.1MB/s, USB 2 ~30MB/s
- use a NFS volume
- use a NBD volume (block device over network) see below

The docker image provides an Open JDK 1.8.0_171 with Maven 3.5.4 ready to
run unit test using your local m2 repository, for this it defines 3 volumes:
- the source: `/volume/git`
- the m2 repository: `/root/.m2`
- a slow disk: `/volume/slow`


## Requirement

You need Docker with cgroup support, if `docker info` returns:

```
WARNING: No swap limit support
```

This is not good, check [how to enable cgroups](https://docs.docker.com/install/linux/linux-postinstall/#your-kernel-does-not-support-cgroup-swap-limit-capabilities).

## Build docker image

From this directory just run:

```
docker build -t unit-test-limited .
```

## Run

To run an env with half of a CPU and 2g of ram on a slow disk:

```
docker run -it -v /home/$USER/dev/nuxeo.git:/volume/git \
               -v /home/$USER/.m2:/root/.m2 \
               -v /media/$USER/MY-SLOW-USB-1-KEY:/volume/slow \
               --memory=2g --memory-swap=2g \
               --cpus="0.5" \
               -u $UID \
               unit-test-limited

root@87be2a3c64f8:/volume/git#
```

To run unit test with Java temporary directory on a slow disk:

```
cd nuxeo-runtime/nuxeo-stream/
root@87be2a3c64f8:/volume/git/nuxeo-runtime/nuxeo-stream# mvn -Djava.io.tmpdir=/volume/slow/tmp clean test
```

To run unit test with the `target` directory on a slow disk you need
to edit the `pom.xml` and add a profile:

```
  <profiles>
    <profile>
      <id>slowdisk</id>
      <build>
        <directory>/volume/slow/target</directory>
      </build>
    </profile>
  </profiles>
```

Then:
```
root@87be2a3c64f8:/volume/git/nuxeo-runtime/nuxeo-stream# mvn -Djava.io.tmpdir=/volume/slow/tmp -Pslowdisk clean test
```

Note when you want to go back to your normal env you may need to fix
some permissions because docker has created some new stuff in `target`
or `~/.m2` repository as root user:

```
chown $USER.USER -R /home/$USER/dev/nuxeo.git /home/$USER/.m2
```

## Simulating slow disk

### NBD (Network Block Device) for slow disk simulation

Here an example on how to simulate a slow hard drive using
[xnbd](https://bitbucket.org/hirofuchi/xnbd/wiki/Home)


```
apt-get install xnbd-server xnbd-client trickle

# create an image file of 10g
dd if=/dev/zero of=/tmp/slow.img bs=1024 count=10000000
mke2fs /tmp/slow.img
chmod 666 /tmp/slow.img

# make sure ndb mod is loaded
modprobe nbd

# run the nbd server on port 9999
xnbd-server --target --lport 9999 /tmp/slow.img

# run a nbd client on another term or host
xnbd-client --connect /dev/nbd0 localhost 9999

# mount the nbd
mkdir -p /mnt/slow
mount -o sync /dev/nbd0 /mnt/slow/
```

After this you can use `/mnt/slow` as volume for `/volume/slow`.

Note that it is also possible to use `trickle` to limit the upload and
download bandwith of `xnbd-server` to limit read and write rate:

```
# limit rate to 2MB:
trickle -d2000 -u2000 xnbd-server --target --lport 9999 /tmp/slow.img
```

But it is a bit unstable, your mileage may vary.

Also it might worth to create a docker for this ...

### NFS

Try to use a docker compose that setup an NFS server and add an extra delay using tc, like:

```
tc qdisc add dev eth0 root netem delay 4ms 1ms
```

# About Nuxeo

Nuxeo provides a modular, extensible Java-based
[open source software platform for enterprise content management](http://www.nuxeo.com/en/products/ep)
and packaged applications for
[document management](http://www.nuxeo.com/en/products/document-management),
[digital asset management](http://www.nuxeo.com/en/products/dam) and
[case management](http://www.nuxeo.com/en/products/case-management). Designed
by developers for developers, the Nuxeo platform offers a modern
architecture, a powerful plug-in model and extensive packaging
capabilities for building content applications.

More information on: <http://www.nuxeo.com/>
