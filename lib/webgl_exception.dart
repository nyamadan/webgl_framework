part of webgl_framework;

class WebGLException implements Exception {
  final String message;
  const WebGLException(this.message);
  String toString() => "WebGLException\n${this.message}";
}

class ShaderCompileException implements Exception {
  final String message;
  final String source;

  const ShaderCompileException(this.message, this.source);
  String toString() {
    var sb = new StringBuffer();

    sb.writeln("ShaderCompileException\n${this.message}");

    var lines = this.source.split("\n");
    for(var i = 0; i < lines.length; i++) {
      sb.writeln("${(i + 1).toString().padLeft(4, '0')}: ${lines[i]}");
    }

    return sb.toString();
  }
}

class ShaderLinkException implements Exception {
  final String message;
  const ShaderLinkException(this.message);
  String toString() => "ShaderLinkException\n${this.message}";
}

