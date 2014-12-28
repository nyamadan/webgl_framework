part of mmd_renderer;

class PMX_Exception implements Exception {
  final String message;
  const PMX_Exception(this.message);
  String toString() => "PMX_Exception\n${this.message}";
}

class PMX_IK {
  int bone_index;
  Vector3 min;
  Vector3 max;

  int _getInt(ByteBuffer buffer, ByteData view, int offset, int size) {
    if(size == 1) {
      return view.getInt8(offset);
    }
    if(size == 2) {
      return view.getInt16(offset, Endianness.LITTLE_ENDIAN);
    }
    if(size == 4) {
      return view.getInt32(offset, Endianness.LITTLE_ENDIAN);
    }
    return null;
  }

  int parse(ByteBuffer buffer, ByteData view, int offset, int bone_index_size) {
    this.bone_index = this._getInt(buffer, view, offset, bone_index_size);
    offset += bone_index_size;

    int rotation_limit = view.getUint8(offset);
    offset += 1;

    if(rotation_limit != 0) {
      this.min = new Vector3.zero();
      this.max = new Vector3.zero();

      this.max.x = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.max.y = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.min.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      this.min.x = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.min.y = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.max.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
    }

    return offset;
  }

  String toString() => ["{", [
    "bone_index: ${this.bone_index}",
    "min: ${this.min}",
    "max: ${this.max}",
  ].join(", "), "}"].join("");
}

class PMX_Bone {
  String name;
  String english_name;
  Vector3 bone_head_pos;
  int parent_bone_index;
  int depth;
  int flag;
  int tail_bone_index;
  Vector3 tail_bone_pos;

  int parent_transform_bone_index;
  double transform_weight;

  Vector3 axis;
  Vector3 local_axis_x;
  Vector3 local_axis_z;

  int foreign_parent_key;

  int ik_target_bone_index;
  int iterations;
  double max_angle;
  List<PMX_IK> iks;

  String _getText(ByteBuffer buffer, ByteData view, int offset, int length, int encoding) {
    if(encoding == 0) {
      int word_length = length ~/ 2;
      List<int> name_buffer = new List<int>.generate(word_length, (int i) => view.getUint16(offset + 2 * i, Endianness.LITTLE_ENDIAN));
      return new String.fromCharCodes(name_buffer);
    } else if(encoding == 1) {
      return null;
    }

    return null;
  }

  int _getInt(ByteBuffer buffer, ByteData view, int offset, int size) {
    if(size == 1) {
      return view.getInt8(offset);
    }
    if(size == 2) {
      return view.getInt16(offset, Endianness.LITTLE_ENDIAN);
    }
    if(size == 4) {
      return view.getInt32(offset, Endianness.LITTLE_ENDIAN);
    }
    return null;
  }

  int parse(ByteBuffer buffer, ByteData view, int offset, int encoding, int bone_index_size) {
    int name_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.name = this._getText(buffer, view, offset, name_length, encoding);
    offset += name_length;

    int english_name_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.english_name = this._getText(buffer, view, offset, english_name_length, encoding);
    offset += english_name_length;

    this.bone_head_pos = new Vector3.zero();
    this.bone_head_pos.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.bone_head_pos.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.bone_head_pos.z = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.parent_bone_index = this._getInt(buffer, view, offset, bone_index_size);
    offset += bone_index_size;

    this.depth = view.getInt32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.flag = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    if(this.flag & 0x0001 == 0) {
      this.tail_bone_pos = new Vector3.zero();
      this.tail_bone_pos.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.tail_bone_pos.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.tail_bone_pos.z = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
    } else {
      this.tail_bone_index = this._getInt(buffer, view, offset, bone_index_size);
      offset += bone_index_size;
    }

    if(this.flag & 0x0300 != 0) {
      this.parent_transform_bone_index = this._getInt(buffer, view, offset, bone_index_size);
      offset += bone_index_size;

      this.transform_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
    }

    if(this.flag & 0x0400 != 0) {
      this.axis = new Vector3.zero();
      this.axis.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.axis.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.axis.z = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
    }

    if(this.isLocalAxis) {
      this.local_axis_x = new Vector3.zero();
      this.local_axis_x.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.local_axis_x.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.local_axis_x.z = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      this.local_axis_z = new Vector3.zero();
      this.local_axis_z.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.local_axis_z.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      this.local_axis_z.z = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
    }

    if(this.isForeignParent) {
      this.foreign_parent_key = view.getInt32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
    }

    if(this.isIKBone) {
      this.ik_target_bone_index = this._getInt(buffer, view, offset, bone_index_size);
      offset += bone_index_size;

      this.iterations = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      this.max_angle = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      this.iks = new List<PMX_IK>.generate(length, (int i){
        PMX_IK ik = new PMX_IK();
        offset = ik.parse(buffer, view, offset, bone_index_size);
        return ik;
      });
    }

    return offset;
  }

