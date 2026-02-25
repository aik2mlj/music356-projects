// name: JoyOfChant.ck
//   original Chant.ck -> Perry Cook
//   map for joystick -> Rebecca Fiebrink + Ge Wang
// date: January 2007

// sources
SndBuf buffy[16];
Impulse i;
Noise n;
// sub patch
TwoZero t => TwoZero t2 => OnePole p;

// formant filters
p => TwoPole f1 => Gain g;
p => TwoPole f2 => g;
p => TwoPole f3 => g;
// reverb and echo
g => ADSR env => Gain gate => JCRev r;
JCRev rr => dac;

// number of channels
dac.channels() => int CHANNELS;
// prev
UGen @prev;
// channel index
0 => int channel;
// buffy index
0 => int which_buffy;

// load glottal pop
for (int i; i < buffy.cap(); i++)
    "special:glot_pop" => buffy[i].read;

// set first two zero filter
1.0 => t.b0;
0.0 => t.b1;
-1.0 => t.b2;
// set second two zero filter
1.0 => t2.b0;
0.0 => t2.b1;
1.0 => t2.b2;

// envelope
env.set(50::ms, 30::ms, .5, 80::ms);
env.keyOff();

// set effects parameters
0.05 => r.mix;
0.01 => rr.mix;

// see formant filter parameters
0.997 => f1.radius;
0.997 => f2.radius;
0.997 => f3.radius;
.4 => float factor;
factor * 1.0 => f1.gain;
factor * 0.8 => f2.gain;
factor * 0.6 => f3.gain;

// initialize center freq
Std.rand2f(230.0, 660.0) => f1.freq;
Std.rand2f(800.0, 2300.0) => f2.freq;
Std.rand2f(1700.0, 3000.0) => f3.freq;

// initialize global variables
400.0 => float f1freq;
1000.0 => float f2freq;
2800.0 => float f3freq;
400.0 => float target_f1freq;
1000.0 => float target_f2freq;
2800.0 => float target_f3freq;
1.0 => float target_gain;

// set one pole parameters
0.99 => p.pole;
.5 => p.gain;

// more global variables, for source generation
0.00625 => float period;
0.00625 => float target_period;
0.0 => float modphase;

// base and register
12 => int base;
3 => int register;
0 => int reg_change;

// toggle mode
0 => int toggle_mode;
1 => int vocal_mode;
0 => int src_mode;
1 => int twist_enable;
0 => int vibrato_bend;
0 => int sing;
buffy.cap() => int bufcap;
0 => float vibrato_depth;
0 => float pitch_bend;
1 => float pop_density;
1.0 / period => Std.ftom => float inter_pitch => float the_pitch;

// initial connection
mono();
// src_mode == 0
buf();

// joystick
Hid js;
// keyboard
Hid kb;
// hid message
HidMsg msg;

<<< "ahem" >>>;

// open
if (!kb.openKeyboard(0))
    me.exit();
if (!js.openJoystick(0))
    me.exit();
<<< "Ready?", "" >>>;

// key map
int key[256];
// key and pitch
0 => key[29];
1 => key[27];
2 => key[6];
3 => key[25];
4 => key[5];
5 => key[4] => key[17];
6 => key[22] => key[16];
7 => key[7] => key[54];
8 => key[9] => key[55];
9 => key[10] => key[56];
10 => key[20] => key[11];
11 => key[26] => key[13];
12 => key[8] => key[14];
13 => key[21] => key[15];
14 => key[23] => key[51];
15 => key[28] => key[52];
16 => key[24];
17 => key[12];
18 => key[18];
19 => key[19];
20 => key[47];
21 => key[48];
22 => key[49];
// which is current
0 => int current;
// current coordinate
0 => float curr_x;
0 => float curr_y;

