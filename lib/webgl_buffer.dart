part of webgl_framework;

class WebGLBuffer {
  TypedData data;
  GL.Buffer buffer;
}

class WebGLArrayBuffer implements WebGLBuffer {
  Float32List data;
  GL.Buffer buffer;

  WebGLArrayBuffer(GL.RenderingContext gl, Float32List data) {
    var vbo = gl.createBuffer();
    gl.bindBuffer(GL.ARRAY_BUFFER, vbo);
    gl.bufferDataTyped(GL.ARRAY_BUFFER, data, GL.STATIC_DRAW);
    gl.bindBuffer(GL.ARRAY_BUFFER, null);

    this.data = data;
    this.buffer = vbo;
  }
}

class WebGLElementArrayBuffer {
  Uint16List data;
  GL.Buffer buffer;
  WebGLElementArrayBuffer(GL.RenderingContext gl, Uint16List data) {
    var ibo = gl.createBuffer();
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ibo);
    gl.bufferDataTyped(GL.ELEMENT_ARRAY_BUFFER, data, GL.STATIC_DRAW);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);

    this.data = data;
    this.buffer = ibo;
  }
}
