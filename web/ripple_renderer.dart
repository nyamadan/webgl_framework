library ripple_renderer;

import "package:webgl_framework/webgl_framework.dart";

import "dart:typed_data";
import "dart:web_gl" as GL;
import "package:vector_math/vector_math.dart";

part "drop_renderer.dart";
part "ripple_pass1_renderer.dart";
part "ripple_pass2_renderer.dart";

// ref: https://github.com/sirxemic/jquery.ripples/
class RippleRenderer extends WebGLRenderer {
  static const String VS =
  """
  attribute vec3 position;
  varying vec2 coord;

  void main(void){
    coord = position.xy * 0.5 + 0.5;
    gl_Position = vec4(position, 1.0);
  }
  """;

  static const String FS =
  """
  precision mediump float;

  uniform vec2 half_pixel;
  uniform sampler2D texture;
  uniform sampler2D ripple;
  uniform float perturbance;

  varying vec2 coord;

  void main(void){
    vec2 offset = -texture2D(ripple, coord).ba;
    float specular = pow(max(0.0, dot(offset, normalize(vec2(-0.6, 1.0)))), 4.0);
    vec4 color = texture2D(texture, coord + offset * perturbance);
    gl_FragColor = vec4(color.rgb + specular, 1.0);
  }
  """;

  GL.Program program;
  
  GL.Texture color_texture;
  GL.Texture ripple_texture;
  double perturbance;

  WebGLArrayBuffer32 position_buffer;
  WebGLElementArrayBuffer16 index_buffer;

  void _initialize() {
    var vs = this.compileVertexShader(VS);
    var fs = this.compileFragmentShader(FS);
    this.program = this.linkProgram(vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    this.attributes = this.getAttributes(this.program, [
      "position",
    ]);
    this.uniforms = this.getUniformLocations(this.program, [
      "texture",
      "ripple",
      "perturbance",
    ]);

    this.position_buffer = new WebGLArrayBuffer32(gl, new Float32List.fromList([
      -1.0,  1.0, 0.0,
       1.0,  1.0, 0.0,
       1.0, -1.0, 0.0,
      -1.0, -1.0, 0.0,
    ]));
    
    this.index_buffer = new WebGLElementArrayBuffer16(gl, new Uint16List.fromList([
      0, 1, 3,
      1, 2, 3,
    ]));
  }

  RippleRenderer(int width, int height)
  {
    this.initContext(width, height);
    this.initTrackball();

    this._initialize();
  }

  RippleRenderer.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;

    this._initialize();
  }

  void render(double ms) {
    gl.viewport(0, 0, this.dom.width, this.dom.height);
    gl.useProgram(this.program);
    
    gl.enable(GL.DEPTH_TEST);
    gl.clearColor(0.5, 0.5, 0.5, 1.0);
    
    this.setUniformTexture0("texture", this.color_texture);
    this.setUniformTexture1("ripple", this.ripple_texture);
    this.setUniformFloat("perturbance", this.perturbance != null ? this.perturbance : 0.04);
    this.setAttributeFloat3("position", this.position_buffer.buffer);

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, this.index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
  }
}