// the four-mants
[[740.0, 1108.0, 2489.0], // ah
 [530.0, 1864.0, 2637.0], // e
 [349.0, 932.0, 2489.0],  // oo
 [196.0, 2637.0, 2793.0]  // i
] @=> float formants[][];

// the four-mants
[[703.0, 1475.0, 2984.0], // ah
 [530.0, 1864.0, 2637.0], // e
 [390.0, 1450.0, 2906.0], // oo
 [431.0, 2434.0, 2913.0]  // i
] @=> float formants2[][];

// the four-mants
[[703.0, 1475.0, 2984.0], // ah
 [530.0, 1864.0, 2637.0], // e
 [400.0, 800.0, 3250.0],  // oo
 [431.0, 2434.0, 2913.0]  // i
] @=> float formants3[][];

// pertubation
Std.rand2f(.95, 1.05) => float pert_f1;
Std.rand2f(.95, 1.05) => float pert_f2;
Std.rand2f(.95, 1.05) => float pert_f3;

// mono
fun void mono() {
    // disconnect
    for (int i; i < CHANNELS; i++)
        r =< dac.chan(i);
    // connect
    r => dac;
    // gain
    .4 => r.gain;
}

// multi
fun void multi() {
    // disconnect
    r =< dac;
    // gain
    1 => r.gain;
}

// dis
fun void dis() {
    // disconnect
    for (int i; i < buffy.cap(); i++)
        buffy[i] =< t;
    i =< t;
    n =< t;
}

// impulse
fun void imp() {
    // disconnect
    dis();
    // connect
    i => t;
    // gain
    5.0 => i.gain;
}

// buf
fun void buf() {
    // disconnect
    dis();
    // connect
    if (register > 3)
        buffy.cap() => bufcap;
    else
        buffy.cap() / 2 => bufcap;
    for (int i; i < bufcap; i++) {
        buffy[i] => t;
        buffy[i].samples() => buffy[i].pos;
    }
}

// noise
fun void noi() {
    // disconnect
    dis();
    // connect
    n => t;
    .25 => n.gain;
}

// spork shreds
spork ~ ramp_stuff();       // interpolate pitch and formants
spork ~ do_impulse();       // voice source
spork ~ kb_ctrl();          // keyboard input
spork ~ js_ctrl();          // joystick input
spork ~ ramp_other_stuff(); // swell ramp
spork ~ network();          // listener

// help function
fun float distance(float x1, float y1, float x2, float y2) {
    return Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
}

// the almighty bew!
fun void bew() {
    // guess what
    distance(curr_x, curr_y, -1, 1) => float A;
    distance(curr_x, curr_y, 1, 1) => float B;
    distance(curr_x, curr_y, -1, -1) => float C;
    distance(curr_x, curr_y, 1, -1) => float D;

    // weights
    1 / (A + .001) => float wA;
    1 / (B + .001) => float wB;
    1 / (C + .001) => float wC;
    1 / (D + .001) => float wD;

    // normalize
    1 / (wA + wB + wC + wD) => float norm;

    // formant table
    formants3 @=> float forms[][];

    // target formant freqs
    (wA * forms[0][0] + wB * forms[1][0] + wC * forms[2][0] + wD * forms[3][0]) * norm * pert_f1 => target_f1freq;
    (wA * forms[0][1] + wB * forms[1][1] + wC * forms[2][1] + wD * forms[3][1]) * norm * pert_f2 => target_f2freq;
    (wA * forms[0][2] + wB * forms[1][2] + wC * forms[2][2] + wD * forms[3][2]) * norm * pert_f3 => target_f3freq;
}

// yes
fun void registerUp() {
    if (register < 6) {
        register ++;
        1 => reg_change;
    }
    <<< "register:", register >>>;
}

// yes
fun void registerDown() {
    if (register > 0) {
        register --;
        1 => reg_change;
    }
    <<< "register:", register >>>;
}