  bool get isLocalAxis => this.flag & 0x0800 != 0;
  bool get isForeignParent => this.flag & 0x2000 != 0;
  bool get isIKBone => this.flag & 0x0020 != 0;

  String toString() => ["{", [
    "name: ${this.name}",
    "english_name: ${this.english_name}",
    "bone_head_pos: ${this.bone_head_pos}",
    "parent_bone_index: ${this.parent_bone_index}",
    "depth: ${this.depth}",
    "flag: ${this.flag}",
    "tail_bone_index: ${this.tail_bone_index}",
    "tail_bone_pos: ${this.tail_bone_pos}",
    "parent_transform_bone_index: ${this.parent_transform_bone_index}",
    "transform_weight: ${this.transform_weight}",
    "axis: ${this.axis}",
    "local_axis_x: ${this.local_axis_x}",
    "local_axis_z: ${this.local_axis_z}",
    "foreign_parent_key: ${this.foreign_parent_key}",
    "ik_target_bone_index: ${this.ik_target_bone_index}",
    "iterations: ${this.iterations}",
    "max_angle: ${this.max_angle}",
    "iks: ${this.iks != null ? '...' : null}",
  ].join(", "), "}"].join("");
}

class PMX_Vertex {
  Vector3 position;
  Vector3 normal;

  Vector2 coord;
  List<Vector2> extra_coord;

  int blend_type;

  int bone1;
  double bone1_weight;
  int bone2;
  double bone2_weight;
  int bone3;
  double bone3_weight;
  int bone4;
  double bone4_weight;

  Vector3 sdef1;
  Vector3 sdef2;
  Vector3 sdef3;

  double edge_weight;

  int _getInt(ByteBuffer buffer, ByteData view, int offset, int size) {
    if(size == 1) {
      return view.getInt8(offset);
    }
    if(size == 2) {
      return view.getInt16(offset, Endianness.LITTLE_ENDIAN);
    }
    if(size == 4) {
      return view.getInt32(offset, Endianness.LITTLE_ENDIAN);
    }
    return null;
  }

  int parse(ByteBuffer buffer, ByteData view, int offset, int extra_coord_size, int bone_index_size) {
    this.position = new Vector3.zero();
    this.position.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.position.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.position.z = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.normal = new Vector3.zero();
    this.normal.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.normal.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.normal.z = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.coord = new Vector2.zero();
    this.coord.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.coord.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.extra_coord = new List<Vector2>.generate(extra_coord_size, (int i) {
      Vector2 coord = new Vector2.zero();
      coord.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      coord.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      return coord;
    });

    this.blend_type = view.getUint8(offset);
    offset += 1;

    switch(this.blend_type) {
      case 0:
        this.bone1 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        break;
      case 1:
        this.bone1 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone2 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone1_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        break;
      case 2:
        this.bone1 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone2 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone3 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone4 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone1_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.bone2_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.bone3_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.bone4_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        break;
      case 3:
        this.bone1 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone2 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone1_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;

        this.sdef1 = new Vector3.zero();
        this.sdef1.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.sdef1.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.sdef1.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;

        this.sdef2 = new Vector3.zero();
        this.sdef2.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.sdef2.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.sdef2.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;

        this.sdef3 = new Vector3.zero();
        this.sdef3.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.sdef3.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.sdef3.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        break;
      case 4:
        this.bone1 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone2 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone3 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone4 = this._getInt(buffer, view, offset, bone_index_size);
        offset += bone_index_size;
        this.bone1_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.bone2_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.bone3_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        this.bone4_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
        offset += 4;
        break;
    }
    this.edge_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    return offset;
  }

