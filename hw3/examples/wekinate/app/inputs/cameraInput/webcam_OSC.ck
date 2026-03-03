//-----------------------------------------------------------------------------
// name: webcam_OSC.ck
// desc: downsample and send webcam footage through OSC! Based (heavily) on Andrew Zhu Aday's
// texture-read.ck example
//
// authors: Michael Gancz (https://ccrma.stanford.edu/~azaday/)
//    date: February 2026
//-----------------------------------------------------------------------------

// ChuGL webcam
Webcam webcam(0);

// create a texture to write the webcam data we're reading
TextureDesc desc;
webcam.width() => desc.width;
webcam.height() => desc.height;
false => desc.mips;
Texture write_texture(desc);

// webcam texture
GPlane plane --> GG.scene();
4 => plane.sca;
plane.colorMap(webcam.texture());

// downsampling stuff
webcam.texture().data() @=> float data[]; // the raw webcam texture data array
100 => int numPoints;                      // the number of data points we want to send
int step; // how aggressively we're downsampling (this gets set in the real-time loop so don't worry
          // about it here)
float message[numPoints]; // the downsampled array that we're actually sending through OSC

// osc stuff
OscOut xmit;                  // our OSC emitter
xmit.dest("localhost", 6448); // change to whatever osc receiver port you're using
30::ms => dur oscRate;      // how often we're sending messages

fun void read() {
    while (true) {
        webcam.texture().read() => now;
        webcam.texture().data() @=> data;
    }
}

fun void send() {
    while (true) {
        // just as a sanity check
        <<< "Data size: " + data.size() >>>;
        <<< "Message size: " + message.size() >>>;
        <<< "Step size: " + step >>>;

        data.size() / numPoints => step;
        downsample(data);

        // package and send osc message
        xmit.start("/wek/inputs");
        for (float elem : message) {
            elem => xmit.add;
        }
        xmit.send();

        oscRate => now;
    }
}

fun void downsample(
    float raw[]) // downsamples our raw webcam footage into a prespecified number of data points
{
    0 => int counter;
    for (int idx; idx < raw.size(); idx++) {
        if (idx % step == 0) {
            raw[idx] => message[counter];
            counter++;
        }
    }
}

spork ~ read();
spork ~ send();
while (true) {
    GG.nextFrame() => now;
}
