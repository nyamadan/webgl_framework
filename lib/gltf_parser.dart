part of webgl_framework;

class GLTFTechniquePass {
  String key;
  Map<String, String> attribute_names;
  Map<String, String> uniform_names;
  Map<String, GL.UniformLocation> uniform_locations;
  GLTFProgram program;
  List<int> enabled;

  String toString() =>
      [
          "{",
          [
              "key: ${this.key}",
              "attribute_names: ${this.attribute_names}",
              "uniform_names: ${this.uniform_names}",
              "uniform_locations: ${this.uniform_locations}",
              "enabled: ${this.enabled}",
              "program: ${this.program}",].join(", "),
          "}"].join("");
}

class GLTFTechniqueParameter {
  String key;
  String semantic;
  int type;

  String toString() =>
      ["{", ["key: ${this.key}", "semantic: ${this.semantic}", "type: ${this.type}",].join(", "), "}"].join("");
}

class GLTFTechnique {
  String key;
  Map<String, GLTFTechniqueParameter> parameters;
  Map<String, GLTFTechniquePass> passes;
  GLTFTechniquePass pass;

  GLTFTechnique parse(Map<String, dynamic> response, Map<String, GLTFProgram> programs, String key) {
    Map<String, dynamic> response_technique = response["techniques"][key];

    this.key = key;
    
    this.parameters = new Map<String, GLTFTechniqueParameter>();
    (response_technique["parameters"] as Map<String, Map<String, dynamic>>).forEach(
        (String key, Map<String, dynamic> response_parameter) {
      var parameter = new GLTFTechniqueParameter();
      parameter.key = key;
      parameter.type = response_parameter["type"];
      parameter.semantic = response_parameter["semantic"];
      this.parameters[key] = parameter;
    });

    this.passes = new Map<String, GLTFTechniquePass>();
    (response_technique["passes"] as Map<String, Map<String, dynamic>>).forEach(
        (String key, Map<String, dynamic> response_pass) {
      var response_program = response_pass["instanceProgram"];
      var pass = new GLTFTechniquePass();
      pass.key = key;
      pass.uniform_names = response_program["uniforms"];
      pass.attribute_names = response_program["attributes"];
      pass.program = programs[response_program["program"]];
      pass.enabled = response_pass["states"]["enable"];
      this.passes[key] = pass;
    });
    
    this.pass = this.passes[response_technique["pass"]];

    return this;
  }

  String toString() =>
      [
          "{",
          ["key: ${this.key}", "parameters: ${this.parameters}", "pass: ${this.pass}", "passes: ${this.passes}"].join(", "),
          "}"].join("");
}

class GLTFBufferView {
  String key;
  GLTFBuffer buffer;
  int target;
  List view;

  GLTFBufferView parse(Map<String, dynamic> response, Map<String, GLTFBuffer> buffers, String key) {
    Map<String, dynamic> response_buffer_view = response["bufferViews"][key];

    this.key = key;
    this.buffer = buffers[response_buffer_view["buffer"]];
    this.target = response_buffer_view["target"];
    int byte_offset = response_buffer_view["byteOffset"];
    int byte_length = response_buffer_view["byteLength"];

    switch (this.target) {
      case GL.ELEMENT_ARRAY_BUFFER:
        this.view = this.buffer.buffer.asUint16List(byte_offset, byte_length ~/ Uint16List.BYTES_PER_ELEMENT);
        break;
      case GL.ARRAY_BUFFER:
        this.view = this.buffer.buffer.asFloat32List(byte_offset, byte_length ~/ Float32List.BYTES_PER_ELEMENT);
        break;
    }
    return this;
  }

  String toString() =>
      ["{", ["key: ${this.key}", "target: ${this.target}", "buffer: ${this.buffer}",].join(", "), "}"].join("");
}


class GLTFBuffer {
  String key;
  String type;
  ByteBuffer buffer;
  String uri;

