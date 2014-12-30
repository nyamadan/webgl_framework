part of webgl_framework;

class TGAParser {
  int id_length;
  int color_map_type;
  int data_type;
  int color_map_origin;
  int color_map_length;
  int color_map_depth;

  int x;
  int y;
  int width;
  int height;
  int bits_per_pixel;
  int image_descriptor;
  int image_origin;

  Uint8List id;
  Uint8List color_map;

  ByteData _view;

  String toString() => ["{", [
  "id_length: ${this.id_length}",
  "color_map_type: ${this.color_map_type}",
  "data_type: ${this.data_type}",
  "color_map_type: ${this.color_map_type}",
  "color_map_origin: ${this.color_map_origin}",
  "color_map_length: ${this.color_map_length}",
  "color_map_depth: ${this.color_map_depth}",
  "x: ${this.x}",
  "y: ${this.y}",
  "width: ${this.width}",
  "height: ${this.height}",
  "bits_per_pixel: ${this.bits_per_pixel}",
  "image_origin: ${this.image_origin}",
  "image_descriptor: ${this.image_descriptor}",
  "id: ${this.id}",
  "color_map: ${this.color_map != null ? "..." : null}",
  ].join(", "), "}"].join("");

  Future<TGAParser> load(String uri) {
    var completer = new Completer<TGAParser>();
    var future = completer.future;

    var req = new HttpRequest();
    req.overrideMimeType("text\/plain; charset=x-user-defined");
    req.onLoad.listen((event){
      List<int> units = req.responseText.codeUnits;
      var u8_list = new Uint8List.fromList(units);
      ByteBuffer buffer = u8_list.buffer;

      this._view = new ByteData.view(buffer);
      int offset = 0;

      print("uri: $uri");

      this.id_length = this._view.getUint8(offset);
      offset += 1;

      this.color_map_type = this._view.getUint8(offset);
      offset += 1;

      this.data_type = this._view.getUint8(offset);
      offset += 1;

      this.color_map_origin = this._view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      this.color_map_length = this._view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      this.color_map_depth = this._view.getUint8(offset);
      offset += 1;

      this.x = this._view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      this.y = this._view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      this.width = this._view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      this.height = this._view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      this.bits_per_pixel = this._view.getUint8(offset);
      offset += 1;

      this.image_descriptor = this._view.getUint8(offset);
      offset += 1;

      this.id = new Uint8List.fromList(new List<int>.generate(this.id_length, (int i){
        int b = this._view.getUint8(offset);
        offset += 1;
        return b;
      }));

      if(this.color_map_type != 0) {
        offset = this.color_map_origin;

        this.color_map = new Uint8List.fromList(new List<int>.generate(this.color_map_length, (int i){
          int b = this._view.getUint8(offset);
          offset += 1;
          return b;
        }));
      }

      this.image_origin = offset;


      completer.complete(this);
    });
    req.open("GET", uri);
    req.send();

    return future;
  }

