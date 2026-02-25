//-----------------------------------------------------------------------------
// name: gametrak-6input.ck
// desc: gametrak to Wekinator OSC
//       sends 6 axes of the gametrak tethers
//       (optional but not enabled) send a 7th number for foot button state
//
// author: Ge Wang (ge@ccrma.stanford.edu)
// date: Winter 2023
//-----------------------------------------------------------------------------

// destination host name
"localhost" => string hostname;
// destination port number: 6448 is Wekinator default
6448 => int port;

// z axis deadzone
0 => float DEADZONE;
// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// sender object
OscOut xmit;
// aim the transmitter at destination
xmit.dest( hostname, port );

// HID objects
Hid trak;
HidMsg msg;

// open joystick 0, exit on fail
if( !trak.openJoystick( device ) ) me.exit();

// print
<<< "joystick '" + trak.name() + "' ready", "" >>>;

// data structure for gametrak
class GameTrak
{
    // timestamps
    time lastTime;
    time currTime;
    
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
}

// gametrack
GameTrak gt;

// spork control
spork ~ gametrak();

// main loop
while( true )
{
    // print 6 continuous axes -- XYZ values for left and right
    // <<< "axes:", gt.axis[0],gt.axis[1],gt.axis[2], gt.axis[3],gt.axis[4],gt.axis[5] >>>;

    // send to Wekinator
    sendOSC();

    // advance time
    20::ms => now;
}

// gametrack handling
fun void gametrak()
{
    while( true )
    {
        // wait on HidIn as event
        trak => now;
        
        // messages received
        while( trak.recv( msg ) )
        {
            // joystick axis motion
            if( msg.isAxisMotion() )
            {            
                // check which
                if( msg.which >= 0 && msg.which < 6 )
                {
                    // check if fresh
                    if( now > gt.currTime )
                    {
                        // time stamp
                        gt.currTime => gt.lastTime;
                        // set
                        now => gt.currTime;
                    }
                    // save last
                    gt.axis[msg.which] => gt.lastAxis[msg.which];
                    // the z axes map to [0,1], others map to [-1,1]
                    if( msg.which != 2 && msg.which != 5 )
                    { msg.axisPosition => gt.axis[msg.which]; }
                    else
                    {
                        1 - ((msg.axisPosition + 1) / 2) - DEADZONE => gt.axis[msg.which];
                        if( gt.axis[msg.which] < 0 ) 0 => gt.axis[msg.which];
                    }
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown() )
            {
                <<< "button", msg.which, "down" >>>;
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                <<< "button", msg.which, "up" >>>;
            }
        }
    }
}

// send OSC message
fun void sendOSC()
{
    // start the message...
    xmit.start( "/wek/inputs" );

    // loop over 6 axis
    for( int i; i < gt.axis.size(); i++ )
    {
        // add each for sending
        gt.axis[i] => xmit.add;
    }
    
    // send it
    xmit.send();
}