  Future<GLTFBuffer> load(Map<String, dynamic> response, String base_path, String key) {
    var completer = new Completer<GLTFBuffer>();
    var future = completer.future;

    var response_buffer = response["buffers"][key];

    this.key = key;
    this.uri = response_buffer["uri"];
    this.type = response_buffer["type"];

    var req = new HttpRequest();
    req.overrideMimeType("text/plain; charset=x-user-defined");
    req.onLoad.listen((event) {
      List<int> units = req.responseText.codeUnits;
      var u8_list = new Uint8List.fromList(units);
      this.buffer = u8_list.buffer;
      completer.complete(this);
    });

    req.open("GET", "${base_path}/${this.uri}");
    req.send();

    return future;
  }

  String toString() =>
      [
          "{",
          ["key: ${this.key}", "type: ${this.type}", "buffer: ${this.buffer}", "uri: ${this.uri}",].join(", "),
          "}"].join("");
}

class GLTFShader {
  String key;
  int type;
  GL.Shader shader;
  String source;
  String uri;

  Future<GLTFShader> load(Map<String, dynamic> response, String base_path, String key) {
    var completer = new Completer<GLTFShader>();
    var future = completer.future;

    var response_buffer = response["shaders"][key];

    this.key = key;
    this.uri = response_buffer["uri"];
    this.type = response_buffer["type"];

    var req = new HttpRequest();
    req.onLoad.listen((event) {
      this.source = req.responseText;
      completer.complete(this);
    });

    req.open("GET", "${base_path}/${this.uri}");
    req.send();

    return future;
  }

  String toString() =>
      [
          "{",
          [
              "key: ${this.key}",
              "type: ${this.type}",
              "uri: ${this.uri}",
              "source: ${this.source}",
              "shader: ${this.shader}",].join(", "),
          "}"].join("");
}

class GLTFProgram {
  String key;
  GL.Program program;

  GLTFShader fragment_shader;
  GLTFShader vertex_shader;

  Map<String, int> attributes;
  List<String> attribute_names;

  GLTFProgram parse(Map<String, dynamic> response, Map<String, GLTFShader> shaders, String key) {
    Map<String, dynamic> response_program = response["programs"][key];

    this.key = key;
    this.fragment_shader = shaders[response_program["fragmentShader"]];
    this.vertex_shader = shaders[response_program["vertexShader"]];
    this.attribute_names = response_program["attributes"];
    return this;
  }

  String toString() =>
      [
          "{",
          [
              "key: ${this.key}",
              "vertex_shader: ${this.vertex_shader}",
              "fragment_shader: ${this.fragment_shader}",
              "attribute_names: ${this.attribute_names}",
              "attributes: ${this.attributes}",
              "program: ${this.program}",].join(", "),
          "}"].join("");
}

class GLTFParser extends WebGLRenderer {
  Map<String, GLTFBuffer> buffers;
  Map<String, GLTFShader> shaders;

  GLTFParser(int width, int height) {
    this.initContext(width, height);
    this.initTrackball();
    this._initialize();
  }

  GLTFParser.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;

