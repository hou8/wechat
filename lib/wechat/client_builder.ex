defmodule WeChat.ClientBuilder do
  @moduledoc false
  alias WeChat.{Component, MiniProgram}

  @base_option_fields [:role, :storage, :appid, :encoding_aes_key, :token, :requester]
  @default_opts [
    role: :official_account,
    storage: WeChat.Storage.File,
    requester: WeChat.Requester
  ]
  @official_account_modules [
    WeChat.Material,
    WeChat.Card,
    WeChat.CardManaging,
    WeChat.CardDistributing,
    WeChat.CustomService,
    WeChat.CustomMessage,
    WeChat.BatchSends,
    WeChat.Template,
    WeChat.User,
    WeChat.UserTag,
    WeChat.UserBlacklist,
    WeChat.Account,
    WeChat.Comment,
    WeChat.WebApp
  ]
  @mini_program_modules [
    MiniProgram.Auth
  ]

  defmacro __using__(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    role = Keyword.get(opts, :role, :official_account)

    sub_modules =
      case role do
        :official_account ->
          @official_account_modules

        :component ->
          case Keyword.get(opts, :app_type, :official_account) do
            :official_account -> [Component | @official_account_modules]
            :mini_program -> [Component | @mini_program_modules]
          end

        :mini_program ->
          @mini_program_modules

        _ ->
          raise ArgumentError, "please set role in [:official_account, :component, :mini_program]"
      end

    {sub_module_ast_list, files} =
      if Keyword.get(opts, :gen_sub_module?, true) do
        gen_sub_modules(sub_modules, __CALLER__.module)
      else
        {[], []}
      end

    default_opts = Macro.prewalk(opts, &Macro.expand(&1, __CALLER__))

    gen_get_function(role, default_opts) ++ files ++ sub_module_ast_list
  end

  defp gen_get_function(:official_account, default_opts) do
    default_opts
    |> Keyword.take([:appsecret | @base_option_fields])
    |> gen_get_function()
  end

  defp gen_get_function(:component, default_opts) do
    default_opts
    |> Keyword.take([:component_appid, :component_appsecret | @base_option_fields])
    |> gen_get_function()
  end

  defp gen_get_function(:mini_program, default_opts) do
    default_opts
    |> Keyword.take([:appsecret | @base_option_fields])
    |> gen_get_function()
  end

  defp gen_get_function(default_opts) do
    appid =
      case Keyword.get(default_opts, :appid) do
        appid when is_binary(appid) ->
          appid

        _ ->
          raise ArgumentError, "please set appid"
      end

    {requester, default_opts} = Keyword.pop(default_opts, :requester)

    base =
      quote do
        def default_opts, do: unquote(default_opts)
        def get_access_token, do: WeChat.Storage.Cache.get_cache(unquote(appid), :access_token)
        defdelegate get(url), to: unquote(requester)
        defdelegate get(url, opts), to: unquote(requester)
        defdelegate get(client, url, opts), to: unquote(requester)
        defdelegate post(url, body), to: unquote(requester)
        defdelegate post(url, body, opts), to: unquote(requester)
        defdelegate post(client, url, body, opts), to: unquote(requester)
      end

    get_funs =
      Enum.map(default_opts, fn
        {:encoding_aes_key, value} ->
          aes_key = WeChat.ServerMessage.Encryptor.aes_key(value)

          quote do
            def encoding_aes_key, do: unquote(value)
            def aes_key, do: unquote(aes_key)
          end

        {key, value} ->
          quote do
            def unquote(key)(), do: unquote(value)
          end
      end)

    [base | get_funs]
  end

  defp gen_sub_modules(sub_modules, parent_module) do
    client_module =
      parent_module
      |> Module.split()
      |> List.last()
      |> String.to_atom()

    Enum.map_reduce(
      sub_modules,
      [],
      fn module, acc ->
        {file, ast} = gen_sub_module(module, parent_module, client_module)
        {ast, [quote(do: @external_resource(unquote(file))) | acc]}
      end
    )
  end

  defp gen_sub_module(module, parent_module, client_module) do
    file = module.__info__(:compile)[:source]

    {:ok, ast} =
      file
      |> File.read!()
      |> Code.string_to_quoted()

    file =
      to_string(file)
      |> String.split("/")
      |> Enum.drop_while(&(&1 != "wechat"))
      |> Path.join()

    new_module_name_alias =
      module
      |> Module.split()
      |> List.delete_at(0)
      |> Enum.map(&String.to_atom/1)

    ast =
      Macro.prewalk(
        ast,
        fn
          {:defmodule, c_m, [{:__aliases__, c_a, _}, do_list]} ->
            [do: {:__block__, [], list}] = do_list

            do_list = [
              do:
                {:__block__, [],
                 [
                   quote(do: alias(unquote(parent_module))),
                   quote(do: @file(unquote(to_string(module))))
                   | list
                 ]}
            ]

            {:defmodule, c_m, [{:__aliases__, c_a, new_module_name_alias}, do_list]}

          {:spec, c_s, ast} ->
            ast =
              Macro.prewalk(
                ast,
                fn
                  {fun_name, context, [{{:., _, [{:__aliases__, _, _}, :client]}, _, _} | args]}
                  when is_atom(fun_name) ->
                    # del first argument
                    {fun_name, context, args}

                  sub_ast ->
                    sub_ast
                end
              )

            {:spec, c_s, ast}

          {:def, c_s, ast} ->
            ast =
              Macro.prewalk(
                ast,
                fn
                  {:., context, [{:client, c_c, nil}, fun_name]} ->
                    # replace client
                    {:., context, [{:__aliases__, c_c, [client_module]}, fun_name]}

                  {fun_name, context, [{:client, _, nil} | args]} when is_atom(fun_name) ->
                    # del first argument
                    {fun_name, context, args}

                  sub_ast ->
                    sub_ast
                end
              )

            {:def, c_s, ast}

          ast ->
            ast
        end
      )

    {file, ast}
  end
end