// keyboard input
fun void kb_ctrl() {
    float freq;

    // infinite event loop
    while (true) {
        // wait for event
        kb => now;

        // get message
        while (kb.recv(msg)) {
            // which
            if (msg.which > 256)
                continue;
            if (key[msg.which] == 0 && msg.which != 29) {
                // register
                if (msg.which == 80 && msg.isButtonDown())
                    registerDown();
                else if (msg.which == 79 && msg.isButtonDown())
                    registerUp();
            }
            // set
            else if (msg.isButtonDown()) {
                // repatch bufs if necessary
                if (reg_change && src_mode == 0) {
                    buf();
                    0 => reg_change;
                }

                // freq
                base + register * 12 + key[msg.which] + Std.rand2f(-.05, .05) => inter_pitch;
                inter_pitch + pitch_bend => the_pitch => Std.mtof => freq;
                1 / freq => target_period;
                msg.which => current;
            }
            // do nothing for button up
        }
    }
}

// joystick input
fun void js_ctrl() {
    float freq;

    // infinite event loop
    while (true) {
        // wait for event
        js => now;

        // get message
        while (js.recv(msg)) {
            // joystick axis motion
            if (msg.isAxisMotion()) {
                // formant axis 1
                if (msg.which == 0) {
                    // remember
                    msg.axisPosition => curr_x;
                    // compute formants
                    bew();
                }
                // formant axis 2
                else if (msg.which == 1) {
                    // remember
                    msg.axisPosition => curr_y;
                    // compute formants
                    bew();
                }
                // twist axis
                else if (msg.which == 2) {
                    if (twist_enable) {
                        if (msg.axisPosition > 0) {
                            (-msg.axisPosition) => vibrato_depth;
                            if (vibrato_bend)
                                msg.axisPosition / 2 => pitch_bend;
                        } else if (msg.axisPosition < 0)
                            (msg.axisPosition) => pitch_bend;
                        else
                            0 => vibrato_depth => pitch_bend;

                        // set freq
                        inter_pitch + pitch_bend => the_pitch => Std.mtof => freq;
                        1 / freq => target_period;
                    }

                    // glottal pop density
                    (msg.axisPosition + 1) / 16 + .035 => pop_density;
                }
                // volume axis
                else if (msg.which == 3) {
                    (-msg.axisPosition + 1) / 2 => g.gain;
                }
            }

            // joystick button down
            else if (msg.isButtonDown()) {
                // trigger
                if (msg.which == 0) {
                    sing => int prev;

                    if (toggle_mode)
                        !sing => sing;
                    else
                        1 => sing;

                    if (!prev && sing) {
                        env.keyOn();
                        3.0 => target_gain;
                    } else if (prev && !sing) {
                        env.keyOff();
                        1.0 => target_gain;
                    }
                }
                // twist enable
                if (msg.which == 1) {
                    0 => twist_enable;
                    0 => vibrato_depth => pitch_bend;

                    // set freq
                    inter_pitch + pitch_bend => the_pitch => Std.mtof => freq;
                    1 / freq => target_period;
                }
                // toggle mode select
                else if (msg.which == 2) {
                    !toggle_mode => toggle_mode;
                    <<< "toggle mode:", toggle_mode ? "ON" : "OFF" >>>;
                    0 => sing;
                    env.keyOff();
                    1.0 => target_gain;
                }
                // src mode select
                else if (msg.which == 6) {
                    (src_mode + 1) % 3 => src_mode;
                    if (src_mode == 2 && !vocal_mode)
                        0 => src_mode;
                    <<< "src mode:", src_mode ? (src_mode == 1 ? "IMPULSE" : "NOISE") : ("GLOTTA"
                                                                                        + "L") >>>;
                    if (src_mode == 1)
                        imp();
                    else if (src_mode == 2)
                        noi();
                    else
                        buf();
                }
                // sing mode select
                else if (msg.which == 7) {
                    !vocal_mode => vocal_mode;
                    <<< "vocal mode:", vocal_mode ? "SING" : "GLOTTAL" >>>;
                    env.keyOff();

                    if (vocal_mode) {
                        mono();
                        if (src_mode == 1)
                            imp();
                        else if (src_mode == 2)
                            noi();
                        else
                            buf();
                    } else {
                        multi();
                        if (src_mode == 1)
                            imp();
                        else
                            buf();
                    }
                }
                // vibrato bend
                else if (msg.which == 8) {
                    !vibrato_bend => vibrato_bend;
                    <<< "vibrato bend:", vibrato_bend ? "ON" : "OFF" >>>;
                }
            }
            // joystick button up
            else if (msg.isButtonUp()) {
                // trigger
                if (msg.which == 0) {
                    sing => int prev;
                    if (!toggle_mode)
                        0 => sing;
                    if (prev && !sing) {
                        env.keyOff();
                        1.0 => target_gain;
                    }
                }
                // twist enable
                else if (msg.which == 1) {
                    1 => twist_enable;
                }
            }
        }

        // hat
        if (msg.isHatMotion()) {
            if (msg.idata == 7 || msg.idata == 0 || msg.idata == 1)
                registerUp();
            else if (msg.idata == 3 || msg.idata == 4 || msg.idata == 5)
                registerDown();
        }
    }
}

