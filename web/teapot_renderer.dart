library teapot_renderer;

import "dart:typed_data";
import "dart:web_gl" as GL;
import "dart:math" as Math;
import "package:vector_math/vector_math.dart";
import "package:webgl_framework/webgl_framework.dart";
import "teapot.dart" as teapot;

part "copy_renderer.dart";
part "drop_renderer.dart";
part "ripple_renderer.dart";

class TeapotRenderer extends WebGLRenderer {
  static const String VS = """
  attribute vec3 position;
  attribute vec3 normal;
  attribute vec2 coord;
  uniform mat4 mvp_matrix;

  varying vec3 v_normal;
  varying vec2 v_coord;

  void main(void){
    v_coord = coord;
    v_normal = normal;
    gl_Position = mvp_matrix * vec4(position, 1.0);
  }
  """;

  static const String FS = """
  precision mediump float;

  uniform sampler2D texture;

  varying vec3 v_normal;
  varying vec2 v_coord;

  void main(void){
    vec4 color = texture2D(texture, v_coord);
    float d  = clamp(dot(v_normal, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
    gl_FragColor = vec4(color.rgb * ((d * d) * 0.5 + 0.5), 1.0);
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

  CopyRenderer copy_renderer;
  
  RippleRenderer ripple_renderer;
  DropRenderer drop_renderer;

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
    gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, this.dom.width, this.dom.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
    gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, this.color_buffer, 0);

    gl.bindTexture(GL.TEXTURE_2D, null);
    gl.bindRenderbuffer(GL.RENDERBUFFER, null);
    gl.bindFramebuffer(GL.FRAMEBUFFER, null);

    int data_length = 4 * this.dom.width * this.dom.height;
    Float32List zero_data = new Float32List(data_length);
    zero_data.fillRange(0, data_length, 0.0);
    
    this.fbo_list = new List<GL.Framebuffer>(2);
    this.texture_list = new List<GL.Texture>(2);
    for (int i = 0; i < 2; i++) {
      this.fbo_list[i] = gl.createFramebuffer();
      gl.bindFramebuffer(GL.FRAMEBUFFER, this.fbo_list[i]);

      this.texture_list[i] = gl.createTexture();
      gl.bindTexture(GL.TEXTURE_2D, this.texture_list[i]);
      gl.texImage2DTyped(GL.TEXTURE_2D, 0, GL.RGBA, this.dom.width, this.dom.height, 0, GL.RGBA, GL.FLOAT, zero_data);
      gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
      gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
      gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, this.texture_list[i], 0);

      gl.bindTexture(GL.TEXTURE_2D, null);
      gl.bindFramebuffer(GL.FRAMEBUFFER, null);
    }
  }
  
  void _swapFBO() {
    GL.Texture temp_texture = this.texture_list[0];
    this.texture_list[0] = this.texture_list[1];
    this.texture_list[1] = temp_texture;
    
    GL.Framebuffer temp_fbo = this.fbo_list[0];
    this.fbo_list[0] = this.fbo_list[1];
    this.fbo_list[1] = temp_fbo;
  }

  void _initialize() {
    var vs = this.compileVertexShader(VS);
    var fs = this.compileFragmentShader(FS);
    this.program = this.linkProgram(vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    this.attributes = this.getAttributes(this.program, ["position", "normal", "coord",]);
    this.uniforms = this.getUniformLocations(this.program, ["mvp_matrix", "texture",]);

    this.position_buffer = new WebGLArrayBuffer32(gl, teapot.positions);
    this.normal_buffer = new WebGLArrayBuffer32(gl, teapot.normals);
    this.coord_buffer = new WebGLArrayBuffer32(gl, teapot.coords);
    this.index_buffer = new WebGLElementArrayBuffer16(gl, teapot.indices);

    this.texture = new WebGLCanvasTexture(gl, flip_y: true);
    this.texture.load(gl, "pattern.png");

    this._initializeFBO();

    this.copy_renderer = new CopyRenderer.copy(this);
    this.drop_renderer = new DropRenderer.copy(this);
    this.ripple_renderer = new RippleRenderer.copy(this);
  }

  TeapotRenderer(int width, int height) {
    this.initContext(width, height);
    this.initTrackball();

    gl.getExtension('OES_texture_float');
    gl.getExtension('OES_texture_float_linear');
    this._initialize();
  }

  TeapotRenderer.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;

    this._initialize();
  }

  void render(double ms) {
    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 1000.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 30.0 + 100.0 * this.trackball.value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 model = new Matrix4.identity();
    model.setRotation(this.trackball.rotation.asRotationMatrix());

    Matrix4 mvp = projection * view * model;

    gl.bindFramebuffer(GL.FRAMEBUFFER, this.fbo);
    gl.viewport(0, 0, this.dom.width, this.dom.height);
    gl.useProgram(this.program);
    gl.enable(GL.DEPTH_TEST);
    gl.clearColor(0.5, 0.5, 0.5, 1.0);

    this.setUniformTexture0("texture", this.texture.texture);
    this.setUniformMatrix4("mvp_matrix", mvp);
    this.setAttributeFloat3("position", position_buffer.buffer);
    this.setAttributeFloat3("normal", normal_buffer.buffer);
    this.setAttributeFloat2("coord", coord_buffer.buffer);

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, this.index_buffer.data.length, GL.UNSIGNED_SHORT, 0);

    gl.bindFramebuffer(GL.FRAMEBUFFER, this.fbo_list[0]);
    this.drop_renderer.ripple_texture = this.texture_list[1];
    this.drop_renderer.render(ms);
    this._swapFBO();
    
    gl.bindFramebuffer(GL.FRAMEBUFFER, null);
    this.ripple_renderer.color_texture = this.color_buffer;
    this.ripple_renderer.ripple_texture = this.texture_list[1];
    this.ripple_renderer.render(ms);
  }
}
