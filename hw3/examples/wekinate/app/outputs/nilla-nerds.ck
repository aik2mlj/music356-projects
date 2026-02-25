//----------------------------------------------------------------------------
/*  1-parameter output for nillawafers vs gummynerds classifier
    wekinator mod by Rebecca Fiebrink (2009-2015)
    updated by Ge Wang (2023)

    USAGE: This example receives Wekinator "/wek/outputs/" messages
    over OSC and maps incoming parameters to musical parameters;
    This example is designed to run with a sender, which can be:
    1) the Wekinator application, OR
    2) another Chuck/ChAI program containing a Wekinator object

    This example expects to receive one of 3 labels;
    these parameters are mapped to musical parameters
    in map2sound().

    for example:
    class 1: no nilla no nerds
    class 2: yes nilla no nerds
    class 3: no nilla yes nerds
    */
//----------------------------------------------------------------------------

// create our OSC receiver
OscIn oscin;
// a thing to retrieve message contents
OscMsg msg;
// use port 12000 (default Wekinator output port)
12000 => oscin.port;

// listen for "/wek/output" message with 5 floats coming in
oscin.addAddress("/wek/outputs, f");
// print
<<< "listening for OSC message from Wekinator on port 12000...", "" >>>;
<<< " |- expecting \"/wek/outputs\" with 1 discrete parameters...", "" >>>;

// set the latest parameters as targets
// NOTE: we rely on map2sound() to actually interpret these parameters musically
fun void waitForEvent() {
    int param;
    // infinite event loop
    while (true) {
        // wait for OSC message to arrive
        oscin => now;

        // grab the next message from the queue.
        while (oscin.recv(msg)) {
            // get output from wekinator as int
            (msg.getFloat(0) + .5) $ int => param;

            // print
            if (param == 1)
                <<< "got nothing...", "" >>>;
            else if (param == 2)
                <<< "NILLA WAFER!", "" >>>;
            else
                <<< "GUMMY NERDS!", "" >>>;
        }
    }
}

// spork osc receiver loop
spork ~ waitForEvent();

// time loop to keep everything going
while (true)
    1::second => now;
