@import "mouse.ck"
@import "play.ck"

// Various object class for painting ==========================================
public class NoiseShader {
    // create the custom shader description
    ShaderDesc shader_desc;
    me.dir() + "noise.wgsl" => shader_desc.vertexPath;
    me.dir() + "noise.wgsl" => shader_desc.fragmentPath;
    // default vertex layout (each vertex has a float3 position, float3 normal, float2 uv)
    [VertexFormat.Float3, VertexFormat.Float3, VertexFormat.Float2] @=> shader_desc.vertexLayout;

    // compile the shader
    Shader noise_shader(shader_desc);

    // assign shader to a material
    Material noise_mat;
    noise_mat.shader(noise_shader);

    1.0 => float utime;
    noise_mat.uniformFloat(0, utime);

    fun void update() {
        while (true) {
            GG.nextFrame() => now;
            utime + GG.dt() => utime;
            noise_mat.uniformFloat(0, utime);
        }
    }
}

public class Shape extends GGen {
    Shred @animateShred;
    Material @material;
    GMesh @gMesh;
    Play @play;
    NoiseShader noiseShader;
    Shred @shaderShred;
    vec3 color0;
    vec3 colorNow;
    0 => int inverted;
    0 => int usingShader;

    Gain @sndBus;
    Gain @anaBus;

    fun void stop() {
        // stop playing, useful when erasing shapes
    }

    fun int touchX(float x, float speed) { return false; }

    fun int touchY(float y, float speed) { return false; }

    fun float x2pan(float x, float speed) {
        // if (speed > 0)
        return Math.map2(x, C.LEFT, C.RIGHT, -1., 1.);
        // else
        //     return Math.map2(x, C.LEFT, C.RIGHT, 1., -1.);
    }

    fun float y2pan(float y, float speed) {
        // if (speed > 0)
        return Math.map2(y, C.UP, C.DOWN, -1., 1.);
        // else
        //     return Math.map2(y, C.UP, C.DOWN, 1., -1.);
        // TODO: specify play direction
    }

    fun int isHovered(Mouse @mouse) { return false; }

    fun vec3 _getRevertedColor(vec3 color) {
        if (inverted == 0) {
            1 => inverted;
            return @(1 - color.x, 1 - color.y, 1 - color.z);
        } else {
            0 => inverted;
            return color;
        }
    }

    // polymorphic function for color inversion
    fun void invertColor() { <<< " invertColor not implemented " >>>; }

    // material as noise shader
    fun void _attachShader() {
        noiseShader.noise_mat.uniformFloat3(1, colorNow);
        gMesh.mat(noiseShader.noise_mat);
        spork ~ noiseShader.update() @=> shaderShred;
    }
    fun void _detachShader() {
        gMesh.mat(material);
        if (shaderShred != null)
            shaderShred.exit();
    }
    fun void toggleShader() {
        if (usingShader) {
            _detachShader();
            0 => usingShader;
        } else {
            _attachShader();
            1 => usingShader;
        }
    }
}

public class Line extends Shape {
    GLines g --> this;
    g @=> gMesh;
    g.mat() @=> material;
    vec2 start, end, dd;
    float cos, sin;
    float length;
    float slope;
    float width0;
    new LinePlay @=> play;

    fun Line(vec2 start, vec2 end, vec3 color, float width, float depth, Gain @sndBus,
             Gain @anaBus) {
        start => this.start;
        end => this.end;
        end - start => this.dd;
        (start.y - end.y) / (start.x - end.x) => slope;
        Math.sqrt(dd.x * dd.x + dd.y * dd.y) => this.length;
        dd.x / length => this.cos;
        dd.y / length => this.sin;

        width => width0 => g.width;
        color => color0 => colorNow => g.color;
        play.init(sndBus, anaBus);
        play.setColor(color);
        g.positions([start, end]);
        depth => this.posZ;
    }

    fun void stop() {
        play.stop();
        width0 => this.width;
        // color0 => this.color;
        if (animateShred != null)
            animateShred.exit();
    }

    fun void updatePos(vec2 start, vec2 end) { g.positions([start, end]); }

    fun vec3 color() { return g.color(); }