    this._initialize();
  }

  void _initialize() {
  }

  Future<Map<String, dynamic>> _loadJson(String base_path, String path) {
    var completer = new Completer<Map<String, dynamic>>();
    var future = completer.future;

    var req = new HttpRequest();
    req.overrideMimeType("application/json");
    req.onLoad.listen((event) {
      Map<String, dynamic> response = JSON.decode(req.responseText);
      completer.complete(response);
    });
    req.open("GET", "$base_path/$path");
    req.send();

    return future;
  }

  Future<Map<String, GLTFBuffer>> _loadBuffers(Map<String, dynamic> response, String base_path) {
    var completer = new Completer<Map<String, GLTFBuffer>>();
    var future = completer.future;

    Map<String, dynamic> buffers = response["buffers"];

    Future.wait(buffers.keys.map((String key) {
      var buffer = new GLTFBuffer();
      return buffer.load(response, base_path, key);
    })).then((List<GLTFBuffer> results) {
      var buffers = new Map<String, GLTFBuffer>();
      results.forEach((GLTFBuffer buffer) => buffers[buffer.key] = buffer);
      return completer.complete(buffers);
    });

    return future;
  }

  Future<Map<String, GLTFShader>> _loadShaders(Map<String, dynamic> response, String base_path) {
    var completer = new Completer<Map<String, GLTFShader>>();
    var future = completer.future;

    Map<String, dynamic> shaders = response["shaders"];

    Future.wait(shaders.keys.map((String key) {
      var shader = new GLTFShader();
      return shader.load(response, base_path, key);
    })).then((List<GLTFShader> results) {
      var shaders = new Map<String, GLTFShader>();

      results.forEach((GLTFShader shader) => shaders[shader.key] = shader);

      return completer.complete(shaders);
    });

    return future;
  }

  Map<String, GLTFProgram> programs;
  Map<String, GLTFProgram> _getPrograms(Map<String, dynamic> response, Map<String, GLTFShader> shaders) {
    var programs = new Map<String, GLTFProgram>();
    response["programs"].keys.forEach((String key) {
      var program = new GLTFProgram();
      program.parse(response, shaders, key);
      programs[key] = program;
    });

    return programs;
  }

  Map<String, GLTFBufferView> buffer_views;
  Map<String, GLTFBufferView> _getBufferViews(Map<String, dynamic> response, Map<String, GLTFBuffer> buffers) {
    var buffer_views = new Map<String, GLTFBufferView>();
    response["bufferViews"].keys.forEach((String key) {
      var buffer_view = new GLTFBufferView();
      buffer_view.parse(response, buffers, key);

      buffer_views[key] = buffer_view;
    });

    return buffer_views;
  }

  Map<String, GLTFTechnique> techniques;
  Map<String, GLTFTechnique> _getTechniques(Map<String, dynamic> response, Map<String, GLTFProgram> programs) {
    var techniques = new Map<String, GLTFTechnique>();
    response["techniques"].keys.forEach((String key) {
      var technique = new GLTFTechnique();
      technique.parse(response, programs, key);

      techniques[key] = technique;
    });

    return techniques;
  }

  Future<GLTFParser> load(String base_path, String path) {
    var completer = new Completer<GLTFParser>();
    var future = completer.future;

    this._loadJson(base_path, path).then((Map<String, dynamic> response) {
      var load_buffers = this._loadBuffers(response, base_path);
      var load_shaders = this._loadShaders(response, base_path);

      return Future.wait([load_buffers, load_shaders]).then((List results) {
        this.buffers = results[0];
        this.shaders = results[1];

        return new Future<Map<String, dynamic>>.value(response);
      });
    }).then((Map<String, dynamic> response) {
      this.buffer_views = this._getBufferViews(response, this.buffers);
      this.programs = this._getPrograms(response, this.shaders);
      this.techniques = this._getTechniques(response, this.programs);
      this.compileShaders();
      this.linkPrograms();
      this.setupTechniques();
      completer.complete(this);
    });
    return future;
  }

  void compileShaders() {
    this.shaders.values.forEach((GLTFShader shader) {
      switch (shader.type) {
        case GL.VERTEX_SHADER:
          shader.shader = this.compileVertexShader(shader.source);
          break;
        case GL.FRAGMENT_SHADER:
          shader.shader = this.compileFragmentShader(shader.source);
          break;
      }
    });
  }

  void linkPrograms() {
    this.programs.values.forEach((GLTFProgram program) {
      program.program = this.linkProgram(program.vertex_shader.shader, program.fragment_shader.shader);
      program.attributes = this.getAttributes(program.program, program.attribute_names);
    });
  }

  void setupTechniques() {
    this.techniques.values.forEach((GLTFTechnique technique) {
      technique.passes.values.forEach((GLTFTechniquePass pass) {
        pass.uniform_locations = this.getUniformLocations(pass.program.program, pass.uniform_names.keys);
      });
    });
  }

  void render(double elapsed) {
  }
}
