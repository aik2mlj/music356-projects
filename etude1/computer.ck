// ----------------------------------------------------------------------------
// Audio part

SinOsc m => SinOsc a => Pan2 pan;
2 => a.sync; // FM synth

0.3 => a.gain;
0.3 => m.gain;
2 => int nChans;
Chorus crs[nChans];
NRev rev[nChans];

// mess up with two-channel chorus and reverberator
200::ms => crs[0].baseDelay;
0.05 => rev[0].mix;
100::ms => crs[1].baseDelay;
0.05 => rev[1].mix;

for (int ch; ch < nChans; ch++) {
    pan.chan(ch) => crs[ch] => rev[ch] => dac.chan(ch);
}

fun void changeFreq() {
    while (true) {
        // random frequency between 200 and 800 Hz
        Math.random2f(200, 600) => a.freq;
        100::ms => now;
    }
}

spork ~changeFreq();

// ----------------------------------------------------------------------------
// Text part
// make a ConsoleInput
ConsoleInput in;
// tokenizer
StringTokenizer tok;
// line
string line[0];

// our default model
Word2Vec model;
300::ms => dur T_WORD; // time per word
8 => int K_NEAREST;

// loading any default here
"lib/glove-wiki-gigaword-50-tsne-2.txt" => string filepath;
// Print a word
chout <= "loading your favorite virtual assistant";
chout.flush(); // distinct from <<< >>>, chout is buffered so you must flush!

for (int i; i < 3; i++) {
    0.5::second => now;
    chout <= "."; // print a dot
    chout.flush();
}
// load model
if (!model.load(me.dir() + filepath)) {
    error();
    me.exit();
}
chout <= "success!" <= IO.newline();
chout.flush();

<<< "how can I help you today? (type !q to quit)", "" >>>;

// loop
while (true) {
    // prompt
    in.prompt("\n> ") => now;

    // read
    while (in.more()) {
        // get it
        tok.set(in.getLine());
        // clear array
        line.clear();
        // print tokens
        while (tok.more()) {
            // put into array
            line << tok.next().lower();
            // print it
            // <<< line[line.size()-1], "" >>>;
        }
        // if non-empty
        if (line.size()) {
            // execute
            execute(line) => int result;
        }
    }
}


fun int execute(string line[]) {
    line[0] => string command;
    string results[K_NEAREST];


    // which command
    if (command == "!q") {
        // exit shred
        me.exit();
    } else {
        // with a chance of 30%, just echo back the input
        if (Math.random2(0, 100) < 30) {
            chout <= "I agree that ";
            m.freq() => float oldFreq;
            Math.random2f(300, 50000) => m.freq;
            for (int i; i < line.size(); i++) {
                chout <= line[i] <= " ";
            }
            endl(500::ms);
            oldFreq => m.freq;
            return 0;
        }
        // with a chance of 20%, say something completely unrelated
        if (Math.random2(0, 100) < 20) {
            // get a random word from the model
            model.getSimilar([ Math.random2f(-3, 3), Math.random2f(-3, 3) ], results.size(),
                             results);
            1::second => now; // like a fake "thinking" pause
            1000 => m.gain;
            chout <= "Did you know that ";
            for (int i; i < Math.random2(2, 8); i++) {
                chout <= results[i] <= " ";
            }
            endl(500::ms);
            0.3 => m.gain;
            return 0;
        }
        // with a another 20%, just say "I see"
        if (Math.random2(0, 100) < 20) {
            chout <= "I see";
            endl(500::ms);
            return 0;
        }
        // change the input into a weird poem
        1000 => m.gain;
        for (int i; i < line.size(); i++) {
            // get similar words
            model.getSimilar(line[i], results.size(), results);
            // pick one at random
            results[Math.random2(0, results.size() - 1)] => line[i];
            chout <= line[i] <= " ";
            chout.flush();
            wait();
        }
        0.3 => m.gain;
        chout <= IO.newline();
    }
    return 0;
}

fun void wait() { T_WORD => now; }

fun void clearLine() {
    // Move cursor to beginning of line
    chout <= "\r";
    chout.flush();
    // Overwrite with spaces
    for (int i; i < 80; i++) {
        chout <= " ";
    }
    chout.flush();
    // Move cursor back to beginning
    chout <= "\r";
    chout.flush();
}

// new line with timing
fun void endl(dur T) {
    // new line
    chout <= IO.newline();
    chout.flush();
    // let time pass
    T => now;
}

fun void error() { <<< "ERROR!!! ERROR!!! ERROR!!!", "" >>>; }