    fun void color(vec3 c) {
        g.color(c);
        play.setColor(c);
    }

    fun float width() { return g.width(); }

    fun void width(float w) { g.width(w); }

    fun float getX(float y) { return (1. / slope) * (y - start.y) + start.x; }

    fun float getY(float x) { return slope * (x - start.x) + start.y; }

    fun int isHovered(Mouse @mouse) {
        // transform mouse position to line coordinate
        mouse.pos.x - start.x => float x_tr;
        mouse.pos.y - start.y => float y_tr;
        x_tr * cos + y_tr * sin => float x_prime;
        -x_tr * sin + y_tr * cos => float y_prime;

        return (0 <= x_prime && x_prime <= length && -width() / 2. <= y_prime &&
                y_prime <= width() / 2.);
    }

    fun void animate(float speed) {
        now => time t0;
        while (true) {
            GG.nextFrame() => now;
            (now - t0) / 1::second => float t;
            Math.sin(t * speed * 5) => float inc;
            width0 + inc * 0.02 => this.width;
            // @(color0.x+inc*0.1, color0.y+inc*0.1, color0.z+inc*0.1) => this.color;
        }
    }

    fun int touchX(float x, float speed) {
        if (x >= Math.min(start.x, end.x) && x <= Math.max(start.x, end.x)) {
            // calculate the intersection's y
            getY(x) => float y;
            if (play.state == 0)
                spork ~ animate(speed) @=> animateShred;
            play.play(y2pan(y, speed), 0);
            return true;
        } else {
            stop();
            return false;
        }
    }

    fun int touchY(float y, float speed) {
        if (y >= Math.min(start.y, end.y) && y <= Math.max(start.y, end.y)) {
            // calculate the intersection's x
            getX(y) => float x;
            if (play.state == 0)
                spork ~ animate(speed) @=> animateShred;
            play.play(x2pan(x, speed), 0);
            return true;
        } else {
            stop();
            return false;
        }
    }

    fun void invertColor() { _getRevertedColor(this.color0) => colorNow => this.color; }
    fun void toggleShader() {
        <<< "GLines seems not able to change material, skipping toggleShader..." >>>;
    }
}

public class Circle extends Shape {
    GCircle g --> this;
    g @=> gMesh;
    FlatMaterial mat @=> material;
    g.mat(mat);
    CircleGeometry geo(.5, 96, 0., 2 * Math.pi);
    g.geo(geo);

    new CirclePlay @=> play;

    vec2 center;
    float r;

    float sca0;

    fun Circle(vec2 center, float r, vec3 color, float depth, Gain @sndBus, Gain @anaBus) {
        center => this.center;
        r => this.r;
        @(center.x, center.y, depth) => this.pos;
        r * 2. => sca0 => this.sca;
        color => color0 => colorNow => mat.color;
        play.init(sndBus, anaBus);
        play.setColor(color);
    }

    fun vec3 color() { return mat.color(); }

    fun void color(vec3 c) {
        mat.color(c);
        play.setColor(c);
    }

    fun void stop() {
        play.stop();
        sca0 => this.sca;
        // color0 => this.color;
        if (animateShred != null)
            animateShred.exit();
    }

    fun int isHovered(Mouse @mouse) {
        mouse.pos - center => vec2 dd;
        return dd.x * dd.x + dd.y * dd.y <= r * r;
    }

    fun void animate(float speed) {
        now => time t0;
        while (true) {
            GG.nextFrame() => now;
            (now - t0) / 1::second => float t;
            Math.sin(t * speed * 5) => float inc;
            sca0 + inc * 0.03 => this.sca;
            // @(color0.x+inc*0.1, color0.y+inc*0.1, color0.z+inc*0.1) => this.color;
        }
    }

    fun int touchX(float x, float speed) {
        if (x >= center.x - r && x <= center.x + r) {
            if (play.state == 0)
                spork ~ animate(speed) @=> animateShred;
            // Math.sqrt(r * r - (x - center.x) * (x - center.x)) => float amount;
            // fix stuttering
            (r - Math.fabs(x - center.x)) * 2 => float amount;
            play.play(y2pan(center.y, speed), amount / C.HEIGHT);
            return true;
        } else {
            stop();
            return false;
        }
    }

