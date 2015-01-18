part of webgl_framework;

class GLTFAccessor {
  String key;
  GLTFBufferView buffer_view;
  int byte_offset;
  int byte_stride;
  int component_type;
  int count;
  String type;

  GLTFAccessor parse(Map<String, dynamic> response, Map<String, GLTFBufferView> buffer_views, String key) {
    Map<String, dynamic> response_accessor = response["accessors"][key];
    this.key = key;
    this.buffer_view = buffer_views[response_accessor["bufferView"] as String];
    this.byte_offset = response_accessor["byteOffset"];
    this.byte_stride = response_accessor["byteStride"];
    this.component_type = response_accessor["componentType"];
    this.count = response_accessor["count"];
    this.type = response_accessor["type"];
    return this;
  }

  String toString() =>
      [
          "{",
          [
              "key: ${this.key}",
              "buffer_view: ${this.buffer_view}",
              "byte_offset: ${this.byte_offset}",
              "byte_stride: ${this.byte_stride}",
              "count: ${this.count}",
              "component_type: ${this.component_type}",
              "type: ${this.type}",].join(", "),
          "}"].join("");
}


class GLTFMaterialTechnique {
  GLTFTechnique technique;
  Map<String, dynamic> values;

  GLTFMaterialTechnique parse(Map<String, dynamic> response_material, Map<String, GLTFTechnique> techniques) {
    var response_technique = response_material["instanceTechnique"] as Map<String, dynamic>;
    this.technique = techniques[response_technique["technique"] as String];

    var response_values = response_technique["values"] as Map<String, dynamic>;
    this.values = new Map<String, dynamic>();
    response_values.forEach((String key, dynamic value) {
      GLTFTechniqueParameter parameter = this.technique.parameters[key];

      switch (parameter.type) {
        case GL.FLOAT_VEC4:
          this.values[key] = new Vector4(value[0] * 1.0, value[1] * 1.0, value[2] * 1.0, value[3] * 1.0);
          return;
        case GL.FLOAT_VEC2:
          this.values[key] = new Vector3(value[0] * 1.0, value[1] * 1.0, value[2] * 1.0);
          return;
        case GL.FLOAT_VEC2:
          this.values[key] = new Vector2(value[0] * 1.0, value[1] * 1.0);
          return;
        case GL.FLOAT:
          this.values[key] = value;
          return;
      }

      throw (new Exception("Unknown value type"));
    });
    return this;
  }

  String toString() => ["{", ["technique: ${this.technique}", "values: ${this.values}",].join(", "), "}"].join("");
}

class GLTFMaterial {
  String key;
  String name;
  GLTFMaterialTechnique instance_technique;

  GLTFMaterial parse(Map<String, dynamic> response, Map<String, GLTFTechnique> techniques, String key) {
    Map<String, dynamic> response_material = response["materials"][key];
    this.key = key;
    this.name = response_material["name"];
    this.instance_technique = new GLTFMaterialTechnique();
    this.instance_technique.parse(response_material, techniques);
    return this;
  }
  String toString() =>
      [
          "{",
          ["key: ${this.key}", "name: ${this.name}", "instance_technique: ${this.instance_technique}",].join(", "),
          "}"].join("");
}

class GLTFMeshPrimitive {
  Map<String, GLTFAccessor> attributes;
  GLTFAccessor indices;
  GLTFMaterial material;
  int primitive;

  GLTFMeshPrimitive parse(Map<String, dynamic> response_primitive, Map<String, GLTFAccessor> accessors, Map<String,
      GLTFMaterial> materials) {

    this.primitive = response_primitive["primitive"];
    this.indices = accessors[response_primitive["indices"] as String];
    this.material = materials[response_primitive["material"] as String];
    this.attributes = new Map<String, GLTFAccessor>();
    (response_primitive["attributes"] as Map<String, String>).forEach((String key, String value) {
      this.attributes[key] = accessors[value];
    });
    return this;
  }

