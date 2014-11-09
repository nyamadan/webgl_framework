library mmd_renderer;

import 'dart:html';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as Math;
import 'dart:web_gl' as GL;

import "package:webgl_framework/webgl_framework.dart";
import "package:vector_math/vector_math.dart";

import "sjis_to_string.dart";
import "teapot.dart" as teapot;

class MMD_Vertex {
  Vector3 position;
  Vector3 normal;
  Vector2 coord;

  int bone1;
  int bone2;

  int bone_weight;
  int edge_flag;
}

class MMD_Model {
  String name;
  String comment;

  List<MMD_Vertex> vertices;
  Uint16List triangles;

  Future<MMD_Model> load(String uri) {
    var completer = new Completer<MMD_Model>();
    var future = completer.future;

    var req = new HttpRequest();
    req.responseType = "arraybuffer";
    req.onLoad.listen((event){
      ByteBuffer buffer = req.response;
      this.parse(buffer);
      completer.complete(this);
    });
    req.open("GET", uri);
    req.send();

    return future;
  }

  void parse(ByteBuffer buffer) {
    var view = new ByteData.view(buffer);
    int offset = 0;
    offset = this._checkHeader(buffer, view, offset);
    offset = this._getName(buffer, view, offset);
    offset = this._getVertices(buffer, view, offset);
    offset = this._getTriangles(buffer, view, offset);
  }

  Float32List createPositionList() {
    Float32List position_list = new Float32List(this.vertices.length * 3);
    for(int i = 0; i < this.vertices.length; i++) {
      var position = this.vertices[i].position;
      position_list[i * 3 + 0] = position.x;
      position_list[i * 3 + 1] = position.y;
      position_list[i * 3 + 2] = position.z;
    }
    return position_list;
  }

  Float32List createNormalList() {
    Float32List normal_list = new Float32List(this.vertices.length * 3);
    for(int i = 0; i < this.vertices.length; i += 3) {
      var normal = this.vertices[i].normal;
      normal_list[i * 3 + 0] = normal.x;
      normal_list[i * 3 + 1] = normal.y;
      normal_list[i * 3 + 2] = normal.z;
    }
    return normal_list;
  }

  int _checkHeader(ByteBuffer buffer, ByteData view, int offset) {
    var header = buffer.asUint8List(0, 7);
    if(
    header[0] != 0x50 ||
    header[1] != 0x6d ||
    header[2] != 0x64 ||
    header[3] != 0x00 ||
    header[4] != 0x00 ||
    header[5] != 0x80 ||
    header[6] != 0x3f
    ) {
      throw(new Exception("File is not PMD"));
    }

    return offset + 7 * Uint8List.BYTES_PER_ELEMENT;
  }

  int _getName(ByteBuffer buffer, ByteData view, int offset) {
    this.name = sjisArrayToString(buffer.asUint8List(offset, 20));
    offset += Uint8List.BYTES_PER_ELEMENT * 20;

    this.comment = sjisArrayToString(buffer.asUint8List(offset, 256));
    offset += Uint8List.BYTES_PER_ELEMENT * 256;

    return offset;
  }

  int _getVertices(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += Uint32List.BYTES_PER_ELEMENT;

    this.vertices = new List<MMD_Vertex>();
    for(int i = 0; i < length; i++) {
      var v = new MMD_Vertex();

      v.position = new Vector3.zero();
      v.position.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += Float32List.BYTES_PER_ELEMENT;
      v.position.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += Float32List.BYTES_PER_ELEMENT;
      v.position.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += Float32List.BYTES_PER_ELEMENT;

      v.normal = new Vector3.zero();
      v.normal.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += Float32List.BYTES_PER_ELEMENT;
      v.normal.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += Float32List.BYTES_PER_ELEMENT;
      v.normal.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += Float32List.BYTES_PER_ELEMENT;

      v.coord = new Vector2.zero();
      v.coord.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += Float32List.BYTES_PER_ELEMENT;
      v.coord.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += Float32List.BYTES_PER_ELEMENT;

      v.bone1 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += Uint16List.BYTES_PER_ELEMENT;

      v.bone2 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += Uint16List.BYTES_PER_ELEMENT;

      v.bone_weight = view.getUint8(offset);
      offset += Uint8List.BYTES_PER_ELEMENT;

      v.edge_flag = view.getUint8(offset);
      offset += Uint8List.BYTES_PER_ELEMENT;

      this.vertices.add(v);
    }
    return offset;
  }