    fun int touchY(float y, float speed) {
        if (y >= center.y - r && y <= center.y + r) {
            if (play.state == 0)
                spork ~ animate(speed) @=> animateShred;
            // Math.sqrt(r * r - (x - center.x) * (x - center.x)) => float amount;
            // fix stuttering
            (r - Math.fabs(y - center.y)) * 2 => float amount;
            play.play(x2pan(center.x, speed), amount / C.HEIGHT);
            return true;
        } else {
            stop();
            return false;
        }
    }

    fun void invertColor() {
        _getRevertedColor(this.color0) => colorNow => this.color;
        noiseShader.noise_mat.uniformFloat3(1, colorNow);
    }
}

public class Plane extends Shape {
    GPlane g --> this;
    g @=> gMesh;
    FlatMaterial mat @=> material;
    g.mat(mat);
    vec2 start, end;

    new PlanePlay @=> play;

    vec3 sca0;

    fun Plane(vec2 pos, float scale, vec3 color, float depth, Gain @sndBus, Gain @anaBus) {
        // might be useless, only square
        @(pos.x, pos.y, depth) => this.pos;
        scale => this.sca;
        this.sca() => sca0;
        @(pos.x - scale / 2., pos.y - scale / 2.) => this.start;
        @(pos.x + scale / 2., pos.y + scale / 2.) => this.end;
        color => color0 => colorNow => mat.color;
        play.init(sndBus, anaBus);
        play.setColor(color);
    }

    fun Plane(vec2 start, vec2 end, vec3 color, float depth, Gain @sndBus, Gain @anaBus) {
        // rectangular
        start => this.start;
        end => this.end;
        (start + end) / 2. => vec2 pos;
        @(pos.x, pos.y, depth) => this.pos;
        Math.fabs((start - end).x) => this.scaX;
        Math.fabs((start - end).y) => this.scaY;
        this.sca() => sca0;
        color => color0 => colorNow => mat.color;
        play.init(sndBus, anaBus);
        play.setColor(color);
    }

    fun void stop() {
        play.stop();
        sca0 => this.sca;
        // color0 => this.color;
        if (animateShred != null)
            animateShred.exit();
    }

    fun vec3 color() { return mat.color(); }

    fun void color(vec3 c) {
        mat.color(c);
        play.setColor(c);
    }

    fun int isHovered(Mouse @mouse) {
        scaX() / 2. => float halfWidth;
        scaY() / 2. => float halfHeight;
        return (mouse.pos.x > pos().x - halfWidth && mouse.pos.x < pos().x + halfWidth &&
                mouse.pos.y > pos().y - halfHeight && mouse.pos.y < pos().y + halfHeight);
    }

    fun void animate(float speed) {
        now => time t0;
        while (true) {
            GG.nextFrame() => now;
            (now - t0) / 1::second => float t;
            Math.sin(t * speed * 5) => float inc;
            @(sca0.x + inc * 0.03, sca0.y + inc * 0.03, sca0.z + inc * 0.03) => this.sca;
            // @(color0.x+inc*0.1, color0.y+inc*0.1, color0.z+inc*0.1) => this.color;
        }
    }

    fun int touchX(float x, float speed) {
        if (x >= Math.min(start.x, end.x) && x <= Math.max(start.x, end.x)) {
            if (play.state == 0)
                spork ~ animate(speed) @=> animateShred;
            play.play(y2pan(this.posY(), speed), this.scaY() / C.HEIGHT);
            return true;
        } else {
            stop();
            return false;
        }
    }

    fun int touchY(float y, float speed) {
        if (y >= Math.min(start.y, end.y) && y <= Math.max(start.y, end.y)) {
            if (play.state == 0)
                spork ~ animate(speed) @=> animateShred;
            play.play(x2pan(this.posX(), speed), this.scaX() / C.HEIGHT);
            return true;
        } else {
            stop();
            return false;
        }
    }

    fun void invertColor() {
        _getRevertedColor(this.color0) => colorNow => this.color;
        noiseShader.noise_mat.uniformFloat3(1, colorNow);
    }
}
