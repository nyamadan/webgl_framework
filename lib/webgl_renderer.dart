part of webgl_framework;

abstract class WebGLRenderer
{
  CanvasElement dom;
  double get aspect => dom.width / dom.height;

  _Trackball trackball;

  GL.RenderingContext gl;
  Map<String, int> attributes;
  Map<String, GL.UniformLocation> uniforms;
  void initContext(int width, int height)
  {
    this.dom = document.createElement("canvas");
    this.dom.width = width;
    this.dom.height = height;

    this.gl = this.dom.getContext3d(antialias: true);
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
        gl.enableVertexAttribArray(attribute);
        attributes[name] = attribute;
      }
    });
    return attributes;
  }

  void setUniformVector2(String key, Vector2 v) {
    if (this.uniforms.containsKey(key)) {
      gl.uniform2fv(this.uniforms[key], v.storage);
    }
  }

  void setUniformFloat(String key, double v) {
    if (this.uniforms.containsKey(key)) {
      gl.uniform1f(this.uniforms[key], v);
    }
  }
  
  void setUniformTexture0(String key, GL.Texture texture) {
    if (this.uniforms.containsKey(key)) {
      gl.activeTexture(GL.TEXTURE0);
      gl.bindTexture(GL.TEXTURE_2D, texture);
      gl.uniform1i(this.uniforms[key], 0);
    }
  }
  
  void setUniformMatrix4(String key, Matrix4 v) {
    if (this.uniforms.containsKey(key)) {
      gl.uniformMatrix4fv(this.uniforms[key], false, v.storage);
    }
  }
  
  void setAttributeFloat3(String key, GL.Buffer buffer) {
    if (this.attributes.containsKey(key)) {
      gl.bindBuffer(GL.ARRAY_BUFFER, buffer);
      gl.vertexAttribPointer(this.attributes[key], 3, GL.FLOAT, false, 0, 0);
    }
  }
  
  void setAttributeFloat2(String key, GL.Buffer buffer) {
    if (this.attributes.containsKey(key)) {
      gl.bindBuffer(GL.ARRAY_BUFFER, buffer);
      gl.vertexAttribPointer(this.attributes[key], 2, GL.FLOAT, false, 0, 0);
    }
  }
  void render(double ms);
}
