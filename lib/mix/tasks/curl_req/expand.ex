defmodule Mix.Tasks.CurlReq.Expand do
  use Mix.Task

  def run(_args) do
    files =
      "lib/**/*.{ex,exs}"
      |> Path.wildcard(match_dot: true)
      |> Enum.filter(&File.regular?/1)

    yes =
      """
      Should we expand the ~CURL() in the following files?
      #{Enum.join(files, "\n")}

      """
      |> Mix.shell().yes?()

    if yes do
      for file <- files do
        expand_file(file)
      end
    else
      Mix.shell().info("Operation aborted")
    end
  end

  defp expand(source) when is_binary(source) do
    {_quoted, patches} =
      source
      |> Sourceror.parse_string!()
      |> Macro.postwalk([], fn
        {:sigil_CURL, _dot_meta, [{:<<>>, _, _} | _] = _rest} = quoted, patches ->
          {:ok, env} = __ENV__ |> Macro.Env.define_import([line: 2], CurlReq)
          # TODO: get range when Sourceror.get_range/1 returns nil
          if range = Sourceror.get_range(quoted) do
            expanded = Macro.expand_once(quoted, env)
            reconstructed = reconstruct(expanded)
            replacement = reconstructed |> Sourceror.to_string()
            patch = %{range: range, change: replacement}
            {quoted, [patch | patches]}
          else
            {quoted, patches}
          end

        quoted, patches ->
          {quoted, patches}
      end)

    Sourceror.patch_string(source, patches)
  end

  defp expand_file(filename) do
    patched_code =
      filename
      |> File.read!()
      |> expand()

    File.write!(filename, patched_code)
  end

  # Walks and transforms the AST so that
  # %{__struct__: Some.Module, key: val, ...}
  # becomes
  # %Some.Module{key: val, ...}.

  defp reconstruct(ast) do
    Macro.postwalk(ast, fn
      # Match on a literal map: {:%{}, meta, fields}
      {:%{}, meta, fields} = node ->
        case Keyword.pop(fields, :__struct__) do
          {nil, _} ->
            # It's just a normal map, not a struct
            node

          {mod, rest} ->
            # We found __struct__: mod
            # Turn that into:
            #
            #   {:%, meta, [
            #     alias_ast_for(mod),
            #     {:%{}, meta, rest}
            #   ]}
            #
            {:%, meta,
             [
               module_to_alias_ast(mod),
               {:%{}, meta, rest}
             ]}
        end

      other ->
        other
    end)
  end

  # Converts an atom module (e.g. Req.Request)
  # into an AST alias: {:__aliases__, [alias: false], [:Req, :Request]}
  defp module_to_alias_ast(mod) when is_atom(mod) do
    mod
    # ["Foo", "Bar", "Baz"]
    |> Module.split()
    |> Enum.map(&String.to_atom/1)
    |> then(fn aliases ->
      {:__aliases__, [alias: false], aliases}
    end)
  end
end
