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
    return new WebGLElementArrayBuffer()
      .. buffer = this.createIBO(data)
      ..data = data
    ;
  }

  GL.Buffer createVBO(Float32List data) {
    var vbo = gl.createBuffer();
    gl.bindBuffer(GL.ARRAY_BUFFER, vbo);
    gl.bufferDataTyped(GL.ARRAY_BUFFER, data, GL.STATIC_DRAW);
    gl.bindBuffer(GL.ARRAY_BUFFER, null);

    return vbo;
  }

  WebGLArrayBuffer createArrayBuffer(Float32List data) {
    return new WebGLArrayBuffer()
      ..buffer = this.createVBO(data)
      ..data = data
    ;
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

  void render(double delta);
}
