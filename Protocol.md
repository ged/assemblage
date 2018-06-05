# Assemblage Network Protocol

The communication between the Assembly server, workers, and repositories is conducted via [ZeroMQ][zeromq] [CLIENT/SERVER][zmq-clientserver] sockets with [Zauth][zauth] CURVE authentication, and uses [MessagePacked](https://msgpack.org/index.html) single-part messages.




## Application Protocol

Each message is a MessagePacked Array of two elements: a header and a payload.

### Headers

The header is a Map which includes the following key-value pairs at a minimum:

`version`
: The protocol version. As of this writing, the only version is `1`.

`action`
: A string that describes what action should be taken by the receiver.




[zeromq]: http://zeromq.org/
[zmq-clientserver]: http://api.zeromq.org/4-2:zmq-socket#toc3
[zauth]: http://czmq.zeromq.org/manual:zauth


