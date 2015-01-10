part of webgl_framework;

class WebGLFBO {
  GL.Framebuffer buffer;
  GL.Renderbuffer depth_buffer;
  GL.Texture texture;
  
  WebGLFBO(GL.RenderingContext gl, {
    int width : 512, int height: 512,
    int texture_type : GL.UNSIGNED_BYTE,
    int min_filter : GL.LINEAR, int mag_filter: GL.LINEAR,
    int attachment : GL.COLOR_ATTACHMENT0,
    bool depth_buffer_enabled : false
    }
  ) {
    this._initialize(gl,
        width, height,
        texture_type,
        min_filter, mag_filter,
        attachment,
        depth_buffer_enabled
        );
  }
  
  void _initialize(
                       GL.RenderingContext gl,
                       int width, int height,
                       int texture_type,
                       int min_filter, int mag_filter,
                       int attachment,
                       bool depth_buffer_enabled
                       )
  {
    this.buffer = gl.createFramebuffer();
    gl.bindFramebuffer(GL.FRAMEBUFFER, this.buffer);

    if(depth_buffer_enabled) {
      this.depth_buffer = gl.createRenderbuffer();
      gl.bindRenderbuffer(GL.RENDERBUFFER, this.depth_buffer);
      gl.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, width, height);
      gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, this.depth_buffer);
    }
    
    this.texture = gl.createTexture();
    gl.bindTexture(GL.TEXTURE_2D, this.texture);
    gl.texImage2DTyped(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, texture_type, null);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, min_filter);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, mag_filter);
    gl.framebufferTexture2D(GL.FRAMEBUFFER, attachment, GL.TEXTURE_2D, this.texture, 0);

    gl.bindTexture(GL.TEXTURE_2D, null);
    gl.bindRenderbuffer(GL.RENDERBUFFER, null);
    gl.bindFramebuffer(GL.FRAMEBUFFER, null);
  }
}
