# Maven Unit Test in limited environment

The goal is to run maven unit test within a limited environment to
reproduce random problem that happens only on overloaded slave.

The limitation to reproduce:
- memory
- CPU
- Disk IO


Using a docker makes things straithforward to handle CPU and memory
limitation, using volume for existing source and m2 repository.

For the slow disk io there are multiple solutions:
- use the default docker overlay2 fs is already interresting
- use a volume that point to an old USB key or a USB HDD
- use a volume that point to a nbd (block device over network) see below

So we define 3 volumes:
- the source: `/volume/git`
- the m2 repository: `/root/.m2`
- a slow disk: `/volume/slow`


## Requierement

You need Docker with cgroup support, if `docker info` returns:

```
WARNING: No swap limit support
```

This is not the case, check [how to enable cgroups](https://docs.docker.com/install/linux/linux-postinstall/#your-kernel-does-not-support-cgroup-swap-limit-capabilities).

## Build docker image

From this directory just run:

```
docker build -t unit-test-limited .
```

## Run

To an env with 1 CPU and 2g of ram on a slow disk:

```
docker run -it -v /home/$USER/dev/nuxeo.git:/volume/git \
               -v /home/$USER/.m2:/root/.m2 \
			   -v /media/$USER/MY-SLOW-USB-1-KEY:/volume/slow \
			   --memory=2g --memory-swap=2g \
			   --cpus=1 \
			   unit-test-limited
root@87be2a3c64f8:/volume/git#
```

To run maven with java tmp on slow disk:

```
cd nuxeo-runtime/nuxeo-stream/
root@87be2a3c64f8:/volume/git/nuxeo-runtime/nuxeo-stream# mvn -Djava.io.tmpdir=/volume/slow/tmp clean install
```

To have the test case also running on slow disk you need to edit the
`pom.xml` and add a profile:

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

Then
```
root@87be2a3c64f8:/volume/git/nuxeo-runtime/nuxeo-stream# mvn -Djava.io.tmpdir=/volume/slow/tmp -Pslowdisk clean install
```

Note when you want to go back to your normal env you may need to fix
some permissions, because has created some new stuff in target or m2
repository as root

```
chown $USER.USER -R /home/$USER/dev/nuxeo.git /home/$USER/.m2
```

## NBD (Network Block Device) for slow disk simulation

Here an example on how to setup a very slow hard drive using [xnbd](https://bitbucket.org/hirofuchi/xnbd/wiki/Home)


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
download bandwith of xnbd-server to limit read and write rate, but it
is a bit unstable your mileage may vary.

It might worth to create a docker for this ...


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
