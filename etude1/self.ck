5::ms => dur INTSTEP;

VoicForm voice => Gain gain => Pan2 pan;

2 => int nChans;
Chorus crs[nChans];
NRev rev[nChans];

// mess up with two-channel chorus and reverberator
200::ms => crs[0].baseDelay;
0.05 => rev[0].mix;
100::ms => crs[1].baseDelay;
0.05 => rev[1].mix;

for (0 => int ch; ch < nChans; ch++) {
    pan.chan(ch) => crs[ch] => rev[ch] => dac.chan(ch);
}

// generic easing function (cubic ease-in-out)
fun float ease(float progress) {
    if (progress < 0.5) {
        return 2 * Math.pow(progress, 3);
    } else {
        return 1 - Math.pow(-2 * progress + 2, 3) / 2;
    }
}


fun void smoothPhoneme(float start, float target, dur duration) {
    now => time begin;

    while (now < begin + duration) {
        // calculate progress (0.0 to 1.0)
        (now - begin) / duration => float progress;
        // apply easing
        ease(progress) => progress;
        // interpolation with eased progress
        start + (target - start) *progress => float newValue;

        newValue $ int => voice.phonemeNum;

        INTSTEP => now;
    }
    target $ int => voice.phonemeNum;
}

fun void smoothVoiced(float start, float target, dur duration) {
    now => time begin;

    while (now < begin + duration) {
        // calculate progress (0.0 to 1.0)
        (now - begin) / duration => float progress;
        // apply easing
        ease(progress) => progress;
        // interpolation with eased progress
        start + (target - start) *progress => float newValue;

        newValue => voice.voiced;

        INTSTEP => now;
    }
    target => voice.voiced;
}

fun void smoothFreq(float start, float target, dur duration) {
    now => time begin;

    while (now < begin + duration) {
        // calculate progress (0.0 to 1.0)
        (now - begin) / duration => float progress;
        // apply easing
        ease(progress) => progress;
        // interpolation with eased progress
        start + (target - start) *progress => float newValue;

        newValue => voice.freq;

        INTSTEP => now;
    }
    target => voice.freq;
}

fun void changePhoneme() {
    now => time start;
    voice.phonemeNum() => float lastPhoneme;
    voice.voiced() => float lastVoiced;
    while (true) {

        // random transition time
        Math.random2(300, 700)::ms => dur transitionTime;
        // random next target
        Math.random2(0, 128) => float target;
        smoothPhoneme(lastPhoneme, target, transitionTime);
        target => lastPhoneme;
        // (Math.sin(t) + 1.) / 2. => voice.voiced;
        // (Math.cos(t * 5.) + 1.) * 10. / 2. => voice.unVoiced;
    }
}

fun void changeVoiced() {
    now => time start;
    voice.voiced() => float lastVoiced;
    while (true) {
        // random transition time
        Math.random2(40, 70)::ms => dur transitionTime;
        // random next target
        Math.random2f(0, 1) => float target;
        smoothVoiced(lastVoiced, target, transitionTime);
        target => lastVoiced;
    }
}

fun void changeFreq() {
    now => time start;
    voice.freq() => float lastFreq;
    while (true) {
        // random transition time
        Math.random2(100, 500)::ms => dur transitionTime;
        // random next target
        Math.random2f(100, 400) => float target;
        smoothFreq(lastFreq, target, transitionTime);
        target => lastFreq;
    }
}

fun void changePan() {
    // use a sine wave to smoothly pan left and right
    while (true) {
        Math.sin(now / 2::second) => pan.pan;
        INTSTEP => now;
    }
}

spork ~changeVoiced();
spork ~changeFreq();
spork ~changePhoneme();
spork ~changePan();

// ----------------------------------------------------------------------------

// instantiate
Word2Vec model;
// pre-trained model to load
me.dir() + "glove-wiki-gigaword-50-tsne-2.txt" => string filepath;
// load pre-trained model (see URLs above for download)
if (!model.load(filepath)) {
    <<< "cannot load model:", filepath >>>;
    me.exit();
}

[
    "identity", "pride", "ego", "importance", "vanity", "arrogance", "insecurity", "narcissism",
    "hatred", "anger"
] @=> string egoWords[];