  int _getTriangles(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += Uint32List.BYTES_PER_ELEMENT;

    this.triangles = new Uint16List(length);
    for(int i = 0; i < length; i += 3) {
      int v0 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += Uint16List.BYTES_PER_ELEMENT;

      int v1 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += Uint16List.BYTES_PER_ELEMENT;

      int v2 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += Uint16List.BYTES_PER_ELEMENT;

      this.triangles[i + 0] = v1;
      this.triangles[i + 1] = v0;
      this.triangles[i + 2] = v2;
    }

    return offset;
  }
}

class MMD_Renderer extends WebGLRenderer {
  static const String VS =
  """
  attribute vec3 position;
  attribute vec3 normal;
  uniform mat4 mvp_matrix;

  varying vec3 v_normal;

  void main(void){
    v_normal = normal;
    gl_Position = mvp_matrix * vec4(position, 1.0);
  }
  """;

  static const String FS =
  """
  precision mediump float;
  varying vec3 v_normal;

  void main(void){
    gl_FragColor = vec4(v_normal, 1.0);
  }
  """;

  GL.Program program;

  Map<String, int> attributes;
  Map<String, GL.UniformLocation> uniforms;

  WebGLArrayBuffer position_buffer;
  WebGLArrayBuffer normal_buffer;
  WebGLElementArrayBuffer index_buffer;

  MMD_Model pmd;

  MMD_Renderer({int width: 512, int height: 512}) : super(width: width, height: height)
  {
    var vs = this.compileVertexShader(VS);
    var fs = this.compileFragmentShader(FS);
    this.program = this.linkProgram(vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    this.attributes = this.getAttributes(this.program, [
      "position",
      "normal",
    ]);
    this.uniforms = this.getUniformLocations(this.program, [
      "mvp_matrix",
    ]);

    gl.enable(GL.DEPTH_TEST);
    gl.clearColor(0.5, 0.5, 0.5, 1.0);
    gl.useProgram(this.program);

    if (this.attributes.containsKey("position")) {
      gl.enableVertexAttribArray(this.attributes["position"]);
    }

    if (this.attributes.containsKey("normal")) {
      gl.enableVertexAttribArray(this.attributes["normal"]);
    }

    (new MMD_Model())
    .load("miku.pmd")
    .then((MMD_Model pmd){
      var position_list = pmd.createPositionList();
      var normal_list = pmd.createNormalList();
      var index_list = pmd.triangles;

      this.position_buffer = this.createArrayBuffer(position_list);
      this.normal_buffer = this.createArrayBuffer(normal_list);
      this.index_buffer = this.createElementArrayBuffer(index_list);

      this.pmd = pmd;
    });
  }

  void render(double ms) {
    if (this.pmd == null) {
      return;
    }

    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 1000.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 20.0 + 10.0 * this.trackball_value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 model = new Matrix4.identity();
    model.setRotation(this.trackball_rotation.asRotationMatrix());

    Matrix4 mvp = projection * view * model;

    if (this.uniforms.containsKey("mvp_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["mvp_matrix"], false, mvp.storage);
    }

    if (this.attributes.containsKey("normal")) {
      gl.bindBuffer(GL.ARRAY_BUFFER, this.normal_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["normal"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("position")) {
      gl.bindBuffer(GL.ARRAY_BUFFER, this.position_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["position"], 3, GL.FLOAT, false, 0, 0);
    }

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);

    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, this.index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
  }
}
