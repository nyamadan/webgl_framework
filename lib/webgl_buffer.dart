part of webgl_framework;

class WebGLBuffer {
  List data;
  GL.Buffer buffer;
  int byte_per_element;
}

class SubArrayData {
  Float32List data;
  int offset;
  int byte_per_element = 4;
  
  SubArrayData(this.offset, this.data);
}

class WebGLArrayBuffer32 implements WebGLBuffer {
  Float32List data;
  GL.Buffer buffer;
  int byte_per_element;

  WebGLArrayBuffer32(GL.RenderingContext gl, Float32List data) {
    this.byte_per_element = 4;
    
    var vbo = gl.createBuffer();
    this.buffer = vbo;
    this.setData(gl, data);
  }

  void setData(GL.RenderingContext gl, Float32List data) {
    gl.bindBuffer(GL.ARRAY_BUFFER, this.buffer);
    gl.bufferDataTyped(GL.ARRAY_BUFFER, data, GL.STATIC_DRAW);
    gl.bindBuffer(GL.ARRAY_BUFFER, null);

    this.data = data;
  }
  
  void setSubData(GL.RenderingContext gl, SubArrayData sub_data) {
    gl.bindBuffer(GL.ARRAY_BUFFER, this.buffer);
    gl.bufferSubDataTyped(GL.ARRAY_BUFFER, sub_data.offset, sub_data.data);
    gl.bindBuffer(GL.ARRAY_BUFFER, null);

    this.data = data;
  }
}

class WebGLElementArrayBuffer8 implements WebGLBuffer {
  Uint8List data;
  GL.Buffer buffer;
  int byte_per_element;

  WebGLElementArrayBuffer8(GL.RenderingContext gl, Uint8List data) {
    this.byte_per_element = Uint8List.BYTES_PER_ELEMENT;

    var ibo = gl.createBuffer();
    this.buffer = ibo;
    this.setData(gl, data);
  }

  void setData(GL.RenderingContext gl, Uint8List data) {
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.buffer);
    gl.bufferDataTyped(GL.ELEMENT_ARRAY_BUFFER, data, GL.STATIC_DRAW);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);

    this.data = data;
  }
}

class WebGLElementArrayBuffer16 implements WebGLBuffer {
  Uint16List data;
  GL.Buffer buffer;
  int byte_per_element;

  WebGLElementArrayBuffer16(GL.RenderingContext gl, Uint16List data) {
    this.byte_per_element = Uint16List.BYTES_PER_ELEMENT;

    var ibo = gl.createBuffer();
    this.buffer = ibo;
    this.setData(gl, data);
  }

  void setData(GL.RenderingContext gl, Uint16List data) {
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.buffer);
    gl.bufferDataTyped(GL.ELEMENT_ARRAY_BUFFER, data, GL.STATIC_DRAW);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);

    this.data = data;
  }
}

class WebGLElementArrayBuffer32 implements WebGLBuffer {
  Uint32List data;
  GL.Buffer buffer;
  int byte_per_element;

  WebGLElementArrayBuffer32(GL.RenderingContext gl, Uint32List data) {
    this.byte_per_element = Uint32List.BYTES_PER_ELEMENT;

    var ibo = gl.createBuffer();
    this.buffer = ibo;
    this.setData(gl, data);
  }
  void setData(GL.RenderingContext gl, Uint32List data) {
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.buffer);
    gl.bufferDataTyped(GL.ELEMENT_ARRAY_BUFFER, data, GL.STATIC_DRAW);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);

    this.data = data;
  }
}
