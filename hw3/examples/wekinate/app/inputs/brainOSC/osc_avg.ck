int elementLength[0];
3 => elementLength["/acc"];
2 => elementLength["/drlref"];
6 => elementLength["/eeg"];
3 => elementLength["/ppg"];
int elementStart[0];
0 => elementStart["/acc"];
3 => elementStart["/drlref"];
5 => elementStart["/eeg"];
11 => elementStart["/ppg"];
int elementCount[0];
0 => elementCount["/acc"];
0 => elementCount["/drlref"];
0 => elementCount["/eeg"];
0 => elementCount["/ppg"];
int elementIndex[0];
0 => elementIndex["/acc"];
1 => elementIndex["/drlref"];
2 => elementIndex["/eeg"];
3 => elementIndex["/ppg"];
float elements[14];
int check[4];

// OSC
OscIn oin;
5000 => oin.port;
OscOut xmit;
xmit.dest( "localhost", 6448 );
// listen to everything coming
oin.listenAll();

// something to shuttle data
OscMsg msg;

// auxiliary
"null" => string lastMsgAddress;
int checkSum;
int currStart;

// infinite time loop
while(true)
{
    // wait for OSC input
    oin => now;
    // drain the message queue
    while( oin.recv(msg) )
    {
        if (msg.address != lastMsgAddress)
        {
            for (elementStart[lastMsgAddress] => int i; i < elementStart[lastMsgAddress] + elementLength[lastMsgAddress]; i++)
            {
                elementCount[lastMsgAddress] /=> elements[i];
            }
            0 => elementCount[lastMsgAddress];
            1 => check[elementIndex[lastMsgAddress]];
            0 => checkSum;
            for (0 => int i; i < 4; i++)
            {
                check[i] +=> checkSum;
            }
            if (checkSum == 4)
            {
                // start the message...
                xmit.start( "/wek/inputs" );

                for (0 => int i; i < 14; i++)
                {
                    elements[i] => xmit.add;
                    chout <= elements[i] + " ";
                }
                chout <= IO.newline();

                // send it
                xmit.send();

                for (0 => int i; i < 4; i++)
                {
                    0 => check[i];
                }
            }
        }
        elementStart[msg.address] => currStart;
        for (0 => int i; i < elementLength[msg.address]; i++)
        {
            msg.getFloat(i) => elements[currStart+i];
        }
        1 +=> elementCount[msg.address];
        msg.address => lastMsgAddress;
    }
}
