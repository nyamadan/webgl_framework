library noise_renderer;

import 'dart:js';
import 'dart:html';
import "dart:web_gl" as GL;
import "dart:typed_data";
import "dart:async";
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
    float w = 0.5 * exp(-pow(uv.y - 0.5, 2.0) * 30.0);
    float noise = snoise(vec3(0.0, uv.y * 50.0, t)) * exp(-pow(abs(mod(t, 1.0) * 2.0 - 1.0), 2.0) * 20.0);
    vec2 s = vec2((uv.x * 1.5) - 0.25 + (4.0 * noise * w), uv.y * 1.5 - 0.25);
    vec3 color = vec3(0.0);
    if(s.x < 1.0 && s.x > 0.0 && s.y < 1.0 && s.y > 0.0) {
      color = texture2D(texture, s).rgb;
    }
    gl_FragColor = vec4(color, 1.0);
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
  
  List<ImageElement> images;
  int current = -1;
  
  bool ready = false;
  double last_updated;
  double started;
  
  int frame = 0;

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
    
    this._initializeFBO();
    
    var futures = new List<Future<ImageElement>>();
    [
     "image1.jpg",
     "image2.jpg",
     "image3.jpg",
     "image4.jpg",
     "image5.jpg",
     "image6.jpg",
     "image7.jpg",
    ].forEach((url) {
      ImageElement img = document.createElement("img");
      
      img.src = url;
      if(img.complete) {
        futures.add(new Future<ImageElement>.value(img));
        return;
      }
      
      var completer = new Completer<ImageElement>();
      img.onLoad.listen((Event event){
        completer.complete(img);
      });
      futures.add(completer.future);
      return;
    });

    Future.wait(futures).then((List<ImageElement> images){
      this.images = images;
    })
    .then((_) {
      this.texture = new WebGLCanvasTexture(gl, flip_y: true, wrap_s: GL.CLAMP_TO_EDGE, wrap_t: GL.CLAMP_TO_EDGE);
      return this.texture.load(gl, "pattern.jpg");
    })
    .then((_){ 
      this.ready = true;     
    });
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
    if(!ready) {
      return;
    }

    if(frame == 512) {
      last_updated = ms;
      current = (current + 1) % images.length;
      texture.ctx.drawImage(images[current], 0, 0);
      texture.refresh(gl);
    }
    
    gl.bindFramebuffer(GL.FRAMEBUFFER, null);
    gl.viewport(0, 0, this.dom.width, this.dom.height);
    gl.useProgram(this.program);
    gl.enable(GL.DEPTH_TEST);
    gl.clearColor(0.5, 0.5, 0.5, 1.0);

    setUniformTexture0("texture", texture.texture);
    setAttributeFloat3("position", position_buffer.buffer);
    setUniformFloat("t", frame * 0.001);
    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
    frame = (frame + 16) % 1024;
  }
}