// main lop
while (true) {
    // let time pass
    Std.rand2f(0.3, 0.8)::second => now;
}

// source generation
fun void do_impulse() {
    // infinite time loop
    while (true) {
        // sing
        if (vocal_mode) {
            // fire!
            if (src_mode == 1)
                1.0 => i.next;
            else if (src_mode == 2) { /* do nothing */
            } else {
                0 => buffy[which_buffy++].pos;
                bufcap %=> which_buffy;
            }
            // modulate phase
            modphase + period => modphase;
            // let period + mod pass
            (period + (.000025 + 0.0004 * vibrato_depth) * period / .004 *
                          Math.sin(6.28 * modphase * 7.5))::second => now;
        } else // glottal pop
        {
            // connect
            if (prev != null)
                r =< prev;
            dac.chan(channel) @=> prev;
            r => prev;
            channel++;
            CHANNELS %=> channel;

            // fire!
            if (src_mode == 1)
                1.0 => i.next;
            else {
                0 => buffy[which_buffy++].pos;
                bufcap %=> which_buffy;
            }
            // wait
            10 / pop_density * ms => now;
            // Std.rand2f(1,25) / pop_density * ms => now;
        }
    }
}

// interpolation
fun void ramp_stuff() {
    // mysterious 'slew'
    0.025 => float slew;

    // infinite time loop
    while (true) {
        (target_period - period) * 5 * slew + period => period;
        (target_f1freq - f1freq) * slew + f1freq => f1freq => f1.freq;
        (target_f2freq - f2freq) * slew + f2freq => f2freq => f2.freq;
        (target_f3freq - f3freq) * slew + f3freq => f3freq => f3.freq;
        0.0025::second => now;
    }
}

// sustain ramp
fun void ramp_other_stuff() {
    // mysterious 'slew', part tew
    float slew;

    // infinite time loop
    while (true) {
        (target_gain >= env.gain() ? .002 : .025) => slew;
        (target_gain - env.gain()) * slew + env.gain() => env.gain;
        0.0025::second => now;
    }
}

// network
fun void network() {
    // create our OSC receiver
    OscRecv recv;
    // use port 6449 (or whatever)
    6449 => recv.port;
    // start listening (launch thread)
    recv.listen();

    // create an address in the receiver, store in new variable
    recv.event("/manamana/voicegate, f") @=> OscEvent oe;

    // infinite event loop
    while (true) {
        // wait for event to arrive
        oe => now;

        // grab the next message from the queue.
        while (oe.nextMsg()) {
            // set gain
            oe.getFloat() => gate.gain;
        }
    }
}