  List<int> getBytes() {
    if(this.bits_per_pixel != 24 && this.bits_per_pixel != 32) {
      return null;
    }

    int view_offset = this.image_origin;
    List<int> buffer = new List<int>(this.width * this.height * 4);

    if(this.data_type == 2) {
      for(int y = 0; y < this.height; y++) {
        for(int x = 0; x < this.width; x++) {
          int buffer_offset = ((this.height - y - 1) * this.width + x) * 4;
          buffer[buffer_offset + 2] = this._view.getUint8(view_offset);
          view_offset += 1;
          buffer[buffer_offset + 1] = this._view.getUint8(view_offset);
          view_offset += 1;
          buffer[buffer_offset + 0] = this._view.getUint8(view_offset);
          view_offset += 1;
          if(this.bits_per_pixel == 32) {
            buffer[buffer_offset + 3] = this._view.getUint8(view_offset);
            view_offset += 1;
          } else if(this.bits_per_pixel == 24) {
            buffer[buffer_offset + 3] = 0xff;
          }
        }
      }
    } else if(this.data_type == 10) {
      int pixel_count = this.width * this.height;
      int pixel_offset = 0;
      while(pixel_offset < pixel_count) {
        int header = this._view.getUint8(view_offset);
        view_offset += 1;

        bool rle = header & 0x80 != 0;
        int count = (header & 0x7f) + 1;
        if(rle) {
          //RLE
          int b = this._view.getUint8(view_offset);
          view_offset += 1;
          int g = this._view.getUint8(view_offset);
          view_offset += 1;
          int r = this._view.getUint8(view_offset);
          view_offset += 1;

          int a;
          if(this.bits_per_pixel == 32) {
            a = this._view.getUint8(view_offset);
            view_offset += 1;
          } else if(this.bits_per_pixel == 24) {
            a = 0xff;
          }

          for(int i = 0; i < count; i++) {
            int row = this.height - (pixel_offset ~/ this.width) - 1;
            int col = pixel_offset % this.width;
            int buffer_offset = (row * this.width + col) * 4;

            buffer[buffer_offset + 0] = r;
            buffer[buffer_offset + 1] = g;
            buffer[buffer_offset + 2] = b;
            buffer[buffer_offset + 3] = a;
            pixel_offset += 1;
          }
        } else {
          //Raw
          for(int i = 0; i < count; i++) {
            int row = this.height - (pixel_offset ~/ this.width) - 1;
            int col = pixel_offset % this.width;
            int buffer_offset = (row * this.width + col) * 4;
            buffer[buffer_offset + 2] = this._view.getUint8(view_offset);
            view_offset += 1;
            buffer[buffer_offset + 1] = this._view.getUint8(view_offset);
            view_offset += 1;
            buffer[buffer_offset + 0] = this._view.getUint8(view_offset);
            view_offset += 1;
            if(this.bits_per_pixel == 32) {
              buffer[buffer_offset + 3] = this._view.getUint8(view_offset);
              view_offset += 1;
            } else if(this.bits_per_pixel == 24) {
              buffer[buffer_offset + 3] = 0xff;
            }

            pixel_offset += 1;
          }
        }
      }
    }

    return buffer;
  }
}

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
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.MIRRORED_REPEAT);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.MIRRORED_REPEAT);
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
  static bool _isPowerOfTwo(int x) => (x & (x - 1)) == 0x00;
  static int _nextHighestPowerOfTwo(int x) {
    --x;
    for(int i = 1; i < 32; i <<= 1) {
      x = x | x >> i;
    }
    return x + 1;
  }

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
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.MIRRORED_REPEAT);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.MIRRORED_REPEAT);
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

  void _refreshCanvas(GL.RenderingContext gl, CanvasImageSource img, int width, int height){
    if (width == 0 || height == 0) {
      return;
    }

    if(_isPowerOfTwo(width) && _isPowerOfTwo(height)) {
      this.canvas.width = width;
      this.canvas.height = height;
    } else {
      this.canvas.width = _nextHighestPowerOfTwo(width);
      this.canvas.height = _nextHighestPowerOfTwo(height);
    }

    this.ctx.drawImageScaled(img, 0, 0, this.canvas.width, this.canvas.height);
    this.refresh(gl);
  }

  void refresh(GL.RenderingContext gl) {
    gl.bindTexture(GL.TEXTURE_2D, this.texture);

    if(this.flip_y) {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 1);
    } else {
      gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 0);
    }
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.MIRRORED_REPEAT);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.MIRRORED_REPEAT);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
    gl.texImage2DCanvas(GL.TEXTURE_2D, 0, this.internal_format, this.format, this.type, this.canvas);
    gl.generateMipmap(GL.TEXTURE_2D);
    gl.bindTexture(GL.TEXTURE_2D, null);
  }

  Future<WebGLCanvasTexture> load(GL.RenderingContext gl, String uri) {
    var completer = new Completer<WebGLCanvasTexture>();
    var future = completer.future;

    RegExp re = new RegExp(r"\.tga$", multiLine: false,caseSensitive: false);
    if(re.hasMatch(uri)) {
      var tga_loader = new TGAParser();
      tga_loader.load(uri)
      .then((tga){
        List<int> bytes = tga.getBytes();
        var tga_canvas = document.createElement("canvas") as CanvasElement;
        tga_canvas.width = tga.width;
        tga_canvas.height = tga.height;

        var tga_ctx = tga_canvas.getContext("2d");
        var image_data = tga_ctx.getImageData(0, 0, tga_canvas.width, tga_canvas.height);
        int length = tga.width * tga.height * 4;
        for(int i = 0; i < length; i++) {
          image_data.data[i] = bytes[i];
        }
        tga_ctx.putImageData(image_data, 0, 0);
        this._refreshCanvas(gl, tga_canvas, tga_canvas.width, tga_canvas.height);
        completer.complete(this);
      });
      return future;
    }

    ImageElement img = document.createElement("img");
    img.onLoad.listen((event){
      this._refreshCanvas(gl, img, img.width, img.height);
      completer.complete(this);
    });

    img.src = uri;

    return future;
  }
}