  String toString() => ["{", [
    "position: ${this.position}",
    "normal: ${this.normal}",
    "coord: ${this.coord}",
    "extra_coord: ${this.extra_coord}",
    "blend_type: ${this.blend_type}",
    "bone1: ${this.bone1}",
    "bone1_weight: ${this.bone1_weight}",
    "bone2: ${this.bone2}",
    "bone2_weight: ${this.bone2_weight}",
    "bone3: ${this.bone3}",
    "bone3_weight: ${this.bone3_weight}",
    "bone4: ${this.bone4}",
    "bone4_weight: ${this.bone4_weight}",
    "sdef1: ${this.sdef1}",
    "sdef2: ${this.sdef2}",
    "sdef3: ${this.sdef3}",
  ].join(", "), "}"].join("");
}

class PMX_Material {
  String name;
  String english_name;

  Vector4 diffuse;
  Vector3 specular;
  double shiness;
  Vector3 ambient;

  bool cull_face;
  bool drop_shadow;
  bool drop_self_shadow;
  bool draw_self_shadow;
  bool edge;

  Vector4 edge_color;
  double edge_size;
  int texture_index;
  int sphere_index;
  int sphere_mode;

  int toon_mode;
  int toon_index;

  String comment;
  int face_vert_count;

  String _getText(ByteBuffer buffer, ByteData view, int offset, int length, int encoding) {
    if(encoding == 0) {
      int word_length = length ~/ 2;
      List<int> name_buffer = new List<int>.generate(word_length, (int i) => view.getUint16(offset + 2 * i, Endianness.LITTLE_ENDIAN));
      return new String.fromCharCodes(name_buffer);
    } else if(encoding == 1) {
      return null;
    }

    return null;
  }

  int _getInt(ByteBuffer buffer, ByteData view, int offset, int size) {
    if(size == 1) {
      return view.getInt8(offset);
    }
    if(size == 2) {
      return view.getInt16(offset, Endianness.LITTLE_ENDIAN);
    }
    if(size == 4) {
      return view.getInt32(offset, Endianness.LITTLE_ENDIAN);
    }
    return null;
  }

