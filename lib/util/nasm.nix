{
  replaceYasmWithNasm =
    final: inputs: (builtins.filter (x: (x.pname or x.name or "") != "yasm") inputs) ++ [ final.nasm ];
}
