// window for detection
2 => float WINDOW_MIN;
5 => float WINDOW_MAX;
0.7 => float THRESHOLD;
0.7 => float SMILE_THRESHOLD;

// create our OSC receiver
OscIn oscin;
// a thing to retrieve message contents
OscMsg msg;
// use port 12000 (default Wekinator output port)
12000 => oscin.port;

oscin.addAddress("/wek/outputs, f");
// print
<<< "listening for OSC message from Wekinator on port 12000...", "" >>>;
<<< " |- expecting \"/wek/outputs\" with 1 discrete parameters...", "" >>>;

// current detected mode
0 => int mode;
0 => int lastMode;

// set the latest parameters as targets
// NOTE: we rely on map2sound() to actually interpret these parameters musically
fun void waitForEvent() {
    int param;
    0 => int totalSamples;
    0 => int smileSamples;
    now => time start;
    // infinite event loop
    while (true) {
        // wait for OSC message to arrive
        oscin => now;

        // grab the next message from the queue.
        while (oscin.recv(msg)) {
            // get output from wekinator as int
            (msg.getFloat(0) + .5) $ int => param;

            totalSamples++;
            // print
            if (param == 1) {
                // <<< "No smile detected!" >>>;
            } else {
                // <<< "Smile detected!" >>>;
                smileSamples++;
            }
        }

        if ((now - start) / 1::second >= Math.random2f(WINDOW_MIN, WINDOW_MAX)) {
            // reset after window
            now => start;
            (smileSamples $ float) / (totalSamples $ float) => float smilePrecentage;
            <<< "Smile percentage: ", smilePrecentage >>>;
            0 => totalSamples;
            0 => smileSamples;

            if (smilePrecentage < SMILE_THRESHOLD) {
                // too little smile within this time window, play a random hint audio file
                // spork ~ playSmile();
            } else {
                spork ~ playWave();
            }
        }
    }
}

// clang-format off
[
"Hey!",
"Hi there.",
"Oh, hey!",
"What’s up?",
"Yo!",
"Hey, how’s it going?",
"Hi!",
"Hey, good to see you.",
"Oh hey, didn’t see you there.",
"Hey! How’ve you been?",
] @=> string messages[];
// clang-format on

"notify-send -t 10000 -i folder-android-symbolic -a 'Computer' 'Your computer says' " => string command;

fun string wrap(string message) { return "'" + message + "'"; }

fun void playWave() { Std.system(command + wrap(messages[Math.random2(0, messages.size() - 1)])); }

// spork osc receiver loop
spork ~ waitForEvent();

// time loop to keep everything going
while (true)
    1::second => now;
