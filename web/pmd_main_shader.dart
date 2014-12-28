part of mmd_renderer;

class PMD_MainShader extends WebGLRenderer {
  static const String VS =
  """
  attribute vec3 position;
  attribute vec3 normal;
  attribute vec3 bone;
  attribute vec2 coord;
  uniform mat4 model_matrix;
  uniform mat4 view_matrix;
  uniform mat4 projection_matrix;

  uniform sampler2D bone_texture;

  varying vec4 v_normal;
  varying vec2 v_coord;

  const vec2 half_bone = vec2(0.5 / 8.0, 0.5 / 512.0);

  mat4 getTransformMatrix(float bone_index) {
    return mat4(
      texture2D(bone_texture, vec2(
          0.0 * half_bone.x + half_bone.x,
          2.0 * bone_index * half_bone.y + half_bone.y
      )),
      texture2D(bone_texture, vec2(
          2.0 * half_bone.x + half_bone.x,
          2.0 * bone_index * half_bone.y + half_bone.y
      )),
      texture2D(bone_texture, vec2(
          4.0 * half_bone.x + half_bone.x,
          2.0 * bone_index * half_bone.y + half_bone.y
      )),
      texture2D(bone_texture, vec2(
          6.0 * half_bone.x + half_bone.x,
          2.0 * bone_index * half_bone.y + half_bone.y
      ))
    );
  }

  vec4 getBonePosition(float bone_index) {
    return texture2D(bone_texture, vec2(
        8.0 * half_bone.x + half_bone.x,
        2.0 * bone_index * half_bone.y + half_bone.y
    ));
  }

  vec4 getTransformedBonePosition(float bone_index) {
    return texture2D(bone_texture, vec2(
        10.0 * half_bone.x + half_bone.x,
        2.0 * bone_index * half_bone.y + half_bone.y
    ));
  }

  void main(void){
    float weight = bone.z;
    mat4 transform1 = getTransformMatrix(bone.x);
    mat4 transform2 = getTransformMatrix(bone.y);

    vec4 bone1 = getBonePosition(bone.x);
    vec4 bone2 = getBonePosition(bone.y);

    vec4 transformed_bone1 = getTransformedBonePosition(bone.x);
    vec4 transformed_bone2 = getTransformedBonePosition(bone.y);

    vec4 v1 = vec4(position, 1.0) - bone1;
    vec4 v2 = vec4(position, 1.0) - bone2;

    vec4 p1 = (transform1 * v1) + transformed_bone1;
    vec4 p2 = (transform2 * v2) + transformed_bone2;

    mat4 m = transform1 * weight + transform2 * (1.0 - weight);
    v_normal = vec4(normalize(mat3(model_matrix * m) * normal), 1.0);

    v_coord = coord;
    gl_Position = projection_matrix * view_matrix * model_matrix * mix(p2, p1, weight);
  }
  """;

  static const String FS =
  """
  precision mediump float;

  uniform vec4 diffuse;
  uniform vec3 ambient;
  uniform sampler2D texture;
  uniform sampler2D toon_texture;

  varying vec4 v_normal;
  varying vec2 v_coord;

  void main(void){
    vec4 tex_color = texture2D(texture, v_coord);

    float n = clamp(dot(v_normal.xyz, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
    vec3 d = texture2D(toon_texture, vec2(0.5, n)).rgb;
    vec3 color = diffuse.rgb * tex_color.rgb * (d + ambient);

    gl_FragColor = vec4(color, diffuse.a * tex_color.a);
  }
  """;

  List<MaterialNode> materials;
  WebGLArrayBuffer32 position_buffer;
  WebGLArrayBuffer32 normal_buffer;
  WebGLArrayBuffer32 coord_buffer;
  WebGLArrayBuffer32 bone_buffer;

  List<WebGLBuffer> index_buffer_list;
  Map<String, WebGLCanvasTexture> textures;
  Map<int, WebGLCanvasTexture> toon_textures;
  WebGLCanvasTexture white_texture;
  WebGLCanvasTexture diffuse_texture;
  WebGLTypedDataTexture bone_texture;

