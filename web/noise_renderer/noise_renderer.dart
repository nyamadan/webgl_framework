library noise_renderer;

import "dart:web_gl" as GL;
import "dart:typed_data";
import "package:vector_math/vector_math.dart";
import "package:webgl_framework/webgl_framework.dart";

part "noise_2d.dart";
part "noise_3d.dart";

class NoiseRenderer extends WebGLRenderer {
  
  static const String VS = """
  attribute vec3 position;
  varying vec2 uv;

  void main(void){
    uv = position.xy * 0.5 + 0.5;
    gl_Position = vec4(position, 1.0);
  }
  """;

  static const String FS = """
  uniform sampler2D texture;
  uniform float t;
  varying vec2 uv;

  void main(void){
    vec4 color = texture2D(texture, uv);
    float noise = 0.5 * snoise(vec3(uv * 5.0, t)) + 1.0;
    gl_FragColor = vec4(vec3(noise), 1.0);
  }
  """;

  GL.Program program;

  WebGLArrayBuffer32 position_buffer;
  WebGLArrayBuffer32 normal_buffer;
  WebGLArrayBuffer32 coord_buffer;
  WebGLElementArrayBuffer16 index_buffer;
  WebGLCanvasTexture texture;
  
  GL.Framebuffer fbo;
  GL.Renderbuffer depth_buffer;
  GL.Texture color_buffer;

  List<GL.Framebuffer> fbo_list;
  List<GL.Texture> texture_list;

  void _initializeFBO() {
    this.fbo = gl.createFramebuffer();
    gl.bindFramebuffer(GL.FRAMEBUFFER, this.fbo);

    this.depth_buffer = gl.createRenderbuffer();
    gl.bindRenderbuffer(GL.RENDERBUFFER, this.depth_buffer);
    gl.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, this.dom.width, this.dom.height);
    gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, this.depth_buffer);

    this.color_buffer = gl.createTexture();
    gl.bindTexture(GL.TEXTURE_2D, this.color_buffer);
    gl.texImage2DTyped(GL.TEXTURE_2D, 0, GL.RGBA, this.dom.width, this.dom.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
    gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, this.color_buffer, 0);

    gl.bindTexture(GL.TEXTURE_2D, null);
    gl.bindRenderbuffer(GL.RENDERBUFFER, null);
    gl.bindFramebuffer(GL.FRAMEBUFFER, null);
  }

  void _initialize() {
    var vs = this.compileVertexShader(VS);
    var fs = this.compileFragmentShader([
      "precision mediump float;",
      _NOISE_3D,
      FS,
    ].join("\n"));
    this.program = this.linkProgram(vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    this.attributes = this.getAttributes(this.program, [
      "position",
    ]);
    this.uniforms = this.getUniformLocations(this.program, [
      "texture",
      "t",
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
    
    this.texture = new WebGLCanvasTexture(gl, flip_y: true);
    this.texture.load(gl, "pattern.png");

    this._initializeFBO();
  }

  NoiseRenderer(int width, int height) {
    this.initContext(width, height);
    this.initTrackball();
    this._initialize();
  }

  NoiseRenderer.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;

    this._initialize();
  }

  void render(double ms) {
    Matrix4 mvp = new Matrix4.identity();

    gl.bindFramebuffer(GL.FRAMEBUFFER, null);
    gl.viewport(0, 0, this.dom.width, this.dom.height);
    gl.useProgram(this.program);
    gl.enable(GL.DEPTH_TEST);
    gl.clearColor(0.5, 0.5, 0.5, 1.0);

    this.setUniformTexture0("texture", this.texture.texture);
    this.setAttributeFloat3("position", this.position_buffer.buffer);
    this.setUniformFloat("t", ms * 0.001);
    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, this.index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
  }
}
