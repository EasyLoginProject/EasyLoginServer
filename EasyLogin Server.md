# EasyLogin Server

## Architecture

### CouchDB

- one database per customer
- administrative databases (TBD).

### Server Applications

- EasyLoginServer application: deploy as many instances as needed. Each application connects to the CouchDB service and is able to use the customer's database according to the request URL (subdomain, path prefix) and headers.
- more to come...

### HTTP Server

Apache or nginx as a front server. FCGI connection with applications (currently: HTTP).

## Deployment

Tested on Ubuntu 16.04.

### Build server

#### Required packages

	build-essential
	clang
	erlang
	libcurl4-openssl-dev
	libicu-dev
	libmozjs185-dev
	libssl-dev
	pkg-config

#### CouchDB

- download from [http://mirrors.standaloneinstaller.com/apache/couchdb/source/2.0.0/apache-couchdb-2.0.0.tar.gz]()
- build:

```
./configure
make release
```

- build results are generated in `rel/couchdb`, can be moved somewhere else

Additional information:

- [http://couchdb.apache.org]()
- [http://docs.couchdb.org/en/2.0.0/install/unix.html]()
- [https://groups.google.com/forum/#!topic/couchdb-user-archive/IYvDobB20zs]()

#### Swift Toolchain

- download from [https://swift.org/download/]()
- tar zxf
- add path to usr/bin in extracted archive to $PATH

To build an application:

- `cd (repository)/Server`
- `swift build` (debug build, in .build/debug)
- `swift build -c release` (release build, in .build/release)

### Production server

#### CouchDB

- install `rel/couchdb` directory from build server
- create `couchdb` user, set privileges
- start `couchdb/bin/couchdb` with `couchdb` user (with supervisord?)
- on first use, for single node configuration, initialize cluster:

```
curl -X PUT http://localhost:5984/_users
curl -X PUT http://localhost:5984/_replicator
curl -X PUT http://localhost:5984/_global_changes
```

- otherwise, set up a multinode cluster: [http://127.0.0.01:5984/_utils#setup]()

### Applications

- install applications (located in `(repository)/Server/.build/release/` on build server)