  String toString() =>
      [
          "{",
          [
              "attributes: ${this.attributes}",
              "indices: ${this.indices}",
              "material: ${this.material}",
              "primitive: ${this.primitive}",].join(", "),
          "}"].join("");
}

class GLTFMesh {
  String key;
  String name;
  List<GLTFMeshPrimitive> primitives;

  GLTFMesh parse(Map<String, dynamic> response, Map<String, GLTFAccessor> accessors, Map<String,
      GLTFMaterial> materials, String key) {
    Map<String, dynamic> response_mesh = response["meshes"][key];

    this.key = key;
    this.name = response_mesh["name"];
    this.primitives =
        (response_mesh["primitives"] as List<Map<String, dynamic>>).map((Map<String, dynamic> response_primitive) {
      var primitive = new GLTFMeshPrimitive();
      primitive.parse(response_primitive, accessors, materials);
      return primitive;
    }).toList();
    return this;
  }

  String toString() =>
      ["{", ["key: ${this.key}", "name: ${this.name}", "primitives: ${this.primitives}",].join(", "), "}"].join("");
}

class GLTFNode {
  String key;
  String name;
  Matrix4 matrix;
  List<GLTFMesh> meshes;
  List<GLTFNode> children;

  GLTFNode parse(Map<String, dynamic> response, Map<String, GLTFNode> nodes, Map<String, GLTFMesh> meshes, String key) {
    Map<String, dynamic> response_node = response["nodes"][key];
    List<String> response_meshes = response_node["meshes"];
    List<String> response_children = response_node["children"];

    this.key = key;
    this.name = response_node["name"];
    if (response_meshes != null) {
      this.meshes = response_meshes.map((String key) => meshes[key]).toList();
    }
    this.matrix = new Matrix4.fromFloat32List(
        new Float32List.fromList((response_node["matrix"] as List<num>).map((num x) => x * 1.0).toList()));
    this.matrix.transpose();
    
    if (response_children != null) {
      this.children = response_children.map((String child_name) => nodes[child_name]).toList();
    }
    return this;
  }

  String toString() =>
      [
          "{",
          [
              "key: ${this.key}",
              "name: ${this.name}",
              "matrix: ${this.matrix}",
              "meshes: ${this.meshes}",
              "children: ${this.children}",].join(", "),
          "}"].join("");
}

class GLTFScene {
  String key;
  List<GLTFNode> nodes;
  
  GLTFScene parse(Map<String, dynamic> response_scenes, Map<String, GLTFNode> nodes, String key) {
    var response_scene = response_scenes[key];
    this.key = key;
    this.nodes = (response_scene["nodes"] as List<String>).map((String node_name) => nodes[node_name]).toList();
    return this;
  }
  
  String toString() => ["{", ["key: ${this.key}", "nodes: ${this.nodes}",].join(", "), "}"].join("");
}


class GLTFTechniquePassDetailCommonProfile {
  String lighting_model;
  List<String> parameters;

  GLTFTechniquePassDetailCommonProfile parse(Map<String, dynamic> response_common_profile) {
    this.lighting_model = response_common_profile["lightingModel"];
    this.parameters = response_common_profile["parameters"];
    return this;
  }
  
  String toString() =>
      ["{", ["lighting_model: ${this.lighting_model}", "parameters: ${this.parameters}",].join(", "), "}"].join("");
}

class GLTFTechniquePassDetail {
  String type;
  GLTFTechniquePassDetailCommonProfile common_profile;

  GLTFTechniquePassDetail parse(Map<String, dynamic> response_details) {
    var response_common_profile = response_details["commonProfile"];
    this.type = response_details["type"];
    
    this.common_profile = new GLTFTechniquePassDetailCommonProfile();
    this.common_profile.parse(response_common_profile);
    return this;
  }
  
  String toString() =>
      ["{", ["type: ${this.type}", "common_profile: ${this.common_profile}",].join(", "), "}"].join("");
}