[
    "confident", "uncertain", "ambitious", "curious", "capable", "resilient", "reflective",
    "anxious", "independent", "determined"
] @=> string feelingWords[];

[
    "wonder", "hesitate", "doubt", "question", "struggle", "reflect", "decide", "seek", "resist",
    "accept"
] @=> string verbs[];

// conditions
3 => int LINES_PER_STANZA;
3 => int NUM_SECTIONS; // here each section is a fixed stanzas format

// number of nearest feelingSearch to retrieve for each word
// higher this number the higher the variance per word
8 => int K_NEAREST;

// timing
400::ms => dur T_WORD;                   // duration per word
false => int shouldScaleTimeToWordLength; // longer feelingSearch take longer?
T_WORD => dur T_LINE_PAUSE;               // a little pause after each line
T_WORD * 2 => dur T_STANZA_PAUSE;         // pause after each stanza

// current word
string feeling;
string ego;
string verb;
// word vector
float vec[model.dim()];
// search results
string feelingSearch[K_NEAREST];
string egoSearch[K_NEAREST];
string verbSearch[K_NEAREST];

// line break
chout <= IO.newline();
chout.flush();

// loop over stanzas
for (int s; s < NUM_SECTIONS; s++) {
    // grab a word out of the "good" bag
    feelingWords[Math.random2(0, feelingWords.size() - 1)] => feeling;
    // grab a word out of the "bad" bag
    egoWords[Math.random2(0, egoWords.size() - 1)] => ego;
    // grab a word out of the "other" bag
    verbs[Math.random2(0, verbs.size() - 1)] => verb;
    // print a stanza
    stanza(feeling, ego, verb, LINES_PER_STANZA);
    endStanza();
    chout <= IO.newline() <= IO.newline();
    chout.flush();
    // pause at end of line
    T_STANZA_PAUSE => now;
}

// print at the end
chout <= "\"Self\"" <= IO.newline();
chout <= "-- a poem about self-ego" <= IO.newline();
chout.flush();

// print a stanza from a starter feeling word
fun void stanza(string feeling, string ego, string verb, int numLines) {
    // loop over lines in a stanza
    for (int n; n < numLines; n++) {
        // a line
        1 => gain.gain;
        say("I");
        wait();
        say("am");
        wait();
        say(feeling);
        wait();
        0 => gain.gain;
        endl();
        wait();

        1 => gain.gain;
        say("then");
        wait();
        say("I");
        wait();
        say(verb);
        wait();
        0 => gain.gain;
        endl();
        wait();

        1 => gain.gain;
        say("ah,");
        wait();
        wait();
        say("my");
        wait();
        say(ego);
        wait();
        0 => gain.gain;
        endl();
        wait();
        endl();

        // get similar feelingSearch
        model.getSimilar(feeling, feelingSearch.size(), feelingSearch);
        // choose one at random
        feelingSearch[Math.random2(0, feelingSearch.size() - 1)] => feeling;
        // get similar egoSearch
        model.getSimilar(ego, egoSearch.size(), egoSearch);
        // choose one at random
        egoSearch[Math.random2(0, egoSearch.size() - 1)] => ego;
        // get similar verbSearch
        model.getSimilar(verb, verbSearch.size(), verbSearch);
        // choose one at random
        verbSearch[Math.random2(0, verbSearch.size() - 1)] => verb;
    }
    // pause at end of line
    T_LINE_PAUSE => now;
}

fun void endStanza() {
    say("No");
    wait();
    say("one");
    wait();
    say("knows");
    wait();
    say("how");
    wait();
    say("I");
    wait();
    say("feel...");
    wait();
}

// say a word with space after
fun void say(string word) { say(word, " "); }

// say a word
fun void say(string word, string append) {
    // print it
    chout <= word <= append;
    chout.flush();
}

// wait
fun void wait() { wait(T_WORD); }

// wait
fun void wait(dur T) {
    // let time pass, let sound...sound
    T => now;
}

// new line with timing
fun void endl() { endl(T_WORD); }

// new line with timing
fun void endl(dur T) {
    // new line
    chout <= IO.newline();
    chout.flush();
    // let time pass
    T => now;
}
