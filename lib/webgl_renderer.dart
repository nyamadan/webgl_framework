part of webgl_framework;

abstract class WebGLRenderer
{
  CanvasElement dom;
  double get aspect => dom.width / dom.height;

  GL.RenderingContext gl;
  void _initContext(int width, int height)
  {
    this.dom = document.createElement("canvas");
    this.dom.width = width;
    this.dom.height = height;

    this.gl = this.dom.getContext3d();
    if (this.gl == null) {
      throw(new Exception("Could not initialize WebGL context."));
    }

    gl.viewport(0, 0, this.dom.width, this.dom.height);
  }

  GL.Shader compileVertexShader(String source) {
    GL.Shader shader = gl.createShader(GL.VERTEX_SHADER);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if(!gl.getShaderParameter(shader, GL.COMPILE_STATUS)) {
      throw(new ShaderCompileException("vertex shader:\n${gl.getShaderInfoLog(shader)}", source));
    }

    return shader;
  }

  GL.Shader compileFragmentShader(String source) {
    GL.Shader shader = gl.createShader(GL.FRAGMENT_SHADER);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if(!gl.getShaderParameter(shader, GL.COMPILE_STATUS)) {
      throw(new ShaderCompileException("fragment shader:\n${gl.getShaderInfoLog(shader)}", source));
    }

    return shader;
  }

  GL.Program linkProgram(GL.Shader vs, GL.Shader fs) {
    var program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);

    if(!gl.getProgramParameter(program, GL.LINK_STATUS)) {
      throw(new ShaderLinkException("Could not link shader: ${gl.getProgramInfoLog(program)}"));
    }

    return program;
  }

  bool trackball_enabled = true;
  double trackball_value = 0.5;
  double trackball_value_delta = 0.05;
  Quaternion trackball_rotation = new Quaternion.identity();
  Vector2 trackball_rotation_delta = new Vector2(0.01, 0.01);
  void _initTrackball() {
    Point prev_point = null;
    this.dom.onMouseDown.listen((MouseEvent event){
      event.preventDefault();

      prev_point = event.client;
    });

    this.dom.onMouseMove.listen((MouseEvent event){
      event.preventDefault();

      if (prev_point == null) {
        return;
      }

      if(this.trackball_enabled) {
        Point delta = event.client - prev_point;
        Quaternion rotation = new Quaternion.identity() .. setEuler(delta.x * this.trackball_rotation_delta.x, delta.y * this.trackball_rotation_delta.y, 0.0);
        this.trackball_rotation =  rotation * this.trackball_rotation;
      }
      prev_point = event.client;
    });

    this.dom.onMouseUp.listen((MouseEvent event){
      event.preventDefault();
      prev_point = null;
    });

    this.dom.onMouseWheel.listen((WheelEvent event){
      event.preventDefault();

      if(event.deltaY > 0.0) {
        this.trackball_value = Math.min(this.trackball_value + this.trackball_value_delta, 1.0);
      }

      if(event.deltaY < 0.0) {
        this.trackball_value = Math.max(this.trackball_value - this.trackball_value_delta, 0.0);
      }
    });
  }

  GL.Buffer createIBO(Uint16List data) {
    var ibo = gl.createBuffer();
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ibo);
    gl.bufferDataTyped(GL.ELEMENT_ARRAY_BUFFER, data, GL.STATIC_DRAW);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);

    return ibo;
  }

  WebGLElementArrayBuffer createElementArrayBuffer(Uint16List data) {
    return new WebGLElementArrayBuffer(this.createIBO(data), data);
  }

  GL.Buffer createVBO(Float32List data) {
    var vbo = gl.createBuffer();
    gl.bindBuffer(GL.ARRAY_BUFFER, vbo);
    gl.bufferDataTyped(GL.ARRAY_BUFFER, data, GL.STATIC_DRAW);
    gl.bindBuffer(GL.ARRAY_BUFFER, null);

    return vbo;
  }

  WebGLArrayBuffer createArrayBuffer(Float32List data) {
    return new WebGLArrayBuffer(this.createVBO(data), data);
  }

  WebGLCanvasTexture createCanvasTexture({int width : 32, int height : 32, Vector4 color : null}) {
    var canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;

    var ctx = canvas.getContext("2d");
    if(color != null) {
      int r = (Math.min(Math.max(color.r, 0.0), 1.0) * 0xff).toInt();
      int g = (Math.min(Math.max(color.g, 0.0), 1.0) * 0xff).toInt();
      int b = (Math.min(Math.max(color.b, 0.0), 1.0) * 0xff).toInt();
      num a = Math.min(Math.max(color.a, 0.0), 1.0);

      var fillStyle_orig = ctx.fillStyle;
      ctx.setFillColorRgb(r, g, b, a);
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = fillStyle_orig;
    }

    var texture = gl.createTexture();
    gl.bindTexture(GL.TEXTURE_2D, texture);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
    gl.texImage2DCanvas(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, canvas);
    gl.bindTexture(GL.TEXTURE_2D, null);

    return new WebGLCanvasTexture(texture, canvas, ctx);
  }

  void bindTexture2D(WebGLCanvasTexture texture) {
    gl.bindTexture(GL.TEXTURE_2D, texture.texture);
  }

  Future<WebGLCanvasTexture> loadCanvasTexture(WebGLCanvasTexture texture, String uri, {bool flip_y: false}) {
    var completer = new Completer<WebGLCanvasTexture>();
    var future = completer.future;

    ImageElement image = document.createElement("img");
    image.onLoad.listen((event){
      bool isPowerOfTwo(int x) => (x & (x - 1)) == 0x00;
      int nextHighestPowerOfTwo(int x) {
        --x;
        for(int i = 1; i < 32; i <<= 1) {
          x = x | x >> i;
        }
        return x + 1;
      }

      if(isPowerOfTwo(image.width) && isPowerOfTwo(image.height)) {
        texture.canvas.width = image.width;
        texture.canvas.height = image.height;
      } else {
        texture.canvas.width = nextHighestPowerOfTwo(image.width);
        texture.canvas.height = nextHighestPowerOfTwo(image.height);
      }

      texture.ctx.drawImage(image, 0, 0);

      gl.bindTexture(GL.TEXTURE_2D, texture.texture);

      if(flip_y) {
        gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 1);
      } else {
        gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 0);
      }
      gl.texImage2DCanvas(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, texture.canvas);
      gl.generateMipmap(GL.TEXTURE_2D);
      gl.bindTexture(GL.TEXTURE_2D, null);

      completer.complete(texture);
    });

    image.src = uri;

    return future;
  }

  Map<String, GL.UniformLocation> getUniformLocations(GL.Program program, List<String> uniform_names) {
    var uniforms = new Map<String, GL.UniformLocation>();

    uniform_names.forEach((String name){
      var location = gl.getUniformLocation(program, name);
      if(location != null) {
        uniforms[name] = location;
      }
    });

    return uniforms;
  }

  Map<String, int> getAttributes(GL.Program program, List<String> names) {
    var attributes = new Map<String, int>();
    names.forEach((String name) {
      int attribute = gl.getAttribLocation(program, name);
      if(attribute >= 0) {
        attributes[name] = attribute;
      }
    });
    return attributes;
  }

  WebGLRenderer({int width : 512, int height : 512}) {
    this._initContext(width, height);
    this._initTrackball();
  }

  void render(double ms);
}