  GL.Program program;
  Map<String, int> attributes;
  Map<String, GL.UniformLocation> uniforms;

  Matrix4 model;
  Matrix4 view;
  Matrix4 projection;
  Matrix4 mvp;

  PMD_MainShader(int width, int height)
  {
    this.initContext(width, height);
    this._initialize();
  }

  PMD_MainShader.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;
    this._initialize();
  }

  void _initialize() {
    var vs = this.compileVertexShader(VS);
    var fs = this.compileFragmentShader(FS);
    this.program = this.linkProgram(vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    this.attributes = this.getAttributes(this.program, [
      "position",
      "normal",
      "coord",
      "bone",
    ]);

    this.uniforms = this.getUniformLocations(this.program, [
      "diffuse",
      "ambient",
      "texture",
      "toon_texture",
      "bone_texture",
      "mvp_matrix",
      "model_matrix",
      "view_matrix",
      "projection_matrix",
    ]);
  }

  void render(double elapsed)
  {
    gl.enable(GL.DEPTH_TEST);
    gl.depthFunc(GL.LEQUAL);
    //gl.depthMask(true);

    gl.disable(GL.CULL_FACE);

    gl.useProgram(this.program);

    if (this.uniforms.containsKey("model_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["model_matrix"], false, model.storage);
    }

    if (this.uniforms.containsKey("view_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["view_matrix"], false, view.storage);
    }

    if (this.uniforms.containsKey("projection_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["projection_matrix"], false, projection.storage);
    }

    if (this.uniforms.containsKey("mvp_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["mvp_matrix"], false, mvp.storage);
    }

    if (this.attributes.containsKey("normal")) {
      gl.enableVertexAttribArray(this.attributes["normal"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.normal_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["normal"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("position")) {
      gl.enableVertexAttribArray(this.attributes["position"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.position_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["position"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("coord")) {
      gl.enableVertexAttribArray(this.attributes["coord"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.coord_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["coord"], 2, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("bone")) {
      gl.enableVertexAttribArray(this.attributes["bone"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.bone_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["bone"], 3, GL.FLOAT, false, 0, 0);
    }

    for (int i = 0; i < this.materials.length; i++) {
      var index_buffer = this.index_buffer_list[i];

      var material = this.materials[i];

      if (this.uniforms.containsKey("diffuse")) {
        var color = new Vector4.copy(material.diffuse);
        gl.uniform4fv(this.uniforms["diffuse"], color.storage);
      }

      if (this.uniforms.containsKey("ambient")) {
        var color = new Vector3.copy(material.ambient);
        gl.uniform3fv(this.uniforms["ambient"], color.storage);
      }

      if (this.uniforms.containsKey("texture")) {
        gl.activeTexture(GL.TEXTURE0);
        GL.Texture texture;
        if(this.textures.containsKey(material.texture_file_name)) {
          texture = this.textures[material.texture_file_name].texture;
        } else {
          texture = this.white_texture.texture;
        }
        gl.bindTexture(GL.TEXTURE_2D, texture);
        gl.uniform1i(this.uniforms["texture"], 0);
      }

      if (this.uniforms.containsKey("bone_texture")) {
        gl.activeTexture(GL.TEXTURE1);
        gl.bindTexture(GL.TEXTURE_2D, this.bone_texture.texture);
        gl.uniform1i(this.uniforms["bone_texture"], 1);
      }

      if (this.uniforms.containsKey("toon_texture")) {
        gl.activeTexture(GL.TEXTURE2);
        GL.Texture texture;
        if(this.toon_textures.containsKey(material.toon_index)) {
          texture = this.toon_textures[material.toon_index].texture;
        } else {
          texture = this.diffuse_texture.texture;
        }
        gl.bindTexture(GL.TEXTURE_2D, texture);
        gl.uniform1i(this.uniforms["toon_texture"], 2);
      }

      gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer.buffer);
      if(index_buffer.byte_per_element == 2) {
        gl.drawElements(GL.TRIANGLES, index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
      } else if(index_buffer.byte_per_element == 4) {
        gl.drawElements(GL.TRIANGLES, index_buffer.data.length, GL.UNSIGNED_INT, 0);
      }
    }
  }
}