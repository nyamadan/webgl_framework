part of webgl_framework;

abstract class WebGLRenderer
{
  CanvasElement dom;
  double get aspect => dom.width / dom.height;

  _Trackball trackball;

  GL.RenderingContext gl;
  void initContext(int width, int height)
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

  void initTrackball() {
    this.trackball = new _Trackball(this.dom);
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

  void render(double ms);
}
