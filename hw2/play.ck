@import "constant.ck"

public class Play {
    0 => static int NONE;   // not played
    1 => static int ACTIVE; // playing
    0 => int state;
    0 => int toAna; // 1 when gain is connected to anaBus instead of sndBus

    Gain sndGain, anaGain;
    // sndBus: output to sound
    // anaBus: bus for analyzer
    fun void init(Gain @sndBus, Gain @anaBus) {
        // only enable sndGain
        1 => sndGain.gain;
        0 => anaGain.gain;
        // connect to sound bus & analysis bus
        sndGain => sndBus;
        anaGain => anaBus;
    }

    fun void setColor(vec3 color) {}
    fun void play(float p, float amount) {}
    fun void stop() {}

    fun void toggleAna() {
        if (toAna) {
            0 => toAna;
            1 => sndGain.gain;
            0 => anaGain.gain;
        } else {
            1 => toAna;
            0 => sndGain.gain;
            1 => anaGain.gain;
        }
    }
}

public class LinePlay extends Play {
    FrencHrn a => NRev rev => Pan2 pan => sndGain;
    pan => anaGain;

    0.2 => a.gain;
    0.1 => rev.mix;

    fun setColor(vec3 color) {
        Color.rgb2hsv(color) => vec3 hsv;
        // map value(brightness) to pitch
        Std.mtof(Math.map2(hsv.z, 0., 1., 30, 100)) => a.freq;
        // map saturation to loudness
        Math.map2(hsv.y, 0., 1., .1, 0.5) => a.gain;
    }

    fun void play(float p, float amount) {
        // <<< "play" >>>;
        // map pan
        p => pan.pan;

        if (state == NONE) {
            ACTIVE => state;
            1 => a.noteOn;
        }
    }

    fun void stop() {
        // <<< "stop" >>>;
        if (state == ACTIVE) {
            NONE => state;
            1 => a.noteOff;
        }
    }
}

public class CirclePlay extends Play {
    SinOsc m => SinOsc a => NRev rev => Pan2 pan => sndGain;
    pan => anaGain;

    2 => a.sync; // FM synth

    0.1 => rev.mix;
    0 => a.gain;
    // NRev rev[2];
    // for (int ch; ch < 2; ++ch)
    //     pan.chan(ch) => rev[ch] => dac.chan(ch);
    // 0.2 => rev[0].mix => rev[1].mix;

    fun setColor(vec3 color) {
        Color.rgb2hsv(color) => vec3 hsv;
        // map value(brightness) to pitch
        Std.mtof(Math.map2(hsv.z, 0., 1., 30 - 12, 100 - 12)) => a.freq;
        a.freq() / 1.618 => m.freq;
        // map saturation to loudness
        // Math.map2(hsv.y, 0., 1., .1, 1.2) => a.gain;
    }

    fun void play(float p, float amount) {
        // <<< "play" >>>;
        // map pan
        p => pan.pan;
        // map chord length to loudness
        Math.map2(amount, 0., 1., 0., 1000) => m.gain;
        // map chord length to loudness
        Math.map2(amount, 0., 1., 0., 1.) => a.gain;

        if (state == NONE) {
            ACTIVE => state;
            // 1 => a.noteOn;
        }
    }

    fun void stop() {
        // <<< "stop" >>>;
        if (state == ACTIVE) {
            NONE => state;
            0 => a.gain;
            // 1 => a.noteOff;
        }
    }
}

public class PlanePlay extends Play {
    SqrOsc a => NRev rev => Pan2 pan => sndGain;
    pan => anaGain;

    0 => a.gain;
    0.1 => rev.mix;

    fun setColor(vec3 color) {
        Color.rgb2hsv(color) => vec3 hsv;
        // map value(brightness) to pitch
        Std.mtof(Math.map2(hsv.z, 0., 1., 30 - 12, 100 - 12)) => a.freq;
        // map saturation to loudness
        // Math.map2(hsv.y, 0., 1., .1, 0.7) => a.gain;
    }

    fun void play(float p, float amount) {
        // <<< "play" >>>;
        // map pan
        p => pan.pan;
        // map length to loudness
        Math.map2(amount, 0., 1., 0., 0.5) => a.gain;

        if (state == NONE) {
            ACTIVE => state;
            // 1 => a.noteOn;
        }
    }

    fun void stop() {
        // <<< "stop" >>>;
        if (state == ACTIVE) {
            NONE => state;
            0 => a.gain;
            // 1 => a.noteOff;
        }
    }
}
