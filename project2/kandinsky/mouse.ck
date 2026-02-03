// simplified Mouse class from examples/input/Mouse.ck  =======================
public class Mouse {
    vec2 pos;

    // update mouse world position
    fun void selfUpdate() {
        while (true) {
            GG.nextFrame() => now;
            // calculate mouse world X and Y coords
            GG.camera().screenCoordToWorldPos(GWindow.mousePos(), 1.0) => vec3 worldPos;
            worldPos.x => this.pos.x;
            worldPos.y => this.pos.y;
        }
    }
}
