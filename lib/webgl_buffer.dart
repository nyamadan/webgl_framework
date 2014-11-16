part of webgl_framework;

class WebGLBuffer {
  TypedData data;
  GL.Buffer buffer;
}

class WebGLArrayBuffer implements WebGLBuffer {
  Float32List data;
  GL.Buffer buffer;

  WebGLArrayBuffer([this.buffer, this.data]);
}

class WebGLElementArrayBuffer {
  Uint16List data;
  GL.Buffer buffer;
  WebGLElementArrayBuffer([this.buffer, this.data]);
}