class GLTFTechniquePass {
  String key;
  Map<String, GLTFTechniqueParameter> attributes;
  Map<String, GLTFTechniqueParameter> uniforms;
  Map<String, GL.UniformLocation> uniform_locations;
  GLTFTechniquePassDetail details;
  GLTFProgram program;
  List<int> enabled;

  GLTFTechniquePass parse(Map<String, dynamic> response_pass, Map<String, GLTFProgram> programs, Map<String,
      GLTFTechniqueParameter> parameters, String key) {
    var response_instance_program = response_pass["instanceProgram"];
    this.key = key;

    this.uniforms = new Map<String, GLTFTechniqueParameter>();
    (response_instance_program["uniforms"] as Map<String, String>).forEach((String uniform_name, String parameter_key) {
      this.uniforms[uniform_name] = parameters[parameter_key];
    });

    this.attributes = new Map<String, GLTFTechniqueParameter>();
    (response_instance_program["attributes"] as Map<String, String>).forEach(
        (String attribute_name, String parameter_key) {
      this.attributes[attribute_name] = parameters[parameter_key];
    });

    var response_details = response_pass["details"];
    this.details = new GLTFTechniquePassDetail();
    this.details.parse(response_details);
    
    this.program = programs[response_instance_program["program"]];
    this.enabled = response_pass["states"]["enable"];
    
    return this;
  }

  String toString() =>
      [
          "{",
          [
              "key: ${this.key}",
              "attributes: ${this.attributes}",
              "uniforms: ${this.uniforms}",
              "uniform_locations: ${this.uniform_locations}",
              "enabled: ${this.enabled}",
              "program: ${this.program}",].join(", "),
          "}"].join("");
}

class GLTFTechniqueParameter {
  String key;
  String semantic;
  int type;

