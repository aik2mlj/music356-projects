//-----------------------------------------------------------------------------
// name: kandinsky.ck
// desc: abstract painting sonified
//
// author: Lejun Min  (https://aik2.site)
// date: Fall 2024
//-----------------------------------------------------------------------------
@import "draw.ck"
@import "mosaic.ck"

// mitigate the weird bug that static values only become valid after class instantiation
C _con;

// Shared audio bus: all shape synths route here before going to dac
// This allows FFT analysis of the generated sound for mosaic synthesis
Gain preMix => dac;
0.8 => preMix.gain;

// Initialize Mouse Manager ===================================================
Mouse mouse;
spork ~ mouse.selfUpdate(); // start updating mouse position

// Scene setup ================================================================
GG.scene() @=> GScene @scene;
GG.windowed(1280, 720);
GG.camera() @=> GCamera @cam;
cam.orthographic(); // Orthographic camera mode for 2D scene

// light
GG.scene().light() @=> GLight light;
0. => light.intensity;

// bloom
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.threshold(5);
bloom_pass.intensity(1);
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

// white background
TPlane background --> scene;
C.WIDTH => background.scaX;
C.HEIGHT_GLB => background.scaY;
-90 => background.posZ;
@(1., 1., 1.) * 5 => background.color;

DrawEvent drawEvent;
preMix @=> drawEvent.preMix; // pass audio bus to drawEvent for shapes
// polymorphism
Draw @draws[4];
LineDraw lineDraw(mouse, drawEvent) @=> draws[0];
CircleDraw circleDraw(mouse, drawEvent) @=> draws[1];
PlaneDraw planeDraw(mouse, drawEvent) @=> draws[2];
Eraser eraser(mouse, drawEvent) @=> draws[3];
for (auto draw : draws) {
    draw --> GG.scene();
    spork ~ draw.draw();
}
spork ~ select_drawtool(mouse, draws, drawEvent);

ColorPicker colorPicker(mouse, drawEvent) --> scene;
spork ~ colorPicker.pick();

PlayLine playline(mouse, drawEvent) --> scene;
spork ~ playline.play();


fun void select_drawtool(Mouse @m, Draw draws[], DrawEvent @drawEvent) {
    while (true) {
        GG.nextFrame() => now;
        for (auto draw : draws) {
            if (GWindow.mouseLeftDown() && draw.isHovered()) {
                // clicked on this drawtool
                if (drawEvent.isNone() || drawEvent.isActive() && drawEvent.draw != draw) {
                    // was inactive / switch activation
                    <<< "activate" >>>;
                    drawEvent.setActive(draw);
                    // drawEvent.broadcast();
                } else if (drawEvent.isActive() && drawEvent.draw == draw) {
                    // deactivate
                    <<< "deactivate" >>>;
                    drawEvent.setNone();
                    // drawEvent.broadcast();
                }
                break;
            }
        }
    }
}

// Mosaic synthesizer: analyzes preMix audio and synthesizes similar samples
Mosaic mosaic;
// input: pre-extracted model file
if (me.args() > 0) {
    me.arg(0) => string FEATURES_FILE;
    if (mosaic.init(FEATURES_FILE, preMix)) {
        spork ~ mosaic.run();
        <<< "Mosaic synthesizer enabled with:", FEATURES_FILE >>>;
    }
} else {
    <<< "usage: chuck kandinsky.ck:INPUT", "" >>>;
    <<< " |- INPUT: model file (.txt) containing extracted feature vectors", "" >>>;
    <<< " |- (running without mosaic synthesis)", "" >>>;
}

while (true) {
    GG.nextFrame() => now;
}