  int parse(ByteBuffer buffer, ByteData view, int offset, int encoding, int texture_index_size) {
    int name_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.name = this._getText(buffer, view, offset, name_length, encoding);
    offset += name_length;

    int english_name_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.english_name = this._getText(buffer, view, offset, english_name_length, encoding);
    offset += english_name_length;

    this.diffuse = new Vector4.zero();
    this.diffuse.r = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.diffuse.g = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.diffuse.b = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.diffuse.a = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.specular = new Vector3.zero();
    this.specular.r = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.specular.g = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.specular.b = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.shiness = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.ambient = new Vector3.zero();
    this.ambient.r = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.ambient.g = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.ambient.b = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    int bit_flag = view.getUint8(offset);
    offset += 1;

    this.cull_face = (bit_flag & 0x01 != 0) ? false : true;
    this.drop_shadow = (bit_flag & 0x02 != 0) ? true : false;
    this.drop_self_shadow = (bit_flag & 0x04 != 0) ? true : false;
    this.draw_self_shadow = (bit_flag & 0x08 != 0) ? true : false;
    this.edge = (bit_flag & 0x10 != 0) ? true : false;

    this.edge_color = new Vector4.zero();
    this.edge_color.r = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.edge_color.g = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.edge_color.b = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.edge_color.a = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.edge_size = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.texture_index = this._getInt(buffer, view, offset, texture_index_size);
    offset += texture_index_size;

    this.sphere_index = this._getInt(buffer, view, offset, texture_index_size);
    offset += texture_index_size;

    this.sphere_mode = view.getUint8(offset);
    offset += 1;

    this.toon_mode = view.getUint8(offset);
    offset += 1;

    if(toon_mode == 0) {
      this.toon_index = view.getInt8(offset);
      offset += 1;
    }
    if(toon_mode == 1) {
      this.toon_index = this._getInt(buffer, view, offset, texture_index_size);
      offset += texture_index_size;
    }

    int comment_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.comment = this._getText(buffer, view, offset, comment_length, encoding);
    offset += comment_length;

    this.face_vert_count = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    return offset;
  }

  String toString() => ["{", [
  "name:  ${this.name}",
  "english_name:  ${this.english_name}",
  "diffuse:  ${this.diffuse}",
  "specular:  ${this.specular}",
  "shiness:  ${this.shiness}",
  "ambient:  ${this.ambient}",
  "cull_face:  ${this.cull_face}",
  "drop_shadow:  ${this.drop_shadow}",
  "drop_self_shadow:  ${this.drop_self_shadow}",
  "draw_self_shadow:  ${this.draw_self_shadow}",
  "edge:  ${this.edge}",
  "edge_color:  ${this.edge_color}",
  "edge_size:  ${this.edge_size}",
  "texture_index:  ${this.texture_index}",
  "sphere_index:  ${this.sphere_index}",
  "sphere_mode:  ${this.sphere_mode}",
  "toon_mode:  ${this.toon_mode}",
  "toon_index:  ${this.toon_index}",
  "comment:  ${this.comment}",
  "face_vert_count:  ${this.face_vert_count}",
  ].join(", "), "}"].join("");
}

class PMX_Model {
  final Logger log = new Logger("PMX_Model");

  double version;
  int byte_size;
  int encoding;
  int extra_coord_size;
  int vertex_index_size;
  int texture_index_size;
  int material_index_size;
  int bone_index_size;
  int morph_index_size;
  int rigid_body_index_size;

  String name;
  String english_name;
  String comment;
  String english_comment;

  List<PMX_Vertex> vertices;
  List<int> triangles;
  List<String> textures;
  List<PMX_Material> materials;
  List<PMX_Bone> bones;

  Future<PMX_Model> load(String uri) {
    var completer = new Completer<PMX_Model>();
    var future = completer.future;

    var req = new HttpRequest();
    req.overrideMimeType("text\/plain; charset=x-user-defined");
    req.onLoad.listen((event){
      var u8_list = new Uint8List.fromList(req.responseText.codeUnits);
      ByteBuffer buffer = u8_list.buffer;

      this.parse(buffer);
      completer.complete(this);
    });
    req.open("GET", uri);
    req.send();

    return future;
  }

  int _getInt(ByteBuffer buffer, ByteData view, int offset, int size) {
    if(size == 1) {
      return view.getInt8(offset);
    }
    if(size == 2) {
      return view.getInt16(offset, Endianness.LITTLE_ENDIAN);
    }
    if(size == 4) {
      return view.getInt32(offset, Endianness.LITTLE_ENDIAN);
    }
    return null;
  }

  String _getText(ByteBuffer buffer, ByteData view, int offset, int length) {
    if(this.encoding == 0) {
      int word_length = length ~/ 2;
      List<int> name_buffer = new List<int>.generate(word_length, (int i) => view.getUint16(offset + 2 * i, Endianness.LITTLE_ENDIAN));
      return new String.fromCharCodes(name_buffer);
    } else if(this.encoding == 1) {
      return null;
    }

    return null;
  }

