//----------------------------------------------------------------------------
// name: wek-send.ck
// desc: OpenSoundControl (OSC) sender example for Wekinator
//----------------------------------------------------------------------------

// destination host name
"localhost" => string hostname;
// destination port number; 6448 is Wekinator default input port
6448 => int port;

// check command line
if( me.args() ) me.arg(0) => hostname;
if( me.args() > 1 ) me.arg(1) => Std.atoi => port;

// sender object
OscOut xmit;

// aim the transmitter at destination
xmit.dest( hostname, port );

// infinite time loop
while( true )
{
    // start the message...
    xmit.start( "/wek/inputs" );

    // add float argument
    Math.random2f( 0, 1 ) => xmit.add;
    // add float argument
    Math.random2f( 0, 1 ) => xmit.add;
    // add float argument
    Math.random2f( 0, 1 ) => xmit.add;
    
    // send it
    xmit.send();

    // advance time
    20::ms => now;
}
