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

  void _renderNode(GLTFNode node, Matrix4 matrix) {
    matrix = matrix * node.matrix;

    if (node.children != null) {
      node.children.forEach((GLTFNode child) => this._renderNode(child, matrix));
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
                    GL.FLOAT,
                    false,
                    accessor.byte_stride,
                    accessor.byte_offset);
                break;
              case "VEC2":
                gl.vertexAttribPointer(
                    program.gl_attributes[attribute_name],
                    2,
                    GL.FLOAT,
                    false,
                    accessor.byte_stride,
                    accessor.byte_offset);
                break;
              case "VEC3":
                gl.vertexAttribPointer(
                    program.gl_attributes[attribute_name],
                    3,
                    GL.FLOAT,
                    false,
                    accessor.byte_stride,
                    accessor.byte_offset);
                break;
            }

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
                  gl.uniformMatrix4fv(
                      pass.uniform_locations[uniform_name],
                      false,
                      (material.instance_technique.values[parameter.key] as Matrix4).storage);
                  break;
                case GL.FLOAT_MAT3:
                  gl.uniformMatrix3fv(
                      pass.uniform_locations[uniform_name],
                      false,
                      (material.instance_technique.values[parameter.key] as Matrix3).storage);
                  break;
                case GL.FLOAT_MAT2:
                  gl.uniformMatrix2fv(
                      pass.uniform_locations[uniform_name],
                      false,
                      (material.instance_technique.values[parameter.key] as Matrix2).storage);
                  break;
              }
            });
          });
        });
      });

    }
  }

  void render(double ms) {
    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 1000.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 30.0 + 100.0 * this.trackball.value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 model = new Matrix4.identity();
    model.setRotation(this.trackball.rotation.asRotationMatrix());

    Matrix4 mvp = projection * view * model;

    gl.viewport(0, 0, this.dom.width, this.dom.height);
    gl.enable(GL.DEPTH_TEST);
    gl.clearColor(0.5, 0.5, 0.5, 1.0);
    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    if (this._gltf != null) {
      this._gltf.nodes.forEach((String key, GLTFNode node) {
        this._renderNode(node, mvp);
      });
    }
  }
}