  int _getHeader(ByteBuffer buffer, ByteData view, int offset) {
    var header = new List<int>.generate(4, (int i) => view.getUint8(offset + i));
    offset += 4;

    if(
      header[0] != 0x50 ||
      header[1] != 0x4d ||
      header[2] != 0x58 ||
      header[3] != 0x20
    ) {
      throw(new PMX_Exception("File is not PMX"));
    }

    this.version = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.byte_size = view.getUint8(offset);
    offset += 1;

    this.encoding = view.getUint8(offset);
    offset += 1;

    this.extra_coord_size = view.getUint8(offset);
    offset += 1;

    this.vertex_index_size = view.getUint8(offset);
    offset += 1;

    this.texture_index_size = view.getUint8(offset);
    offset += 1;

    this.material_index_size = view.getUint8(offset);
    offset += 1;

    this.bone_index_size = view.getUint8(offset);
    offset += 1;

    this.morph_index_size = view.getUint8(offset);
    offset += 1;

    this.rigid_body_index_size = view.getUint8(offset);
    offset += 1;

    return offset;
  }

  int _getName(ByteBuffer buffer, ByteData view, int offset) {
    int name_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.name = this._getText(buffer, view, offset, name_length);
    offset += name_length;

    int english_name_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.english_name = this._getText(buffer, view, offset, english_name_length);
    offset += english_name_length ;

    int comment_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.comment = this._getText(buffer, view, offset, comment_length);
    offset += comment_length;

    int english_comment_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.english_comment = this._getText(buffer, view, offset, english_comment_length);
    offset += english_comment_length;

    return offset;
  }

  int _getVertices(ByteBuffer buffer, ByteData view, int offset) {
    int vertex_length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.vertices = new List<PMX_Vertex>.generate(vertex_length, (int i) {
      var vertex = new PMX_Vertex();
      offset = vertex.parse(buffer, view, offset, this.extra_coord_size, this.bone_index_size);
      return vertex;
    });

    return offset;
  }

  int _getTriangles(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.triangles = new List<int>(length);
    for(int i = 0; i < length; i += 3) {
      int v0 = this._getInt(buffer, view, offset, this.vertex_index_size);
      offset += this.vertex_index_size;

      int v1 = this._getInt(buffer, view, offset, this.vertex_index_size);
      offset += this.vertex_index_size;

      int v2 = this._getInt(buffer, view, offset, this.vertex_index_size);
      offset += this.vertex_index_size;

      this.triangles[i + 0] = v1;
      this.triangles[i + 1] = v0;
      this.triangles[i + 2] = v2;
    }

    return offset;
  }

  int _getTextures(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;


    this.textures = new List<String>.generate(length, (int i){
      int texture_path_length = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      String path = this._getText(buffer, view, offset, texture_path_length);
      offset += texture_path_length;
      return path;
    });

    return offset;
  }

  int _getMaterials(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.materials = new List<PMX_Material>.generate(length, (int i){
      PMX_Material material = new PMX_Material();
      offset = material.parse(buffer, view, offset, this.encoding, this.texture_index_size);
      return material;
    });

    return offset;
  }

  int _getBones(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.bones = new List<PMX_Bone>.generate(length, (int i){
      PMX_Bone bone = new PMX_Bone();
      offset = bone.parse(buffer, view, offset, this.encoding, this.bone_index_size);
      return bone;
    });

    return offset;
  }

