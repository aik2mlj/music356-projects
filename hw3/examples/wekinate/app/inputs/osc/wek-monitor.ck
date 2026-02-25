//----------------------------------------------------------------------------
// name: wek-monitor.ck
// desc: monitor input OSC on wekinator's input port
//       (for observation/OSC debug only)
//
//       NOTE: don't run this at the same time as Wekinator to avoid port
//       conflict; this program is for observing/debugging your OSC sender);
//       NOTE: if you run this in miniAudicle, the port may still be tied up
//       until you quit miniAudicle!
//----------------------------------------------------------------------------

// create our OSC receiver
OscIn oin;
// create our OSC message
OscMsg msg;
// use port 6448 (monitor input)
6448 => oin.port;

// create an address in the receiver, expect an int and a float
oin.addAddress( "/wek/inputs" );
// print
cherr <= "listening for \"/wek/inputs\" messages on port " <= oin.port()
      <= "..." <= IO.newline();

// infinite event loop
while( true )
{
    // wait for event to arrive
    oin => now;
    
    // grab the next message from the queue. 
    while( oin.recv(msg) )
    {         
        // print stuff
        cherr <= "received OSC message: \"" <= msg.address <= "\" "
              <= "typetag: \"" <= msg.typetag <= "\" "
              <= "arguments: " <= msg.numArgs() <= IO.newline();
        
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
        // done with line
        cherr <= IO.newline();
    }
}
