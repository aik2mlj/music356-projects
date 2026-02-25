int elementInfo[0][2];
[0, 3] @=> elementInfo["/acc"];
[3, 2] @=> elementInfo["/drlref"];
[5, 6] @=> elementInfo["/eeg"];
[11, 3] @=> elementInfo["/ppg"];
float data[14];

// OSC
OscIn oin;
5000 => oin.port;
oin.listenAll();
OscOut xmit;
xmit.dest( "localhost", 6448 );
OscMsg msg;

// auxiliary
int start, i;

// infinite time loop
while(true)
{
    // wait for OSC input
    oin => now;
    // drain the message queue
    while( oin.recv(msg) )
    {
        if( msg.address == "/acc" || msg.address == "/drlref"
        || msg.address == "/eeg" || msg.address == "/ppg" )
        {
            elementInfo[msg.address][0] => start;
            for (0 => i; i < elementInfo[msg.address][1]; i++)
            {
                msg.getFloat(i) => data[start + i];
            }
        }
    }
    
    // start the message...
    xmit.start( "/wek/inputs" ); 
    for (0 => int i; i < 9; i++)
    {
        data[i] => xmit.add;
        cherr <= data[i] + " ";
    }
    cherr <= IO.newline();
    // send it
    xmit.send();
}