  void parse(ByteBuffer buffer) {
    var view = new ByteData.view(buffer);
    int offset = 0;

    offset = this._getHeader(buffer, view, offset);
    offset = this._getName(buffer, view, offset);
    offset = this._getVertices(buffer, view, offset);
    offset = this._getTriangles(buffer, view, offset);
    offset = this._getTextures(buffer, view, offset);
    offset = this._getMaterials(buffer, view, offset);
    offset = this._getBones(buffer, view, offset);

    log.info(this);
    log.fine("<bones>");
    this.bones.forEach((PMX_Bone bone){
      log.fine(bone);
    });
    log.fine("<materials>");
    this.materials.forEach((PMX_Material material){
      log.fine(material);
    });
  }

  TypedData createTriangleList([int index = null]) {
    if(index == null) {
      switch(this.vertex_index_size) {
        case 1:
          return new Uint8List.fromList(this.triangles);
        case 2:
          return new Uint16List.fromList(this.triangles);
        case 4:
          return new Uint32List.fromList(this.triangles);
      }
      return null;
    }

    int offset = 0;
    int i = 0;
    for(i = 0; i < index; i++) {
      offset += this.materials[i].face_vert_count;
    }

    var triangles = this.triangles
      .getRange(offset, offset + this.materials[i].face_vert_count)
      .toList()
    ;

    switch(this.vertex_index_size) {
      case 1:
        return new Uint8List.fromList(triangles);
      case 2:
        return new Uint16List.fromList(triangles);
      case 4:
        return new Uint32List.fromList(triangles);
    }
    return null;
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
    for(int i = 0; i < this.vertices.length; i++) {
      var normal = this.vertices[i].normal;
      normal_list[i * 3 + 0] = normal.x;
      normal_list[i * 3 + 1] = normal.y;
      normal_list[i * 3 + 2] = normal.z;
    }
    return normal_list;
  }

  Float32List createEdgeList() {
    Float32List edge_list = new Float32List(this.vertices.length);
    for(int i = 0; i < this.vertices.length; i++) {
      edge_list[i] = this.vertices[i].edge_weight;
    }
    return edge_list;
  }

  Float32List createBoneList() {
    Float32List bone_list = new Float32List(this.vertices.length * 3);
    for(int i = 0; i < this.vertices.length; i++) {
      PMX_Vertex vertex = this.vertices[i];
      bone_list[i * 3 + 0] = vertex.bone1 * 1.0;
      if(vertex.bone2 == null) {
        bone_list[i * 3 + 1] = vertex.bone1 * 1.0;
        bone_list[i * 3 + 2] = 1.0;
      } else {
        bone_list[i * 3 + 1] = vertex.bone2 * 1.0;
        bone_list[i * 3 + 2] = vertex.bone1_weight / 100.0;
      }
    }
    return bone_list;
  }

  Float32List createCoordList() {
    Float32List normal_list = new Float32List(this.vertices.length * 2);
    for(int i = 0; i < this.vertices.length; i++) {
      var coord = this.vertices[i].coord;
      normal_list[i * 2 + 0] = coord.x;
      normal_list[i * 2 + 1] = coord.y;
    }
    return normal_list;
  }

  String toString() => ["{", [
    "version: ${this.version}",
    "byte_size: ${this.byte_size}",
    "encoding: ${this.encoding}",
    "extra_coord_size: ${this.extra_coord_size}",
    "vertex_index_size: ${this.vertex_index_size}",
    "texture_index_size: ${this.texture_index_size}",
    "material_index_size: ${this.material_index_size}",
    "bone_index_size: ${this.bone_index_size}",
    "morph_index_size: ${this.morph_index_size}",
    "rigid_body_index_size: ${this.rigid_body_index_size}",
    "name: ${this.name}",
    "english_name: ${this.english_name}",
    "comment: ${this.comment}",
    "english_comment: ${this.english_comment}",
    "triangles: ${this.triangles != null ? "..." : null}",
    "vertices: ${this.vertices != null ? "..." : null}",
    "textures: ${this.textures != null ? "..." : null}",
    "materials: ${this.materials != null ? "..." : null}",
    "bones: ${this.bones != null ? "..." : null}",
  ].join(", "), "}"].join("");
}
