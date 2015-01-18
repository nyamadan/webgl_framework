library gltf_viewer;

import "dart:web_gl" as GL;
import "dart:math" as Math;
import "package:vector_math/vector_math.dart";
import "package:webgl_framework/webgl_framework.dart";

class GLTFRenderer extends WebGLRenderer {
  GLTFParser _gltf;
  void _initialize() {
    var gltf = new GLTFParser.copy(this);
    gltf.load("model", "fighter.gltf").then((GLTFParser gltf) {
      this._gltf = gltf;
    });
  }

  GLTFRenderer(int width, int height) {
    this.initContext(width, height);
    this.initTrackball();
    this._initialize();
  }

  GLTFRenderer.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;

    this._initialize();
  }

  void _renderNode(GLTFNode node, Matrix4 model, Matrix4 view, Matrix4 projection, Matrix3 normal, Matrix4 matrix) {
    matrix = matrix * node.matrix;

    if (node.children != null) {
      node.children.forEach((GLTFNode child) => this._renderNode(child, model, view, projection, normal, matrix));
    }


    if (node.meshes != null) {
      GLTFProgram current_program;
      node.meshes.forEach((GLTFMesh mesh) {
        mesh.primitives.forEach((GLTFMeshPrimitive primitive) {
          GLTFMaterial material = primitive.material;
          GLTFMaterialTechnique material_technique = material.instance_technique;
          GLTFTechnique technique = material_technique.technique;
          Map<String, GLTFTechniqueParameter> parameters = technique.parameters;
          GLTFTechniquePass pass = technique.pass;
          GLTFProgram program = pass.program;

          if (current_program != program) {
            gl.useProgram(program.gl_program);
            current_program = program;
          }

          pass.attributes.forEach((String attribute_name, GLTFTechniqueParameter parameter) {
            GLTFAccessor accessor = primitive.attributes[parameter.semantic];
            gl.bindBuffer(accessor.buffer_view.target, accessor.buffer_view.gl_buffer);
            switch (accessor.type) {
              case "SCALAR":
                gl.vertexAttribPointer(
                    program.gl_attributes[attribute_name],
                    1,
                    accessor.component_type,
                    false,
                    accessor.byte_stride,
                    accessor.byte_offset);
                break;
              case "VEC2":
                gl.vertexAttribPointer(
                    program.gl_attributes[attribute_name],
                    2,
                    accessor.component_type,
                    false,
                    accessor.byte_stride,
                    accessor.byte_offset);
                break;
              case "VEC3":
                gl.vertexAttribPointer(
                    program.gl_attributes[attribute_name],
                    3,
                    accessor.component_type,
                    false,
                    accessor.byte_stride,
                    accessor.byte_offset);
                break;
            }
          });

          pass.uniforms.forEach((String uniform_name, GLTFTechniqueParameter parameter) {
            switch (parameter.type) {
              case GL.FLOAT_VEC4:
                gl.uniform4fv(
                    pass.uniform_locations[uniform_name],
                    (material.instance_technique.values[parameter.key] as Vector4).storage);
                break;
              case GL.FLOAT_VEC3:
                gl.uniform3fv(
                    pass.uniform_locations[uniform_name],
                    (material.instance_technique.values[parameter.key] as Vector3).storage);
                break;
              case GL.FLOAT_VEC2:
                gl.uniform2fv(
                    pass.uniform_locations[uniform_name],
                    (material.instance_technique.values[parameter.key] as Vector2).storage);
                break;
              case GL.FLOAT_MAT4:
                switch (parameter.semantic) {
                  case "MODELVIEW":
                    gl.uniformMatrix4fv(
                        pass.uniform_locations[uniform_name],
                        false,
                        ((view * model * matrix) as Matrix4).storage);
                    break;
                  case "PROJECTION":
                    gl.uniformMatrix4fv(pass.uniform_locations[uniform_name], false, projection.storage);
                    break;
                  default:
                    gl.uniformMatrix4fv(
                        pass.uniform_locations[uniform_name],
                        false,
                        (material.instance_technique.values[parameter.key] as Matrix4).storage);
                    break;
                }
                break;
              case GL.FLOAT_MAT3:
                switch (parameter.semantic) {
                  case "MODELVIEWINVERSETRANSPOSE":
                    gl.uniformMatrix3fv(pass.uniform_locations[uniform_name], false, normal.storage);
                    break;
                  default:
                    gl.uniformMatrix3fv(
                        pass.uniform_locations[uniform_name],
                        false,
                        (material.instance_technique.values[parameter.key] as Matrix3).storage);
                    break;
                }
                break;
              case GL.FLOAT_MAT2:
                gl.uniformMatrix2fv(
                    pass.uniform_locations[uniform_name],
                    false,
                    (material.instance_technique.values[parameter.key] as Matrix2).storage);
                break;
            }
          });

          gl.bindBuffer(primitive.indices.buffer_view.target, primitive.indices.buffer_view.gl_buffer);
          gl.drawElements(primitive.primitive, primitive.indices.count, primitive.indices.component_type, 0);
        });
      });
    }
  }

  void render(double ms) {
    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 1000.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 3.0 + 10.0 * this.trackball.value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 model = new Matrix4.identity();
    model.setRotation(this.trackball.rotation.asRotationMatrix());

    Matrix3 normal = new Matrix3.identity();

    gl.viewport(0, 0, this.dom.width, this.dom.height);
    gl.enable(GL.DEPTH_TEST);
    gl.clearColor(0.5, 0.5, 0.5, 1.0);
    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    if (this._gltf != null) {
      this._gltf.scene.nodes.forEach((GLTFNode node) {
        this._renderNode(node, model, view, projection, normal, new Matrix4.identity());
      });
    }
  }
}
