# Assemblage

A continuous integration toolkit.

home
: https://assembla.ge/

code
: https://bitbucket.org/sascrotch/assemblage

github
: https://github.com/ged/assemblage

docs
: http://assembla.ge/docs/assemblage


## Description

Assemblage is a continuous integration toolkit. It's intended to provide you
with a minimal infrastructure for distributing and performing automated tasks
for one or more version control repositories. It makes as few assumptions as
possible as to what those things might be.

It's still just a personal project, but if you want to use it I'm happy to
answer questions and entertain suggestions, especially in the form of
patches/PRs.

Assemblage has three primary parts: the **Assembly Server**, **Assembly
Workers**, and **Repositories**.

<dl>
  <dt>Assembly Server</dt>
  <dd>Aggregates and distributes events from <em>repositories</em> to
  <em>workers</em> via one or more "assemblies".</dd>

  <dt>Assembly Workers</dt>
  <dd>Listens for events published by the <em>assembly server</em>, checks out
  a <em>repository</em>, and runs an assembly script in that repository.</dd>

  <dt>Repository</dt>
  <dd>A distributed version control repository. Assemblage currently supports
  Mercurial and Git.</dd>
</dl>



## Prerequisites

* Ruby
* libzmq >= 4.2.3 (with drafts enabled)
* czmq >= 4.1.0 (with drafts enabled)
* A DVCS; Assemblage currently supports Mercurial and Git.


## Installation

This example uses three different servers for the three parts, but you can, of
course, run all of this on a single host.

You'll first need a server to manage your assemblies:

    example $ sudo gem install assemblage
    example $ assemblage create-server /usr/local/assemblage
    Creating a server run directory in /usr/local/assemblage...
    Generating a server key...
    Creating the assemblies database...
    done.

    You can start the assembly server like so:
      assemblage start-server /usr/local/assemblage
    
    Server public key is:
      &}T0.[{MZSJC]roN-{]x2QCkG+dXki!6j!.1JU1u

    example $ assemblage start-server /usr/local/assemblage
    Starting assembly server at:
      tcp://example.com:7872

Now (possibly on a different host) you can create a new worker installation.
Workers have a name and a list of tags that describe its capabilities, e.g.,
the OS it's running on, installed software, etc. Our example is running on
FreeBSD 11, and has Ruby 2.4, Ruby 2.5, Python 2.7, ZeroMQ, and the PostgreSQL
client libraries available. We'll use a pretty simple tag convention but you
can make it as simple or complex as you want.

    user@example-client $ sudo gem install assemblage
    user@example-client $ mkdir -p /usr/local/assemblage
    user@example-client $ cd /usr/local/assemblage
    user@example-client $ assemblage create-worker \
      -t freebsd,freebsd11,ruby,ruby24,ruby25,python,\
      python27,zeromq,libpq worker1
    Creating a new assembly worker run directory in
      /usr/local/assemblage/worker1...
    Set up with worker name: example-client-worker1
    done.

Tell it that it should talk to the new server we just set up:

    user@example-client $ cd /usr/local/assemblage/worker1
    user@example-client $ assemblage add-server \
      --key="&}T0.[{MZSJC]roN-{]x2QCkG+dXki!6j!.1JU1u" \
      tcp://example.com:7872
    Talking to tcp://example.com:7872...
    Registering client `example-client-worker1`...
    Requesting a client key...
    done.

This will register the client with the server, but it needs to be approved
on the server before it can start working:

    user@example $ assemblage approve-worker example-client-worker1
    Looking for worker registration... found.
    Approving connections from example-client-worker1...
    done.

Now you can start the worker, which will listen for jobs it can work on.

    user@example-client $ cd /usr/local/assemblage/worker1
    user@example-client $ assemblage start-worker
    Starting assembly worker `worker1`...
    Connecting to assembly servers...
       example... done.
    Waiting for jobs...

Now we need our repositories to notify the assembly server when events occur.
We'll hook up a Mercurial repo for a Ruby library so that it runs unit tests
whenever there's a new commit. First we'll install assemblage on the repo
server and add the server we're going to send events to:

    user@example-repo $ sudo gem install assemblage
    user@example-repo $ cd /usr/local/hg/repos/project1
    user@example-repo $ hg init
    user@example-repo $ assemblage add-repo \
      --type=hg \
      --key="&}T0.[{MZSJC]roN-{]x2QCkG+dXki!6j!.1JU1u" \
      http://repo.example.com/project1 tcp://example.com:7872 
    Talking to tcp://example.com:7872...
    Registering repo `http://repo.example.com/project1`...
    Requesting a repo key...
    done.

We'll add a hook to the repository's .hg/hgrc that looks like:

    [hooks]
    incoming.assemblage = /usr/local/bin/assemblage send-event commit \
      project1 $HG_NODE

We'll need to approve the repo registration now too:

    user@example $ assemblage approve-repo http://repo.example.com/project1
    Looking for repo registration... found.
    Approving repo events from http://repo.example.com/project1...
    done.

And finally, we'll combine all the parts into an assembly called
`project1-freebsd-tests` that will run on a worker with the `freebsd`, `ruby`,
and `libpq` tags for each commit to the repo at
`http://repo.example.com/project1`:

    user@example $ assemblage add -t freebsd,ruby,libpq \
      http://repo.example.com/project1

Now when commits arrive at our repo, it will send events to the assemblage server, which will queue up an assembly. Because the worker we added has all of the required tags, it will:

- get a notification of the commit
- clone the repository checked out to that commit
- look for an assembly script called `commit` in a directory called `.assemblies/` (by default)
- if it finds one, it will run the script
- it will then send back any files contained in the `.assemblies/` subdirectory with the SHA of the commit (if it exists) along with the exit code of the script.



## Contributing

You can check out the current development source with Mercurial via
[Bitbucket](http://bitbucket.org/sascrotch/assemblage). Or if you prefer Git,
via [its Github mirror](https://github.com/ged/assemblage).

After checking out the source, run:

    $ rake newb

This task will install any missing dependencies, run the tests/specs,
and generate the API documentation.


## License

Copyright (c) 2018, Michael Granger
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the author/s, nor the names of the project's
  contributors may be used to endorse or promote products derived from this
  software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


