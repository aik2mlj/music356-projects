//----------------------------------------------------------------------------
// name: faceosc-print.ck
// desc: monitor incoming OSC messages from FaceOSC
//
// get FaceOSC here (and also see the OSC message it sends)
//     https://github.com/kylemcdonald/ofxFaceTracker/releases
//
// author: Ge Wang (https://ccrma.stanford.edu/~ge/)
// date: Winter 2023
//----------------------------------------------------------------------------

// create our OSC receiver
OscIn oin;
// create our OSC message
OscMsg msg;
// use port 6448 (monitor input)
8338 => oin.port;
// listen for all message
oin.listenAll();

// print
cherr <= "listening for messages on port " <= oin.port()
      <= "..." <= IO.newline();
      
// spork the listener
spork ~ incoming();

// main shred time loop
while( true )
{
    // do nothing here
    1::second => now;
}

// listener
fun void incoming()
{
    // infinite event loop
    while( true )
    {
        // wait for event to arrive
        oin => now;
        
        // grab the next message from the queue. 
        while( oin.recv(msg) )
        {         
            // print arbitrary line for easier reading
            if( msg.address == "/found" ) { cherr <= "------" <= IO.newline(); }      
            
            // print message type
            cherr <= "RECEIVED: \"" <= msg.address <= "\": ";
            // print arguments
            printArgs( msg );
        }
    }
}

// print argument
fun void printArgs( OscMsg msg )
{
    // iterate over
    for( int i; i < msg.numArgs(); i++ )
    {
        if( msg.typetag.charAt(i) == 'f' ) // float
        {
            cherr <= msg.getFloat(i) <= " ";
        }
        else if( msg.typetag.charAt(i) == 'i' ) // int
        {
            cherr <= msg.getInt(i) <= " ";
        }
        else if( msg.typetag.charAt(i) == 's' ) // string
        {
            cherr <= msg.getString(i) <= " ";
        }            
    }       
    
    // new line
    cherr <= IO.newline();
}
