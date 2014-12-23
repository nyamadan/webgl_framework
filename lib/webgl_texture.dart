part of webgl_framework;

class WebGLTypedDataTexture {
  GL.Texture texture;
  TypedData data;

  bool flip_y;
  int internal_format;
  int format;
  int type;
  int width;
  int height;

  WebGLTypedDataTexture(GL.RenderingContext gl, TypedData data, {
    int width : 256,
    int height : 256,
    bool flip_y: false,
    int internal_format : GL.RGBA,
    int format : GL.RGBA,
    int type : GL.UNSIGNED_BYTE,
    Vector4 color
  }){
    this.flip_y = flip_y;
    this.format = format;
    this.internal_format = internal_format;
    this.type = type;
    this.width = width;
    this.height = height;

    this.texture = gl.createTexture();
    this.data = data;
    gl.bindTexture(GL.TEXTURE_2D, this.texture);
    if(this.flip_y) {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 1);
    } else {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 0);
    }
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
    gl.texImage2DTyped(GL.TEXTURE_2D, 0, this.internal_format, this.width, this.height, 0, this.format, this.type, this.data);
    gl.bindTexture(GL.TEXTURE_2D, null);
  }

  void refresh(GL.RenderingContext gl) {
    gl.bindTexture(GL.TEXTURE_2D, this.texture);

    if(this.flip_y) {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 1);
    } else {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 0);
    }
    gl.texImage2DTyped(GL.TEXTURE_2D, 0, this.internal_format, this.width, this.height, 0, this.format, this.type, this.data);
    gl.generateMipmap(GL.TEXTURE_2D);
    gl.bindTexture(GL.TEXTURE_2D, null);
  }
}

class WebGLCanvasTexture {
  CanvasElement canvas;
  CanvasRenderingContext2D ctx;

  GL.Texture texture;
  bool flip_y;
  int internal_format;
  int format;
  int type;

  WebGLCanvasTexture(GL.RenderingContext gl, {
    int width : 256,
    int height : 256,
    bool flip_y : false,
    int internal_format : GL.RGBA,
    int format : GL.RGBA,
    int type : GL.UNSIGNED_BYTE,
    Vector4 color
  }){
    this.flip_y = flip_y;
    this.format = format;
    this.internal_format = internal_format;
    this.type = type;

    this.canvas = document.createElement("canvas");
    this.canvas.width = width;
    this.canvas.height = height;

    this.ctx = this.canvas.getContext("2d");
    if(color != null) {
      this._setColor(color);
    }

    this.texture = gl.createTexture();
    gl.bindTexture(GL.TEXTURE_2D, this.texture);
    if(flip_y) {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 1);
    } else {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 0);
    }
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
    gl.texImage2DCanvas(GL.TEXTURE_2D, 0, this.internal_format, this.format, this.type, this.canvas);
    gl.bindTexture(GL.TEXTURE_2D, null);
  }

  void _setColor(Vector4 color) {
    int r = (Math.min(Math.max(color.r, 0.0), 1.0) * 0xff).toInt();
    int g = (Math.min(Math.max(color.g, 0.0), 1.0) * 0xff).toInt();
    int b = (Math.min(Math.max(color.b, 0.0), 1.0) * 0xff).toInt();
    num a = Math.min(Math.max(color.a, 0.0), 1.0);

    var fillStyle_orig = ctx.fillStyle;
    this.ctx.setFillColorRgb(r, g, b, a);
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this.ctx.fillStyle = fillStyle_orig;
  }

  void refresh(GL.RenderingContext gl) {
    gl.bindTexture(GL.TEXTURE_2D, this.texture);

    if(this.flip_y) {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 1);
    } else {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 0);
    }
    gl.texImage2DCanvas(GL.TEXTURE_2D, 0, this.internal_format, this.format, this.type, this.canvas);
    gl.generateMipmap(GL.TEXTURE_2D);
    gl.bindTexture(GL.TEXTURE_2D, null);
  }

  Future<WebGLCanvasTexture> load(GL.RenderingContext gl, String uri) {
    var completer = new Completer<WebGLCanvasTexture>();
    var future = completer.future;

    ImageElement image = document.createElement("img");
    image.onLoad.listen((event){
      if (image.width == 0 || image.height == 0) {
        return;
      }

      bool isPowerOfTwo(int x) => (x & (x - 1)) == 0x00;
      int nextHighestPowerOfTwo(int x) {
        --x;
        for(int i = 1; i < 32; i <<= 1) {
          x = x | x >> i;
        }
        return x + 1;
      }

      if(isPowerOfTwo(image.width) && isPowerOfTwo(image.height)) {
        this.canvas.width = image.width;
        this.canvas.height = image.height;
      } else {
        this.canvas.width = nextHighestPowerOfTwo(image.width);
        this.canvas.height = nextHighestPowerOfTwo(image.height);
      }

      this.ctx.drawImageScaled(image, 0, 0, this.canvas.width, this.canvas.height);
      this.refresh(gl);
      completer.complete(this);
    });

    image.src = uri;

    return future;
  }
}