  GLTFTechniqueParameter parse(Map<String, dynamic> response_parameter, String key) {
    this.key = key;
    this.type = response_parameter["type"];
    this.semantic = response_parameter["semantic"];
    return this;
  }
  
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
      parameter.parse(response_parameter, key);
      this.parameters[key] = parameter;
    });

    this.passes = new Map<String, GLTFTechniquePass>();
    (response_technique["passes"] as Map<String, Map<String, dynamic>>).forEach(
        (String key, Map<String, dynamic> response_pass) {
      var pass = new GLTFTechniquePass();
      pass.parse(response_pass, programs, this.parameters, key);
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
  TypedData view;

  GL.Buffer gl_buffer;

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
      [
          "{",
          ["key: ${this.key}", "target: ${this.target}", "buffer: ${this.buffer}", "gl_buffer: ${this.gl_buffer}",].join(", "),
          "}"].join("");
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
  GL.Program gl_program;

  GLTFShader fragment_shader;
  GLTFShader vertex_shader;

  Map<String, int> gl_attributes;
  List<String> attributes;

  GLTFProgram parse(Map<String, dynamic> response, Map<String, GLTFShader> shaders, String key) {
    Map<String, dynamic> response_program = response["programs"][key];

    this.key = key;
    this.fragment_shader = shaders[response_program["fragmentShader"]];
    this.vertex_shader = shaders[response_program["vertexShader"]];
    this.attributes = response_program["attributes"];
    return this;
  }

  String toString() =>
      [
          "{",
          [
              "key: ${this.key}",
              "vertex_shader: ${this.vertex_shader}",
              "fragment_shader: ${this.fragment_shader}",
              "attributes: ${this.attributes}",
              "gl_attributes: ${this.gl_attributes}",
              "gl_program: ${this.gl_program}",].join(", "),
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

  Map<String, GLTFMaterial> materials;
  Map<String, GLTFMaterial> _getMaterials(Map<String, dynamic> response, Map<String, GLTFTechnique> techniques) {
    var materials = new Map<String, GLTFMaterial>();
    var response_materials = response["materials"] as Map<String, Map<String, dynamic>>;

    response_materials.forEach((String key, Map<String, dynamic> response_material) {
      var material = new GLTFMaterial();
      material.parse(response, techniques, key);
      materials[key] = material;
    });

    return materials;
  }

  Map<String, GLTFAccessor> accessors;
  Map<String, GLTFAccessor> _getAccessors(Map<String, dynamic> response, Map<String, GLTFBufferView> buffer_views) {
    var accessors = new Map<String, GLTFAccessor>();
    var response_accessors = response["accessors"] as Map<String, Map<String, dynamic>>;

    response_accessors.forEach((String key, Map<String, dynamic> response_accessor) {
      var accessor = new GLTFAccessor();
      accessor.parse(response, buffer_views, key);
      accessors[key] = accessor;
    });

    return accessors;
  }

  Map<String, GLTFMesh> meshes;
  Map<String, GLTFMesh> _getMeshes(Map<String, dynamic> response, Map<String, GLTFAccessor> accessors, Map<String,
      GLTFMaterial> materials) {
    var meshes = new Map<String, GLTFMesh>();
    var response_meshes = response["meshes"] as Map<String, Map<String, dynamic>>;

    response_meshes.forEach((String key, Map<String, dynamic> response_mesh) {
      var mesh = new GLTFMesh();
      mesh.parse(response, accessors, materials, key);
      meshes[key] = mesh;
    });

    return meshes;
  }

  Map<String, GLTFNode> nodes;
  Map<String, GLTFNode> _getNodes(Map<String, dynamic> response, Map<String, GLTFMesh> meshes) {
    var response_nodes = response["nodes"] as Map<String, Map<String, dynamic>>;

    var nodes = new Map<String, GLTFNode>();
    response_nodes.keys.forEach((String key) {
      var node = new GLTFNode();
      nodes[key] = node;
    });

    response_nodes.forEach((String key, Map<String, dynamic> response_node) {
      nodes[key].parse(response, nodes, meshes, key);
    });

    return nodes;
  }

  Map<String, GLTFScene> scenes;
  Map<String, GLTFScene> _getScenes(Map<String, dynamic> response, Map<String, GLTFNode> nodes) {
    var response_scenes = response["scenes"] as Map<String, Map<String, dynamic>>;

    var scenes = new Map<String, GLTFScene>();
    response_scenes.keys.forEach((String key) {
      var scene = new GLTFScene();
      scene.parse(response_scenes, nodes, key);
      scenes[key] = scene;
    });

    return scenes;
  }

  GLTFScene scene;
  GLTFScene _getScene(Map<String, dynamic> response, Map<String, GLTFScene> scenes) {
    var scene_name = response["scene"] as String;
    return scenes[scene_name];
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
      this.materials = this._getMaterials(response, this.techniques);
      this.accessors = this._getAccessors(response, this.buffer_views);
      this.meshes = this._getMeshes(response, this.accessors, this.materials);
      this.nodes = this._getNodes(response, this.meshes);
      this.scenes = this._getScenes(response, this.nodes);
      this.scene = this._getScene(response, this.scenes);
      this.compileShaders();
      this.linkPrograms();
      this.setupTechniques();
      this.createBuffers();
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
      program.gl_program = this.linkProgram(program.vertex_shader.shader, program.fragment_shader.shader);
      program.gl_attributes = this.getAttributes(program.gl_program, program.attributes);
    });
  }

  void setupTechniques() {
    this.techniques.values.forEach((GLTFTechnique technique) {
      technique.passes.values.forEach((GLTFTechniquePass pass) {
        pass.uniform_locations = this.getUniformLocations(pass.program.gl_program, pass.uniforms.keys);
      });
    });
  }

  void createBuffers() {
    this.buffer_views.values.forEach((GLTFBufferView buffer_view) {
      buffer_view.gl_buffer = gl.createBuffer();
      gl.bindBuffer(buffer_view.target, buffer_view.gl_buffer);
      gl.bufferDataTyped(buffer_view.target, buffer_view.view, GL.STATIC_DRAW);
      gl.bindBuffer(buffer_view.target, null);
    });
  }

  void render(double elapsed) {
  }
}
